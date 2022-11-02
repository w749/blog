---
title: Docker WordPress的Nginx应用
author: 汪寻
date: 2021-03-31
tags:
 - Docker
categories:
 - Software
---

前一段时间用 Docker 在服务器部署了一个 WordPress 博客，部署起来倒很简单，Docker 镜像都是封装好拿来即用的，问题出现在前两天想在 Docker 中部署 ssl 的时候。

<!-- more -->

我先是在阿里云申请了域名和免费一年的ssl，随后部署的时候就出现问题了，首先我用 Nginx 在服务器上直接部署 ssl，它显示 WordPress 和 Nginx 监听的端口冲突，失败；接下来我直接在 WordPress 所在的容器进行 ssl 部署，用的是容器自带的 Apache，由于配置文件的原因和我所申请的 ssl 是指定的域名导致一直不能成功，失败；然后我又想着把 WordPress 和 Nginx 全部装在服务器上，在服务器完成搭建 WordPress 和配置 ssl 的过程，结果直接卡在了 WordPress 搭建这里，失败；无奈最后服务器端 iptables 和 Docker 等一众服务全都出现问题，不能重启也找不到 docker. service，只能将云盘清空重新将 WordPress 部署在 Docker 中，再将以前备份的数据库恢复，万幸是恢复如初了，再没敢动配置 ssl 这个心思。

昨晚把这个事仔细想了想，有两个方法可以实现这个需求，第一是使用 Docker 内部的 Apache 继续配置，在 Docker 中就只是传入 pem 和 key 文件再配置 conf 文件就行了，上次是由于没了解各参数所代表的意思，跟着网上的教程乱配一通：还有一种方法是再开一个 Nginx 容器，监听服务器的 80 和 443 端口，再转发给 WordPress 对外暴露的 3344 和 4455 端口，实现一个服务器内部端口转发的功能，这样只暴露 Nginx 的 80 和 443 端口就可以了，其他端口都是内部使用。

当然这只是个人想法，还不确定能不能实现，我对 Nginx 这个做法比较感兴趣，但确定的是再也不敢直接在服务器端尝试了，有时间了重新搭建一个 WordPress 容器测试没问题了再应用在生产中，不然又得经历一次清盘操作了。
