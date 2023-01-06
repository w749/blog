---
title: Dockerfile简单应用
author: 汪寻
date: 2021-04-11 11:25:57
update: 2021-04-11 11:45:18
tags:
 - Docker
categories:
 - Software
---

Dockerfile 是一个用来构建镜像的文本文件，结合Docker使用，构建自己的镜像，文本内容包含了一条条构建镜像所需的指令和说明。

<!-- more -->

#### **FROM**

基础镜像可以为任意镜像。如果基础镜像没有被发现，Docker将试图从Docker image index来查找该镜像。FROM命令必须是Dockerfile的首个命令。如果同一个DockerFile创建多个镜像时，可使用多个FROM指令（每个镜像一次）

```
# Usage: FROM [image name]
FROM ubuntu 
```

#### **MAINTAINER**

指定维护者的信息，并应该放在FROM的后面。

```
# Usage: MAINTAINER [name]
MAINTAINER authors_name 
```

#### **RUN**

RUN命令是Dockerfile执行命令的核心部分。它接受命令作为参数并用于创建镜像。不像CMD命令，RUN命令用于创建镜像（在之前commit的层之上形成新的层）。  
格式为Run 或者Run \[“executable” ,”Param1”, “param2”\]  
前者在shell终端上运行，即/bin/sh -C，后者使用exec运行。例如：RUN \[“/bin/bash”, “-c”,”echo hello”\]  
每条run指令在当前基础镜像执行，并且提交新镜像。当命令比较长时，可以使用“/”换行。

```
# Usage: RUN [command]
RUN apt-get update 
```

#### **USER**

格式为 USER daemon 。  
指定运行容器时的用户名或UID，后续的 RUN 也会使用指定用户。  
当服务不需要管理员权限时，可以通过该命令指定运行用户。并且可以在之前创建所需要的用户，例如： RUN groupadd -r postgres && useradd -r -g postgres postgres 。要临时获取管理员权限可以使用 gosu ，而不推荐 sudo 。

```
# Usage: USER [UID]
USER 751
```

#### **VOLUME**

VOLUME命令用于让你的容器访问宿主机上的目录。  
格式为 VOLUME \[“/data”\] 。  
创建一个可以从本地主机或其他容器挂载的挂载点，一般用来存放数据库和需要保持的数据等。

```
# Usage: VOLUME ["/dir_1", "/dir_2" ..]
VOLUME ["/my_files", "/app_files"]
```

#### **WORKDIR**

WORKDIR命令用于设置CMD指明的命令的运行目录。  
格式为 WORKDIR /path/to/workdir 。  
为后续的 RUN 、 CMD 、 ENTRYPOINT 指令配置工作目录。  
可以使用多个 WORKDIR 指令，后续命令如果参数是相对路径，则会基于之前命令指定的路径。例如:

```
WORKDIR /a 
WORKDIR b 
WORKDIR c 
RUN pwd 
# 最终路径为 /a/b/c 
```

#### **CMD**

支持三种格式：  
CMD \[“executable” ,”Param1”, “param2”\]使用exec执行，推荐  
CMD command param1 param2，在/bin/sh上执行  
CMD \[“Param1”, “param2”\] 提供给ENTRYPOINT做默认参数。  
每个容器只能执行一条CMD命令，多个CMD命令时，只最后一条被执行。

```
# Usage 1: CMD application "argument", "argument", ..
CMD "echo" "Hello docker!"
```

#### **ENV**

格式为 ENV 。 指定一个环境变量，会被后续 RUN 指令使用，并在容器运行时保持。

```
ENV TZ "Asia/Shanghai"
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
```

#### **ADD**

ADD命令有两个参数，源和目标。它的基本作用是从源系统的文件系统上复制文件到目标容器的文件系统。如果源是一个URL，那该URL的内容将被下载并复制到容器中。如果文件是可识别的压缩格式，则docker会帮忙解压缩。

```
# Usage: ADD [source directory or URL] [destination directory]
ADD /my_app_folder /my_app_folder 
```

#### **COPY（与ADD没有区别）**

COPY 将文件从路径 <src复制添加到容器内部路径 <dest>。

```
COPY <src> <dest>
```

#### **EXPOSE**

指定在docker允许时指定的端口进行转发

```
EXPOSE <port>[<port>...]
```

#### **ENTRYPOINT**

两种格式：  
ENTRYPOINT \["executable", "param1", "param2"\]  
ENTRYPOINT command param1 param2（shell中执行）。  
配置容器启动后执行的命令，并且不可被 docker run 提供的参数覆盖。  
每个 Dockerfile 中只能有一个 ENTRYPOINT，当指定多个时，只有最后一个起效。

#### **以构建Flume为示例**

```dockerfile
FROM centos

_# install java_
ADD _https://repo.huaweicloud.com/java/jdk/8u181-b13/jdk-8u181-linux-x64.tar.gz_ _/usr/local_
RUN _tar_ _-zxvf_ _/usr/local/jdk-8u181-linux-x64.tar.gz_ _-C_ _/usr/local/_
RUN _rm_ _-rf_ _/usr/local/jdk-8u181-linux-x64.tar.gz_
ENV JAVA_HOME _/usr/local/jdk1.8.0_181_
ENV PATH $JAVA_HOME_/bin:_$PATH
ENV CLASSPATH _.:_$JAVA_HOME_/lib_

_# install Flume_
ADD _https://mirrors.tuna.tsinghua.edu.cn/apache/flume/1.9.0/apache-flume-1.9.0-bin.tar.gz_ _/usr/local_
RUN _tar_ _-zxvf_ _/usr/local/apache-flume-1.9.0-bin.tar.gz_ _-C_ _/usr/local/_
RUN _rm_ _-rf_ _/usr/local/apache-flume-1.9.0-bin.tar.gz_
RUN _mv_ _/usr/local/apache-flume-1.9.0-bin_ _/usr/local/flume_
WORKDIR _/usr/local/flume_
ADD _flume-env.sh_ _/usr/local/flume/conf_

# export port
EXPOSE _1999_
```

#### **Docker镜像打包**

```bash
# 以打包flume为例，先cd到Dockerfile所在的目录
# 发布到Docker Hub
docker build -t flume .
docker tag flume wxk749/flume:latest  # 给镜像打标签
docker login  # 输入用户名和密码登录到Docker Hub
docker push wxk749/flume
docker pull wxk749/flume

# 接发布到阿里云私人仓库，私人仓库需要先登录后推送和拉取
docker login --username=wxk74963 registry.cn-beijing.aliyuncs.com
docker tag flume registry.cn-beijing.aliyuncs.com/wangxukun/flume:latest
docker push registry.cn-beijing.aliyuncs.com/wangxukun/flume:latest
docker pull registry.cn-beijing.aliyuncs.com/wangxukun/flume:latest
```
