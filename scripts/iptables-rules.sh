#!/bin/bash
# 当前脚本会在容器启动时执行
# 用途：解决容器重启防火墙规则消失的问题、容器中iptables规则异常的问题
# 脚本位置：/usr/local/bin/iptables-rules.sh
# 配置文件位置：/etc/iptables/ports.conf
# 注意：本脚本通过读取配置文件来开放端口，请勿直接修改脚本内部的端口列表。

# --- 配置区 ---
# 定义端口配置文件的路径
PORTS_CONFIG_FILE="/etc/iptables/ports.conf"

# --- 核心逻辑 ---

# 函数：记录消息到标准输出
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [IPTABLES SCRIPT] $1"
}

# 函数：处理并设置指定IP版本的iptables规则
set_iptables_rules() {
    local ip_version="$1" # "ipv4" 或 "ipv6"
    local ipt_cmd=""
    local msg_prefix=""

    if [[ "$ip_version" == "ipv4" ]]; then
        ipt_cmd="iptables"
        msg_prefix="IPv4"
    elif [[ "$ip_version" == "ipv6" ]]; then
        ipt_cmd="ip6tables"
        msg_prefix="IPv6"
    else
        log_message "错误: 未知的 IP 版本 '$ip_version'"
        return 1
    fi

    log_message "--- 配置 $msg_prefix 防火墙规则开始 ---"

    # 1. 清空所有链的规则，并删除用户自定义链
    log_message "清空 $msg_prefix 已有规则..."
    "$ipt_cmd" -F INPUT || { log_message "清空 $msg_prefix INPUT 链失败"; return 1; }
    "$ipt_cmd" -F FORWARD || { log_message "清空 $msg_prefix FORWARD 链失败"; return 1; }
    "$ipt_cmd" -F OUTPUT || { log_message "清空 $msg_prefix OUTPUT 链失败"; return 1; }
    "$ipt_cmd" -X || { log_message "删除 $msg_prefix 用户自定义链失败"; return 1; }
    "$ipt_cmd" -Z || { log_message "清零 $msg_prefix 计数器失败"; return 1; }

    # 2. 设置默认策略为 DROP，这是最安全的起点
    log_message "设置 $msg_prefix 默认策略为 INPUT/FORWARD DROP, OUTPUT ACCEPT..."
    "$ipt_cmd" -P INPUT DROP || { log_message "设置 $msg_prefix INPUT 策略为 DROP 失败"; return 1; }
    "$ipt_cmd" -P FORWARD DROP || { log_message "设置 $msg_prefix FORWARD 策略为 DROP 失败"; return 1; }
    "$ipt_cmd" -P OUTPUT ACCEPT || { log_message "设置 $msg_prefix OUTPUT 策略为 ACCEPT 失败"; return 1; }

    # 3. 允许回环接口（本地通信）
    log_message "允许 $msg_prefix 回环接口 (lo)..."
    "$ipt_cmd" -A INPUT -i lo -j ACCEPT || { log_message "允许 $msg_prefix lo 接口失败"; return 1; }

    # 4. 允许已建立或相关的连接通过
    log_message "允许 $msg_prefix 已建立或相关的连接..."
    "$ipt_cmd" -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || { log_message "允许 $msg_prefix ESTABLISHED,RELATED 连接失败"; return 1; }

    # 在设置完基本规则后，添加IPv6特殊规则
    if [[ "$ip_version" == "ipv6" ]]; then
        log_message "添加IPv6特殊规则..."
        
        # 放行ICMPv6（IPv6网络基础协议）
        "$ipt_cmd" -A INPUT -p ipv6-icmp -j ACCEPT || { log_message "允许ICMPv6失败"; return 1; }
        
        # 放行邻居发现协议(NDP)所需的多播地址
        "$ipt_cmd" -A INPUT -d ff02::/16 -p udp -j ACCEPT || { log_message "允许NDP多播失败"; return 1; }
        
        # 放行DHCPv6通信（如果使用）
        "$ipt_cmd" -A INPUT -p udp --dport 546 -j ACCEPT || { log_message "允许DHCPv6失败"; return 1; }
    fi

    if [[ "$ip_version" == "ipv4" ]]; then
        "$ipt_cmd" -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    fi

    # 5. 读取配置文件并开放指定端口
    if [[ ! -f "$PORTS_CONFIG_FILE" ]]; then
        log_message "警告: 端口配置文件 '$PORTS_CONFIG_FILE' 不存在。未开放任何端口。"
        return 0
    fi

    log_message "从配置文件 '$PORTS_CONFIG_FILE' 读取端口规则..."
    while IFS= read -r line; do
        # 移除行首尾空格
        line=$(echo "$line" | xargs)
        # 跳过空行和注释行
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        local port_spec="$line"
        local port_range=""
        local protocol=""

        # 检查是否指定了协议 (e.g., 80/tcp, 443/udp)
        if [[ "$port_spec" =~ ^([0-9]+(-[0-9]+)?)/(tcp|udp)$ ]]; then
            port_range="${BASH_REMATCH[1]}"
            protocol="${BASH_REMATCH[3]}"
        else
            port_range="$port_spec"
        fi

        # 处理端口范围或单个端口
        if [[ "$port_range" =~ ^[0-9]+-[0-9]+$ ]]; then
            # 端口范围
            local start_port=$(echo "$port_range" | cut -d'-' -f1)
            local end_port=$(echo "$port_range" | cut -d'-' -f2)

            if [[ -z "$protocol" || "$protocol" == "tcp" ]]; then
                "$ipt_cmd" -A INPUT -p tcp --dport "$start_port":"$end_port" -j ACCEPT || { log_message "允许 $msg_prefix TCP 端口范围 $port_range 失败"; }
                log_message "$msg_prefix 允许 TCP 端口范围 $port_range"
            fi
            if [[ -z "$protocol" || "$protocol" == "udp" ]]; then
                "$ipt_cmd" -A INPUT -p udp --dport "$start_port":"$end_port" -j ACCEPT || { log_message "允许 $msg_prefix UDP 端口范围 $port_range 失败"; }
                log_message "$msg_prefix 允许 UDP 端口范围 $port_range"
            fi
        elif [[ "$port_range" =~ ^[0-9]+$ ]]; then
            # 单个端口
            local single_port="$port_range"

            if [[ -z "$protocol" || "$protocol" == "tcp" ]]; then
                "$ipt_cmd" -A INPUT -p tcp --dport "$single_port" -j ACCEPT || { log_message "允许 $msg_prefix TCP 端口 $single_port 失败"; }
                log_message "$msg_prefix 允许 TCP 端口 $single_port"
            fi
            if [[ -z "$protocol" || "$protocol" == "udp" ]]; then
                "$ipt_cmd" -A INPUT -p udp --dport "$single_port" -j ACCEPT || { log_message "允许 $msg_prefix UDP 端口 $single_port 失败"; }
                log_message "$msg_prefix 允许 UDP 端口 $single_port"
            fi
        else
            log_message "警告: 配置文件中包含无效的端口规则: '$line'"
        fi
    done < "$PORTS_CONFIG_FILE"

    # 6. 显示最终规则
    log_message "$msg_prefix INPUT 链最终规则:"
    "$ipt_cmd" -L INPUT -v -n --line-numbers

    log_message "--- 配置 $msg_prefix 防火墙规则结束 ---"
    echo "" # 添加空行用于分隔不同 IP 版本的输出
    return 0
}

if [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) == "1" ]]; then
    log_message "警告：系统IPv6支持已禁用，IPv6规则将不会生效"
fi

# --- 执行规则设置 ---
log_message "------- iptables-rules.sh 脚本开始执行 -------"
set_iptables_rules "ipv4"
set_iptables_rules "ipv6"
log_message "------- iptables-rules.sh 脚本执行完毕 -------"