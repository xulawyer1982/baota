#!/bin/bash

# 当前脚本会在容器启动时执行 

# 用途：解决容器重启防火墙规则消失的问题、容器中iptables规则异常的问题
# 脚本位置：/usr/local/bin/iptables-rules.sh

# 注意：要放行端口只需修改ports数组即可，切勿修改其他地方
#      反正就目前文件执行不会出问题，不要修改执行顺序之类的
#      目前发现使用 iptables -P INPUT DROP 或者 iptables -A INPUT -j DROP 会出现问题。所以目前不使用


# 放行端口 在这里修改
# 手动修改后可运行当前脚本生效： /usr/local/bin/iptables-rules.sh
# 已经加入Systemd服务会容器启动会自动运行

ports=(22 80 443 8888)

# 清空已有规则
iptables -F INPUT
iptables -F FORWARD
iptables -F OUTPUT
iptables -X
iptables -Z

ip6tables -F INPUT
ip6tables -F FORWARD
ip6tables -F OUTPUT
ip6tables -X
ip6tables -Z

# 设置默认策略为ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

# 允许回环接口（本地通信）
iptables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT

# 拒绝所有端口tcp和udp 
# 这里使用端口范围的方式，
# 不可使用'iptables -A INPUT -j DROP','iptables -P INPUT DROP'
# 貌似要在允许端口之前执行 否则有问题
iptables -A INPUT -p tcp --dport 0:65535 -j DROP
iptables -A INPUT -p udp --dport 0:65535 -j DROP
ip6tables -A INPUT -p tcp --dport 0:65535 -j DROP
ip6tables -A INPUT -p udp --dport 0:65535 -j DROP

# 允许已建立或相关的连接通过
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 开放端口
for port in "${ports[@]}"; do
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT && echo "iptables允许 TCP 端口 $port"
    iptables -I INPUT -p udp --dport "$port" -j ACCEPT && echo "iptables允许 UDP 端口 $port"
    echo -e ''
    ip6tables -I INPUT -p tcp --dport "$port" -j ACCEPT && echo "ip6tables允许 TCP 端口 $port"
    ip6tables -I INPUT -p udp --dport "$port" -j ACCEPT && echo "ip6tables允许 UDP 端口 $port"
    echo -e '---------------------------'
done

echo -e ''
iptables -L INPUT -v -n --line-numbers
echo -e ''
ip6tables -L INPUT -v -n --line-numbers

echo -e '-------  iptables-rules.sh 结束  -------'
