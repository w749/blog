---
title: Windows常用命令
author: 汪寻
date: 2019-08-17 21:22:22
update: 2019-08-17 21:53:39
tags:
 - Windows
categories:
 - Language

---

Windows常用操作命令。

<!-- more -->

### Windows关机命令

```shell
# 立即关机
shutdown -s
# 十五分钟后关机单位是秒，默认为30s
shutdown -s -t 900
# 立即重启电脑
shutdown -r -t 0
# 关闭定时关机计划
shutdown -a
```

### VM虚拟机端口映射

主要解决的是以供另外一台主机连接当前主机内的虚拟机，思路是将当前主机下的所有虚拟机的22端口全部映射到当前主机的不同端口，这样另外一台主机直接连接当前主机的映射端口即可达到远程登录虚拟机的效果了。这里的当前主机指的是Windows及Windows下的vmware虚拟机

```shell
# 查看已有的所有端口映射
netsh interface portproxy show all
# 端口映射，将192.168.150.128虚拟机的22端口映射到主机的9000端口上并监听所有访问地址
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8032 connectaddress=node01 connectport=8032
# 删除已有的映射关系，只需删除监听的这个端口
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=9000
# 另外一台主机连接当前主机虚拟机，假设当前主机IP地址为192.168.192.195，root为虚拟机用户名，密码为虚拟机密码
ssh root@192.168.192.195

# 添加多个端口映射
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=9201 connectaddress=192.168.163.100 connectport=9200
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=9202 connectaddress=192.168.163.110 connectport=9200
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=9203 connectaddress=192.168.163.120 connectport=9200
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=5601 connectaddress=192.168.163.100 connectport=5601
# 添加防火墙规则
netsh advfirewall firewall add rule name="node01 9200" dir=in action=allow protocol=tcp localport=9201
netsh advfirewall firewall add rule name="node02 9200" dir=in action=allow protocol=tcp localport=9202
netsh advfirewall firewall add rule name="node03 9200" dir=in action=allow protocol=tcp localport=9203
netsh advfirewall firewall add rule name="node01 5601" dir=in action=allow protocol=tcp localport=5601
```

### Windows curl

```shell
Invoke-WebRequest http://localhost:5601 -Method GET  -UseBasicParsing
```

### Windows端口管理

```shell
netstat -ano  # 查看所有端口占用情况
netstat -aon|findstr "5601"  # 查询指定端口的占用情况
tasklist|findstr "3372"  # 查看PID对应的进程
taskkill /f /t /im javaw.exe  # 强制终止该进程及子进程（一定得搞清楚进程作用再终止！！！）
```

### 查看Windows内存

```shell
systeminfo  # 查看Windows基本信息以及内存使用情况
```
