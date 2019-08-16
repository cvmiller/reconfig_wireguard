#!/bin/sh


#
#  Tool to reconfigure Wireguard by listening to incoming addresses and ports
#
#  by Craig Miller
#  28 Jan 2019
#

VERSION=0.96


usage () {
               echo "	$0 - reconfigure Wireguard for incoming connection "
	       echo "	e.g. $0  "
	       echo "	-i [WG_interface]  optional, use if more than one Wireguard interface"
	       echo "	-P [peer number 0,1,2...] optional, use if more than one peer"
	       echo "	-k  Kill the running version of this script"
	       echo "	-h  this help"
	       echo "	"
	       echo " By Craig Miller - Version: $VERSION"
	       exit 1
           }




# initialize some vars

WAN=$(/sbin/uci get network.wan.ifname)
# wireguard interface, e.g. WGNET
WG_INT=$(/sbin/uci show 2> /dev/null | grep proto | grep wireguard | cut -d '.' -f 2)
LISTEN_PORT=$(/sbin/uci get network.$WG_INT.listen_port)

WG_CMD="/root/reconfig_wg.sh"

# uci parameters to be reconfigured
ENDPOINT_PEER=0

DEBUG=0
KILL=0

# apps used
TCPDUMP=/usr/sbin/tcpdump
UCI=/sbin/uci
LOGGER=/usr/bin/logger
KILLALL=/usr/bin/killall

while getopts "?hi:P:kd" options; do
  case $options in
    d ) DEBUG=1
    	numopts=$(( numopts++));;
    k ) KILL=1
    	numopts=$(( numopts++));;
    i ) WG_INT=$OPTARG
    	numopts=$(( numopts + 2));;
    P ) ENDPOINT_PEER=$OPTARG
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

# update endpoint vars based on peer number
ENDPOINT_HOST="network.@wireguard_$WG_INT[$ENDPOINT_PEER].endpoint_host"
ENDPOINT_PORT="network.@wireguard_$WG_INT[$ENDPOINT_PEER].endpoint_port"

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
	# kill WG_CMD
	$LOGGER "Wireguard reconfig: stopping $WG_CMD"
	cmd=$(echo $WG_CMD | tr '/' ' ' | awk '{print $NF}')
	
	# pds of WG_CMD, exclude grep & -k kill command
	pids=$(ps | grep $cmd | grep -v grep | grep -v  -- " -k" | awk '{print $1}')
	
	# kill tcpdump too
	$KILLALL tcpdump
	# kill WG_CMD
	kill $pids
}


if [ $KILL -eq 1 ]; then
	echo "---- Killing running Wireguard reconfig script"
	kill_script
	exit 0
fi


echo "---- Listening for incoming Wireguard packet"
# write start time to syslog
now=$(date)
$LOGGER "Wireguard reconfig: listening to port $LISTEN_PORT at $now"

# capture src address and port
addr_port=$(tcpdump -i $WAN -l -n -c 1 -p "dst port $LISTEN_PORT and udp" | awk '{print $3 }')


# parse src address and port
src_port=$(echo $addr_port | tr '.' ' ' | awk '{print $5 }')
src_addr=$(echo $addr_port | tr '.' ' ' | awk '{print $1 "."  $2 "." $3 "." $4 }')

# if tcpdump is killed, die quietly
if [ "$src_port" == "" ]; then
	#die quietly
	exit 0
fi

echo "---- Found incoming WG packet on $src_addr and port $src_port"

if [ $DEBUG -eq 1 ]; then
	echo "---- DEBUG: look at current config"

	a=$( $UCI get $ENDPOINT_HOST)
	p=$( $UCI get $ENDPOINT_PORT)

	echo "---- old config is: $a $p"
fi


echo "---- reconfig $WG_INT"

$UCI set "$ENDPOINT_HOST=$src_addr"
$UCI set "$ENDPOINT_PORT=$src_port"

if [ $DEBUG -eq 1 ]; then
	echo "---- DEBUG: look at reconfigured config"
	a=$( $UCI get $ENDPOINT_HOST)
	p=$( $UCI get $ENDPOINT_PORT)
	echo "---- New config is: $a $p"
fi

echo "---- restart Wireguard"

ifdown $WG_INT
ifup $WG_INT

sleep 2

echo "---- show Wireguard status"

wg show

echo "---- restarting dhhcpv6 server"

/etc/init.d/odhcpd restart

now=$(date)
echo "---- Write time of connect to syslog: $now"

$LOGGER -s "Wireguard reconfig: complete: $now"

echo " ---- pau"



