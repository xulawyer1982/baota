# 宝塔面板Docker镜像

- 基于Debian12构建的宝塔面板镜像，为[github Actions自动构建](https://github.com/eyunzhu/baota/actions)，无人工干预，安全有保障，[dockerfile](https://github.com/eyunzhu/baota/tree/master/dockerfiles)公开可[自定义构建](##自主构建镜像方法)
- 优点
  - 可自由的挂载目录，数据迁移备份方便而不用操心容器环境，比官方更方便
  - dockerfile开源，github actions自动构建，安全，可自定义构建需要的环境
  - 镜像文件小
  - lnmp的镜像解决了官方镜像redis不能正常启动等问题(或者自行参考[宝塔容器非特权模式，redis无法启动的问题](https://github.com/eyunzhu/baota/blob/e0b85ba86b63bbb1997017424571de299b05a10d/scripts/boot.sh#L36C13-L38C76)解决)
  - 面板版本随官方安装脚本更新
- 可使用host网络模式部署，也可使用macvlan网络模式部署作为独立主机（在特权模式下可设置单独的防火墙）


## 镜像简介


1. `baota:minimal` 仅安装了最新版宝塔面板，未装运行环境软件
   
2. `baota:lnmp` 安装了完整的LNMP环境(nginx1.24,mysql8.4,php8.3,phpmyadmin5.1,redis7.2)

## 镜像使用

1. 目录挂载说明
   1. 可自由挂载`/www`及其之下的任何目录
   2. 建议直接挂载到`/www`，包含全部的运行环境，方便全息备份，迁移数据，重新部署
   3. 也可按需最小化挂载
      - 容器里面的网站数据目录：`/www/wwwroot`
      - MySQL数据目录：`/www/server/data`
      - vhost文件路径：`/www/server/panel/vhost`
   
2. 
   ```
3. 

4. 常用部署命令记录
   ```bash
   # 普通模式
   docker run -d --restart=unless-stopped --name='bt_1' -v /local/www:/www --net macvlan-net --ip 192.168.1.211 eyunzhu/baota:lnmp
   
   # 特权模式 使用macvlan 可单独设置iptables防火墙
   docker run -d --restart=unless-stopped --privileged --name='bt_2' -v /local/www:/www --net macvlan-net --ip 192.168.1.201 --entrypoint="/bin/bash" eyunzhu/baota:lnmp -c "/usr/local/bin/boot.sh & exec /lib/systemd/systemd"
   ```
5. 其他
   
   1. 若使用ssh,请到面板->安全->ssh管理->修改root密码



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





