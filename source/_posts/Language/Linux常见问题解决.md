---
title: Linux常见问题解决
author: 汪寻
date: 2019-08-07 13:26:42
updated: 2019-08-07 13:36:53
tags:
 - Linux
categories:
 - Language

---

Linux常见问题解决。

<!-- more -->

### Linux下MySQL安装

```shell
# 判断是否安装MySQL
rpm -qa | grep mysql
rpm -e --nodeps 安装包名称  # 卸载指定安装包
# 下载server和client RPM包，在https://dev.mysql.com/downloads/mysql/下选择 SUSE Linux Enterprise Server**，然后选择MySQL Server和Client Utilities两个版本下载
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-community-server-8.0.22-1.sl15.x86_64.rpm


# 在线安装MySQL57
wget -i -c http://dev.mysql.com/get/mysql57-community-release-el7-10.noarch.rpm
yum -y install mysql57-community-release-el7-10.noarch.rpm
yum -y install mysql-community-server
systemctl start  mysqld.service  # 开启mysqld服务
systemctl status mysqld.service  # 查看mysqld状态
grep "password" /var/log/mysqld.log  # 查看临时密码，并用这个密码登录
mysql -uroot -p

set global validate_password_policy=0;  # 设置密码策略
set global validate_password_length=1;  # 设置密码长度
ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';  # 修改root密码
# 设置为外部机器也可以访问
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'IDENTIFIED BY '123456' WITH GRANT OPTION;
FLUSH PRIVILEGES;  # 刷新权限
exit;

# 因为安装了Yum Repository，以后每次yum操作都会自动更新，需要把这个卸载掉
yum -y remove mysql57-community-release-el7-10.noarch
```

### Securecrt连接Mac本地终端

```shell
# ①启动sshd服务：
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
# ②查看是否启动：（返回-       0       com.openssh.sshd即为成功）
sudo launchctl list | grep ssh
```

③ 登录后中文乱码的解决方法：
secureCRT连接设置编码为UTF-8编码
在/etc/profile最后加入 export LANG=zh_CN.UTF-8
修改/etc/profile 提示文件只读。 sudo chmod +w /etc/profile
执行 source /etc/profile

### Centos8开放防火墙端口

```shell
# 查看centos版本号
cat /etc/redhat-release 
# 查看防火墙某个端口是否开放
firewall-cmd --query-port=3306/tcp
# 开放防火墙端口3306
firewall-cmd --zone=public --add-port=3306/tcp --permanent
# 查看防火墙状态
systemctl status firewalld
# 关闭防火墙
systemctl stop firewalld
# 打开防火墙
systemctl start firewalld
# 开放一段端口，开放了之后需要重启防火墙
firewall-cmd --zone=public --add-port=40000-45000/tcp --permanent
# 查看开放的端口列表
firewall-cmd --zone=public --list-ports
```

### 时钟同步

同步到阿里云服务器

```shell
# 安装crontab
yum install -y ntp
# 添加定时任务
crontab -e
# 内容:*/1 * * * * /usr/sbin/ntpdate ntp4.aliyun.com;
# 每分钟进行一次时钟同步，前提是可以联网
```

### OpenVPN

网上直接搜 openvpn-install.sh 脚本自动安装配置 OpenVPN server 和 client，下面是手动安装步骤。

### 管理Python虚拟环境

使用Virtaulenvwrapper来管理Python虚拟环境，将所有虚拟环境整合在一个目录下 - 管理（新增，删除，复制）虚拟环境 - 快速切换虚拟环境。

1. 安装
   
   ```shell
   # on Windows
   pip install virtualenvwrapper-win
   # on macOS / Linux
   pip install --user virtualenvwrapper
   # then make Bash load virtualenvwrapper automatically
   vim ~/.bashrc
   
   export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
   export WORKON_HOME=~/virtualenvs
   source /usr/local/bin/virtualenvwrapper.sh
   
   source ~/.bashrc
   ```

2. 创建虚拟环境
   
   ```shell
   # on macOS/Linux:
   mkvirtualenv --python=python3.6 env
   # on Windows
   mkvirtualenv --python=python3 env
   ```

3. 管理环境
   
   ```shell
   workon  # 列出虚拟环境列表
   workon env  # 切换环境到env
   deactivate  # 退出环境
   rmvirtualenv env  # 删除指定环境
   ```

### nethogs流量监控

NetHogs 是一个开源的命令行工具(类似于Linux的top命令)，用来按进程或程序实时统计网络带宽使用率。

最好是放在screen中执行，不然会随着当前终端的关闭而终止。

```shell
yum -y install nethogs  # 安装
nethogs  # 简单使用
nethogs -d 5  # 5s刷新一次，默认3s
nethogs -v 3  # 按M为单位返回数据
nethogs -d 60 -v 3 >> nethogs.log  # 将查询的数据写入文件，使用cat可以查看
```

### screen多重视窗管理

**Screen**是一款由GNU计划开发的用于命令行终端切换的自由软件。用户可以通过该软件同时连接多个本地或远程的命令行会话，并在其间自由切换。GNU Screen可以看作是窗口管理器的命令行界面版本。它提供了统一的管理多个会话的界面和相应的功能。

**会话恢复**

只要Screen本身没有终止，在其内部运行的会话都可以恢复。这一点对于远程登录的用户特别有用——即使网络连接中断，用户也不会失去对已经打开的命令行会话的控制。只要再次登录到主机上执行screen -r就可以恢复会话的运行。同样在暂时离开的时候，也可以执行分离命令detach，在保证里面的程序正常运行的情况下让Screen挂起（切换到后台）。这一点和图形界面下的VNC很相似。

**多窗口**

在Screen环境下，所有的会话都独立的运行，并拥有各自的编号、输入、输出和窗口缓存。用户可以通过快捷键在不同的窗口下切换，并可以自由的重定向各个窗口的输入和输出。Screen实现了基本的文本操作，如复制粘贴等；还提供了类似滚动条的功能，可以查看窗口状况的历史记录。窗口还可以被分区和命名，还可以监视后台窗口的活动。 会话共享 Screen可以让一个或多个用户从不同终端多次登录一个会话，并共享会话的所有特性（比如可以看到完全相同的输出）。它同时提供了窗口访问权限的机制，可以对窗口进行密码保护。

```shell
yum -y install screen  # 安装
screen -S yourname  # 新建一个叫yourname的session（常用）
screen -ls  # 列出当前所有的session（常用）
screen -r yourname  # 进入yourname这个session（常用）
screen -d yourname  # 远程detach某个session
screen -d -r yourname  # 结束当前session并回到yourname这个session
screen -wipe  # 检查目前所有的screen作业，并删除已经无法使用的screen作业（常用）

# 在每个screen session 下，所有命令都以 ctrl+a(C-a) 开始，键入以下命令操作（常用d暂时离开当前会话）
C-a ?  # 显示所有键绑定信息
C-a c  # 创建一个新的运行shell的窗口并切换到该窗口
C-a n  # Next，切换到下一个 window 
C-a p  # Previous，切换到前一个 window 
C-a 0..9  # 切换到第 0..9 个 window
C-a [Space]  # 由视窗0循序切换到视窗9
C-a C-a  # 在两个最近使用的 window 间切换 
C-a x  # 锁住当前的 window，需用用户密码解锁
C-a d  # detach，暂时离开当前session，将目前的 screen session (可能含有多个 windows) 丢到后台执行，并会回到还没进 screen 时的状态，此时在 screen session 里，每个 window 内运行的 process (无论是前台/后台)都在继续执行，即使 logout 也不影响。 
C-a z  # 把当前session放到后台执行，用 shell 的 fg 命令则可回去。
C-a w  # 显示所有窗口列表
C-a t  # time，显示当前时间，和系统的 load 
C-a k  # kill window，强行关闭当前的 window
C-a [  # 进入 copy mode，在 copy mode 下可以回滚、搜索、复制就像用使用 vi 一样
    C-b Backward，PageUp 
    C-f Forward，PageDown 
    H(大写) High，将光标移至左上角 
    L Low，将光标移至左下角 
    0 移到行首 
    $ 行末 
    w forward one word，以字为单位往前移 
    b backward one word，以字为单位往后移 
    Space 第一次按为标记区起点，第二次按为终点 
    Esc 结束 copy mode 
C-a ]  # paste，把刚刚在 copy mode 选定的内容贴上
```

### Centos中文乱码

是在解决docker中的centos8显示中文乱码的时候找到这个解决办法的，安装中文包在设置支持的语言包即可

```bash
yum search Chinese
yum -y install langpacks-zh_CN.noarch
localectl set-locale LANG=zh_CN.utf8
# 如果还未生效重启当前会话
```

### wget下载网站某个目录所有文件

```shell
wget -np -nH -r -k -p –span-hosts https://www.docs4dev.com/docs/en/apache-hive/3.1.1
/reference

# -c 断点续传
# -r 递归下载，下载指定网页某一目录下（包括子目录）的所有文件
# -nd 递归下载时不创建一层一层的目录，把所有的文件下载到当前目录
# -np 递归下载时不搜索上层目录，如wget -c -r www.xianren.org/pub/path/
# 没有加参数-np，就会同时下载path的上一级目录pub下的其它文件
# -k 将绝对链接转为相对链接，下载整个站点后脱机浏览网页，最好加上这个参数
# -L 递归时不进入其它主机，如wget -c -r www.xianren.org/
# 如果网站内有一个这样的链接：
# www.xianren.org，不加参数-L，就会像大火烧山一样，会递归下载www.xianren.org网站
# -p 下载网页所需的所有文件，如图片等
# -A 指定要下载的文件样式列表，多个样式用逗号分隔
# -i 后面跟一个文件，文件内指明要下载的URL
```

### Centos8安装Openvpn无法上网

1、开启内核 IP 地址转发
首先查看内核是否开启 IP 地址转发功能

```shell
cat /proc/sys/net/ipv4/ip_forward
```

返回为 1 已开启，返回 0 则需要手动开一下。
以 root 用户身份执行

```shell
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
cat /proc/sys/net/ipv4/ip_forward
```

2、防火墙允许 IP 地址转发
默认情况下 firewalld 会禁止转发流量，可以执行 firewall-cmd --query-masquerade 查看状态，如果是 no，可执行下面的命令开启转发。
开启 IP 地址转发

```shell
firewall-cmd --add-masquerade --permanent  #开启 IP 地址转发
firewall-cmd --reload  #重载防火墙规则，使之立即生效
```

### Openvpn不让所有流量都走VPN

通过自动安装脚本`openvpn-install.sh`安装的Openvpn默认设置的所有流量都经过VPN，就会造成异地登陆，网络卡顿，耗费服务器带宽的影响，所以一般只允许Openvpn指定网段下的地址走VPN，其余还是走本地，这样设置也可以同时连接多个VPN不冲突。

在客户端加入`route-nopull`配置目的是不从服务端拉取路由表，对于WIN10中的客户端配置需要删除`block-outside-dns`这一行，Linux则可以不删，因为这个设置， OpenVPN 会添加 Windows 防火墙记录。

### Vim相关配置

修改~/.vimrc文件

```bash
" 显示中文 "
  set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
  set termencoding=utf-8
  set encoding=utf-8
" 自动语法高亮 " 
  syntax on
" 检测文件类型  "
  filetype on
" 设定 tab 长度为 4  "
  set tabstop=4
" 设置按BackSpace的时候可以一次删除掉4个空格 " 
  set softtabstop=4
" 搜索时忽略大小写，但在有一个或以上大写字母时仍大小写敏感  "
  set ignorecase
  set smartcase
" 实时搜索  "
  set incsearch
" 搜索时高亮显示被找到的文本  "
  set hlsearch
" 关闭错误声音  "
  set noerrorbells
  set novisualbell
" 智能自动缩进  "
  set smartindent
```