### Synopsis

Using WireGuard to bring the IPv6 Internet to the IPv4-only land of NAT.

This script is a work-around for OpenWrt which reconfigures WireGuard peer on the fly based on incoming packets from a mobile OpenWrt Router.

### Motivation

The evil of NAT (Net Address Translation) has become institutionalized. And because NAT munges the network header, it causes all sorts of problems, including preventing simple IPv6 tunneling (6in4).

But go to any Starbucks, McDonald's, the airport or even the Library, and you will find yourself on a NATted network. How to get on the IPv6 Internet when stuck behind NAT? Enter the VPN (Virtual Private Network).

### VPN tunneling IPv6

Most people use VPNs make it appear they are in a different location, or are looking for the extra security. But most (99%) VPN providers only support IPv4, and in fact, either disable IPv6, or ask you to do so to prevent IPv6 *leakage*.

But what if you could use a VPN to transport IPv6 traffic to the IPv6 Internet (now over 25%). I looked at OpenVPN, for this purpose, but found all the moving parts (Certs, pushing routes, lack of IPv6 examples) daunting. If you have a working OpenVPN setup, you may find it easier to tunnel IPv6 through it.

### Wireguard, the easy VPN

Wireguard is getting a lot of buzz these days, as it is much easier to setup than OpenVPN. It works similar to `ssh` keys. Create public/private keys, for each node in the VPN, tell the each nodes the remote node IPv4 address, and connect! Wireguard is very good at making a complex VPN thing into a simple setup.

But the *standard* Wireguard VPN only has a roaming laptop at the far end. I wanted to share the IPv6 goodness with my friends, which meant that I wanted to have an entire IPv6 subnet available in IPv4-only NATland.

### Using OpenWrt to share IPv6 goodness

OpenWrt to the rescue. OpenWrt is an open source router software than runs on hundreds of different types of routers. And Wireguard is a package that is prebuilt for each of those routers. There's even a friendly  web GUI frontend to configure Wireguard! What's not to like.

![extending your IPv6 network](http://www.makikiweb.com/ipv6/_images/wireguard_ipv6_network.png)

The network (above) shows the highlevel design. Allow IPv4 traffic to follow the usual NATland path to the IPv4 Internet (via the Evil NAT Router). But push the IPv6 traffic through the Wireguard Tunnel, where there is another router to forward it onto the IPv6 Internet. This is called **split tunnel** in VPN parlance.

The advantages of this topology are:
* IPv4 traffic follows the usual NATted path, no change there
* End stations (to the left of R1) require no special software configuration to use it
* Rather than just keeping the IPv6 to yourself, you can share the IPv6 goodness with anyone connecting to R1 router

The last point means you can bring IPv6 networking into the unfriendly IPv4 NATland world, and show people there is a better way. Training in the obvious application, but there are other applications such as transitional networks.

### Road Warrior Script

What if your remote location is not static? What if the Evil NATland router changes your port? How can you fill in the Peer IP address and port if you have unpredictable NAT changing things on your?

I am still working on it. The *real* solution would be to leave the Peer IP and Port info blank, and let WireGuard figure it out. But alas with OpenWrt 18.06.1 that doesn't work.

As a work-around, I have created a script (reconfig_wg.sh) for R2 which listens for the Peer, and reconfigures the R2 WireGuard IP and Port info dynamically. 

## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other embedded platforms beyond OpenWRT are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))

