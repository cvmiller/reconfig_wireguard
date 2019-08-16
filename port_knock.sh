#!/bin/sh


#
#  Tool to restart Wireguard reconfig by listening to incoming knocker port
#    Use traceroute on knocker port to activate "restart" loop
#
#  by Craig Miller
#  9 Feb 2019
#

VERSION=0.95


usage () {
               echo "	$0 - restart reconfig_ws for incoming connections "
	       echo "	e.g. $0  "
	       echo "	-c [Wireguard listener command]"
	       echo "	-p [knock port to listen on]"
	       echo "	-k  Kill the running version of this script"
	       echo "	-h  this help"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }




# initialize some vars

WAN=$(/sbin/uci get network.wan.ifname)
# wireguard interface, e.g. WGNET
WG_INT=$(/sbin/uci show | grep proto | grep wireguard | cut -d '.' -f 2)
#LISTEN_PORT=$(/sbin/uci get network.$WG_INT.listen_port)

KNOCK_PORT=19000
KNOCK_PROTO="udp"

# create range of 99 ports, traceroute increments ports with each hop
KNOCK_PORT_END=$(expr $KNOCK_PORT + 99 )
WG_CMD="/root/reconfig_wg.sh"

# uci parameters to be reconfigured
ENDPOINT_PEER=0
ENDPOINT_HOST="network.@wireguard_$WG_INT[$ENDPOINT_PEER].endpoint_host"
ENDPOINT_PORT="network.@wireguard_$WG_INT[$ENDPOINT_PEER].endpoint_port"

DEBUG=0
KILL=0
CONTINUE="TRUE"

# apps used
TCPDUMP=/usr/sbin/tcpdump
UCI=/sbin/uci
LOGGER=/usr/bin/logger
KILLALL=/usr/bin/killall


while getopts "?hdi:c:p:k" options; do
  case $options in
    d ) DEBUG=1
    	numopts=$(( numopts++));;
    k ) KILL=1
    	numopts=$(( numopts++));;
    i ) WG_INT=$OPTARG
    	numopts=$(( numopts + 2));;
    c ) WG_CMD=$OPTARG
    	numopts=$(( numopts + 2));;
    p ) KNOCK_PORT=$OPTARG
    	# update end of range
    	KNOCK_PORT_END=$(expr $KNOCK_PORT + 99 )
    	numopts=$(( numopts + 2));;
    h ) usage;;
    \? ) usage	# show usage with flag and no value
         exit 1;;
    * ) usage		# show usage with unknown flag
    	 exit 1;;
  esac
done
# remove the options as cli arguments
shift $numopts


# check that tcpdump is installed
check=$(command -v $TCPDUMP)
if [ $? -ne 0 ]; then
	echo "ERROR: tcpdump not found, please install"
	exit 1
fi

# check that uci is installed
check=$(command -v $UCI)
if [ $? -ne 0 ]; then
	echo "ERROR: uci not found. Is this an OpenWrt router?"
	exit 1
fi


kill_script () {
	if [ $1 != "" ]; then
		# kill _this_ script
		cmd=$1
	else
		# parse WG_CMD
		cmd=$(echo $WG_CMD | tr '/' ' ' | awk '{print $NF}')
	fi
	# pds of WG_CMD, exclude grep & -k kill command
	pids=$(ps | grep $cmd | grep -v grep | grep -v  -- " -k" | awk '{print $1}')
	
	# kill tcpdump too
	$KILLALL tcpdump
	# kills the script
	kill $pids
}

if [ $KILL -eq 1 ]; then
	echo "---- Killing running port_knock.sh script"
	kill_script $0
	$LOGGER "Wireguard knocker: stopping $WG_CMD"
	exit 0
fi


#example of capturing with TTL=1
#tcpdump -i eth1  -v -l -n portrange 2122-2199 and ip[8]=1

# loop if not in debug mode
while [ "$CONTINUE" == "TRUE" ]
do

	echo "---- Listening for incoming Wireguard knocker ports: $KNOCK_PORT-$KNOCK_PORT_END"
	# write start time to syslog
	now=$(date)
	$LOGGER "Wireguard knocker: listening to port $KNOCK_PORT-$KNOCK_PORT_END at $now"

	# capture src address and port with ttl=1 (from traceroute)
	#capture=$(tcpdump -i $WAN -l -n -c 1 -p -v "dst portrange $KNOCK_PORT-$KNOCK_PORT_END and udp and ip[8]=1" )
	capture=$(tcpdump -i $WAN -l -n -c 1 -p -v "dst portrange $KNOCK_PORT-$KNOCK_PORT_END and udp and ip[8]=1" | egrep -o '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' )
	# isolate ip src and dst 
	capture=$(echo $capture |  awk '{print $1 " -> " $2 }')
	if [ $DEBUG -eq 1 ]; then
		# show packet info captured
		echo $capture
	fi

	# log knocker
	$LOGGER "Wireguard knocker RX: $capture"


	# don't loop if in debug mode
	if [ $DEBUG -eq 1 ]; then
		CONTINUE="FALSE"
	else
		# kill WG_CMD
		kill_script
		$LOGGER "Wireguard knocker: restarting $WG_CMD"
		# restart reconfig_wg script
		$WG_CMD &	
	fi
	
done

echo " ---- pau"








