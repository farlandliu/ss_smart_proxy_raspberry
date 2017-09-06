
note:
本文修改自gist :https://gist.github.com/lanceliao/3099caed8750911dfe58, 原文有很多地方看不太懂，重新整理了一下。

> 思路：国内域名用dnsmasq解析，国外域名用pdnsd解析

* 1 开启ipv4转发
```
vi /etc/sysctl.conf
# 将net.ipv4.ip_forward=0更改为net.ipv4.ip_forward=1
sysctl -p
```

* 2  安装和配置dnsmasq
  -安装
  ```
  sudo apt instal dnsmasq ipset -y
  ```

  - 配置
  ```
  # backup conf file
  sudo cp /etc/dnsmasq.conf dnsmasp.conf.bak
  # prepare resolv conf for dnsmasq service 
  sudo cp /etc/reslve.conf /etc/resolv.dnsmasq.conf 
  sudo cp /etc/hosts /etc/dnsmasq.hosts

  # open dnsmasq.conf
  sudo nano /etc/dnsmasq.conf

  # 设置项如下
  port=53
  conf-dir=/etc/dnsmasq.d
  resolv-file=/etc/resolv.dnsmasq.conf
  strict-order 
  listen-address=127.0.0.1,10.22.39.230
  addn-hosts=/etc/dnsmasq.hosts
  conf-dir=/etc/dnsmasq.d/,*.conf 
  address=/ad.iqiyi.com/127.0.0.1   #广告劫持
  #log-queries
  log-facility=/var/log/dnsmasq.log # for debug
  ```
  # resolv.dnsmasq.conf
  ```
  nameserver 10.2.1.175  #公司本地局域网DNS 或电信、联通等公共的DNS
  nameserver 114.114.114.114
  nameserver 114.114.115.115
  ```
  ##重要!!! 修改 /etc/default/dnsmasq
  ```
  sudo nano /etc/default/dnsmasq
  # 去掉下行的注释，防止dnsmasq读取/etc/resolv.conf
  IGNORE_RESOLVCONF=yes
  ```
* 3. 安装和配置pdnsd

  - 安装
  ```
  sudo apt install -y  pdnsd
  ```
  - pdnsd配置
  ```
  #vi /etc/pdnsd.conf 
  #修改端口并指定google的DNS
	  global {
		perm_cache=1024;
		cache_dir="/var/cache";
	  server_port=1053;
		server_ip = 127.0.0.1;  # Use eth0 here if you want to allow other
		#server_ip = any		# to do test
		status_ctl = on;
	  paranoid=on;       # This option reduces the chance of cache poisoning
		                    # but may make pdnsd less efficient, unfortunately.
		query_method=tcp_only;

		min_ttl=15m;       # Retain cached entries at least 15 minutes.
		max_ttl=1w;        # One week.
		timeout=10;        # Global timeout option (10 seconds).
		neg_domain_pol=on;
		udpbufsize=1024;   # Upper limit on the size of UDP messages.
	}

	server {
	    label="google-dns";
	    ip=8.8.8.8;
	    root_server=on;
	    uptest=none;
	}

	server { 
	    label="korea";
	    ip=49.238.213.1; 
	    root_server=on;
	    uptest=none;
	}

  ```
  修改 /etc/default/pdnsd
  ```
  START_DAEMON=yes
  ```

  - DNS测试

  ``` 
  systemctl restart dnsmasq
  systemctl restart pdnsd
  ```
   
  ```nslookup -port=1053 twitter.com 127.0.0.1```
  ```dig @127.0.0.1 -p 1053 www.google.com ```
  ```dig @10.22.39.230 -p 53 www.google.com ``` 
  #安装 dig
  ```sudo apt install dnsutils -y^C```



  - dnsmasq的配置
  这里需要特别注意，设置步骤如下：

  1. 


  ```
  vi /etc/dhcpcd.conf
  # 文件末尾加上两行(去掉注释)
  #  listen-address=127.0.0.1 
  # conf-dir=/etc/dnsmasq.d/,*.conf
  # 最后一行指定dnsmasq的解析规则目录，这里只解析被墙的域名,
  # 参考https://gist.github.com/lanceliao/85cd3fcf1303dba2498c的脚本生成一份污染域名列表放到该目录下，列表自带ipset规则

* 4 安装shadowsocks-libev

  ```
  #http://shadowsocks.org/en/download/servers.html 
  # for jessie
  sudo sh -c 'printf "deb http://httpredir.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/jessie-backports.list'
  sudo apt-get update
  sudo apt-get -t jessie-backports install shadowsocks-libev

  # for stretch
  # 在 /etc/apt/sources.list 文件中像下面这样添加一行:
  deb http://ftp.de.debian.org/debian stretch-backports main 
  sudo apt install shadowsocks-libev
  ```


3. 编写shadowsocks启动和停止脚本```shadowsocks.sh```，这个脚本将gfwlist的列表域名使用shadowsocks转发。dnsmasq的配置在```/etc/dnsmasq.d```目录下，由于gfwlist里面没有google的域名，我们另加一个配置文件:
	```
	server=/.google.com.hk/127.0.0.1#1053
	ipset=/.google.com.hk/gfwlist

	server=/.google.com/127.0.0.1#1053
	ipset=/.google.com/gfwlist

	server=/.google.jp/127.0.0.1#1053
	ipset=/.google.jp/gfwlist

	server=/.google.co.jp/127.0.0.1#1053
	ipset=/.google.co.jp/gfwlist

	server=/.google.co.uk/127.0.0.1#1053
	ipset=/.google.co.uk/gfwlist

	server=/.amazonaws.com/127.0.0.1#1053
	ipset=/.amazonaws.com/gfwlist
	```

4. 编写和启动shadowsocks服务```shadowsocks.service```
5. 参考
  - [dnsmasq](https://wiki.archlinux.org/index.php/Dnsmasq)
  - [DNSCrypt](https://wiki.archlinux.org/index.php/DNSCrypt)
  - [dnsmasq-gfwlist.py](https://gist.github.com/lanceliao/85cd3fcf1303dba2498c)
  - [使用ipset让openwrt上的shadowsocks更智能的重定向流量](https://hong.im/2014/07/08/use-ipset-with-shadowsocks-on-openwrt/)

