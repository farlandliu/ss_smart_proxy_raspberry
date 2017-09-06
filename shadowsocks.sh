#!/bin/bash
# Shell scripts to control shadowsocks proxy on Linux
# Author:	Lance Liao	http://www.shuyz.com
# Date:		Sep 19th, 2015
# Last updated:	Apr 9, 2016
# edit by liu 2017/9/06

#ss_redir=/opt/shadowsocks/ss-redir
#ss_tunnel=/opt/shadowsocks/ss-tunnel
ss_config=/etc/sss.json

ss_port=1080
dns_port=1054

add_rules_ipset() {
    set_ok=$(ipset list | grep "gfwlist")
    if [ -z "$set_ok" ]; then
        ipset create gfwlist hash:ip counters timeout 1200
    else
        echo 'ipset gfwlist already exists!'
    fi

    echo 'add dns servers to gfwlist...'
    ipset add gfwlist 8.8.8.8
    ipset add gfwlist 8.8.4.4
    ipset add gfwlist 49.238.213.1
    ipset add gfwlist 208.67.222.222
    ipset add gfwlist 208.67.220.220

    iptables -t nat -A OUTPUT -p tcp -m set --match-set gfwlist dst -j REDIRECT --to-port $ss_port
    
    # we should restart dnsmasq to put add rules to the set
    # if dnsmasq is start before the set is created, the site could not be open
    echo 'restarting dnsmasq...'
    systemctl restart dnsmasq
}

add_rules_iptables()
{
	iptables -t nat -N SHADOWSOCKS

	# Ignore these IPs, the IP of proxy server should be included here
	iptables -t nat -A SHADOWSOCKS -d [remote-proxy-server] -j RETURN
	# Ignore LANs IP address
	iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

	iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports $ss_port

	# using PREROUTING if you're using openwrt
	#iptables -t nat -I PREROUTING -p tcp -j SHADOWSOCKS
	iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
}

remove_rules()
{
	iptables -t nat -F #SHADOWSOCKS
	#iptables -t nat -D SHADOWSOCKS
	#iptables -t nat -D OUTPUT -p tcp -j SHADOWSOCKS
	#iptables -t nat -X SHADOWSOCKS

    ipset flush gfwlist
}

flash_iptables()
{
	echo "flushing all iptables rules..."

	ipset flush gfwlist

	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT

	echo "iptables flushed."
}

init_proxy()
{
	if [[ $1 = "auto" ]]; then
		echo "initiliazing proxy in auto mode..."
		echo "adding ipset for ss-redir..."
		add_rules_ipset			
	else
		echo "initiliazing proxy in global mode..."
		echo "adding iptables rules for ss-redir..."
		add_rules_iptables		
	fi

	echo "starting ss-redir on port ${ss_port}..."
	nohup $ss_redir -c $ss_config 2>/tmp/ss-redir.log &
	echo "ss-redir started."

	echo "start ss-tunnel on port ${dns_port}..."
	nohup $ss_tunnel -c $ss_config -l $dns_port -L 8.8.8.8:53 -u 2>/tmp/ss-tunnel.log &
	echo "ss-tunnel started."	

	echo "all done!"
}

stop_proxy() {
	echo "stopping ss-redir..."
	killall -9 ss-redir
	echo "ss-redir killed."

	echo "stop ss-tunnel..."
	killall -9 ss-tunnel
	echo "ss-tunnel killed."

	echo removing shadowsocks firewall rules...
    remove_rules
	echo "firewall rules removed."

	echo "all done!"
}

check_status()
{
	isfound=$(ps aux | grep "ss-redir" | grep -v "grep"); 
	if [ -z "$isfound" ]; then
		echo "ss-redir is dead!"
	else
		echo "ss-redir is alive"
	fi

	isfound=$(ps aux | grep "ss-tunnel" | grep -v "grep"); 
	if [ -z "$isfound" ]; then
		echo "ss-tunnel is dead!"
	else
		echo "ss-tunnel is alive"
	fi

	echo "iptable nat rules:"
	iptables -t nat -L
	
	echo "ipset list:"
	ipset list gfwlist

#	echo "nat rules list:"
#	iptables -t nat -L
}

if [ $# -eq 0 ]; then 
	check_status
	exit 0
fi

if [[ $1 = "start" ]]; then
	init_proxy auto
elif [[ $1 = "start_auto" ]]; then
	init_proxy auto
elif [[ $1 = "start_global" ]]; then
	init_proxy global
elif [[ $1 = "stop" ]]; then
	stop_proxy
elif [[ $1 = "flush" ]]; then
	flash_iptables
else
	check_status
fi

exit 0