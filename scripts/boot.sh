#!/bin/bash

# 当前脚本会在容器启动时执行 
# 脚本位置：/usr/local/bin/boot.sh


# 初始化：还原mysql数据目录 此处为解决安装了数据库的镜像在构建时备份并清空了数据目录，一方面可以减少镜像大小，另一方面可以解决挂载目录时data被宿主机覆盖的问题
if [ -d /www/server/data ] && [ ! "$(ls -A /www/server/data)" ] && [ -f /www/server/data_backup.tar.gz ]; then
  # 数据库目录为空 并且/www/server/data_backup.tar.gz存在
  # 还原数据
  echo "初始化：还原mysql数据目录"
  tar xzf /www/server/data_backup.tar.gz -C /www/server
  rm -rf /www/server/data_backup.tar.gz
  /etc/init.d/mysqld start
fi


# 启动面板
/usr/bin/bt stop
/usr/bin/bt start


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