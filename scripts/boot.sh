#!/bin/bash

# 当前脚本会在容器启动时执行 
# 脚本位置：/usr/local/bin/boot.sh


# 初始化：还原面板数据
if [ -f /www_backup.tar.gz ]; then
  # www目录为空 并且/www.tar.gz存在
  # 还原数据
  echo "初始化：还原面板数据"
  tar xzf /www_backup.tar.gz -C /
  rm -rf /www_backup.tar.gz
fi


# 启动面板
/usr/bin/bt stop
/usr/bin/bt start

# 扫描并启动所有服务
init_scripts=$(ls /etc/init.d)
  for script in ${init_scripts}; do
      /etc/init.d/${script} start
done


# 运行防火墙规则
# 检查 /lib/systemd/systemd 是否在运行
if ps -p 1 | grep -q "systemd"; then
    echo "运行systemd"
    chmod +x /usr/local/bin/iptables-rules.sh
    /usr/local/bin/iptables-rules.sh
else
   echo "未运行systemd"
fi


tail -f /dev/null