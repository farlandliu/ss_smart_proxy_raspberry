#!/bin/sh
# ref from [here](https://hong.im/2014/03/16/configure-an-openwrt-based-router-to-use-shadowsocks-and-redirect-foreign-traffic/)
#create a new chain named SHADOWSOCKS
iptables -t nat -N SHADOWSOCKS

#Redirect what you want

#Google
iptables -t nat -A SHADOWSOCKS -p tcp -d 74.125.0.0/16 -j REDIRECT --to-ports 1080
iptables -t nat -A SHADOWSOCKS -p tcp -d 173.194.0.0/16 -j REDIRECT --to-ports 1080

#Youtube
iptables -t nat -A SHADOWSOCKS -p tcp -d 208.117.224.0/19 -j REDIRECT --to-ports 1080
iptables -t nat -A SHADOWSOCKS -p tcp -d 209.85.128.0/17 -j REDIRECT --to-ports 1080

#Twitter
iptables -t nat -A SHADOWSOCKS -p tcp -d 199.59.148.0/22 -j REDIRECT --to-ports 1080

#Shadowsocks.org
iptables -t nat -A SHADOWSOCKS -p tcp -d 199.27.76.133/32 -j REDIRECT --to-ports 1080

#1024
iptables -t nat -A SHADOWSOCKS -p tcp -d 184.154.128.246/32 -j REDIRECT --to-ports 1080

#Anything else should be ignore
iptables -t nat -A SHADOWSOCKS -p tcp -j RETURN

# Apply the rules
iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS