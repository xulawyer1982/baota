# 宝塔面板Docker镜像

基于Debian12构建的宝塔面板镜像，为dockerfile使用宝塔官方脚本自动构建，无人工干预，安全有保障，dockerfile公开可自定义构建

面板版本随官方安装脚本更新

可使用host网络模式部署，也可使用macvlan网络模式部署作为独立主机（在特权模式下可设置单独的防火墙）


## 镜像简介


1. `baota:minimal`
   
   仅安装了最新版宝塔面板

2. `baota:lnmp`

   基于`baota:minimal`，安装了完整的LNMP环境(nginx1.24,mysql5.7,php7.4/8.2,phpmyadmin5.1,redis7.2)

## 镜像使用

1. 镜像运行命令

   ```bash
   # 普通模式
   docker run -d eyunzhu/baota:lnmp

   # 特权模式 可以单独使用防火墙
   docker run -d --privileged --entrypoint="/bin/bash" eyunzhu/baota:lnmp -c "/usr/local/bin/boot.sh & exec /lib/systemd/systemd"
   ```
2. 面板基本信息
   1. 面板管理地址：http://您的ip地址:8888/btpanel
   2. 默认用户：username
   3. 默认密码：password
3. 目录 （宝塔默认未更改）
   1. 容器里面的网站数据目录：`/www/wwwroot`
   2. MySQL数据目录：`/www/server/data`
   3. vhost文件路径：`/www/server/panel/vhost`
4. 常用部署命令记录
   ```bash
   # 普通模式
   docker run -d --name='bt_1' --net macvlan-net --ip 192.168.1.211 eyunzhu/baota:lnmp

   # 特权模式 使用macvlan
   docker run -d --privileged --name='bt_2' --net macvlan-net --ip 192.168.1.201 --entrypoint="/bin/bash" eyunzhu/baota:lnmp -c "/usr/local/bin/boot.sh & exec /lib/systemd/systemd"
   ```


## 自主构建镜像方法
可自行修改dockerfile文件，自定义构建镜像

1. 项目目录结构
   
   ```plaintext
   .
   ├── dockerfiles
   │   ├── dockerfile.baota               # Baota 面板基础镜像 dockerfile
   │   └── dockerfile.baota-lnmp          # Baota 面板 LNMP 镜像 dockerfile
   ├── references                         # 参考目录
   ├── scripts
   │   ├── boot.sh                        # 自定义初始化脚本
   │   └── iptables-rules.sh              # IPTables 规则脚本
   ├── .dockerignore                      # Docker 镜像忽略文件
   └── README.md
   ```
2. 构建命令
      在项目根目录下执行构建
   
   1. `baota:minimal`
      ```bash
      docker build -t eyunzhu/baota:minimal -f ./dockerfiles/dockerfile.baota . 

      # 或者后台运行构建
      nohup docker build --network macvlan-net -t eyunzhu/baota:minimal -f ./dockerfiles/dockerfile.baota . > 1.log 2>&1 &
      ```
   2. `baota:lnmp`
      ```bash
      docker build -t eyunzhu/baota:lnmp -f ./dockerfiles/dockerfile.baota-lnmp . 

      # 或者后台运行构建
      nohup docker build --network macvlan-net -t eyunzhu/baota:lnmp -f ./dockerfiles/dockerfile.baota-lnmp . > 2.log 2>&1 &
      ```

## 问题注意
1. 防火墙
   - 一般部署不需要注意防火墙，若使用macvlan网络模式部署容器作为独立主机使用需要注意
   - 此镜像防火墙仅安装了iptables

      修改防火墙请在容器`/usr/local/bin/iptables-rules.sh`脚本中

      修改完成后运行一次`/usr/local/bin/iptables-rules.sh`脚本即可

      不要在面板管理规则，且面板中端口只显示ipv4的规则（面板调用的是ufw,镜像未安装，测试ufw在容器中有问题）





