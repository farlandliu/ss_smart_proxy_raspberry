[Unit]
Description=shadowsocks proxy service
After=network.target

[Service]
User=root
Type=oneshot
ExecStart=/opt/shadowsocks/shadowsocks start
ExecStop=/opt/shadowsocks/shadowsocks stop
RemainAfterExit=yes
#PIDFile=/run/n2n.pid

[Install]
WantedBy=multi-user.target