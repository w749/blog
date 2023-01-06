---
title: Flume简单应用
author: 汪寻
date: 2021-04-13 21:21:44
updated: 2021-04-13 21:35:36
tags:
 - ETL
categories:
 - Software
---

Apache Flume 是一个分布式的、可靠的、可用的系统，可以有效地收集、聚合和将大量的日志数据从许多不同的源移动到一个集中的数据存储中。它的 SOURCE、SINK、CHANNEL 三大组件这种模式，来完成数据的接收、缓存、发送这个过程，拥有非常完美的契合度。 Flume agent 是一个(JVM)进程，它承载着从 source 到下一个 sink 的事件流。

<!-- more -->

### **Flume架构**

<div align=center><img src="http://flume.apache.org/_images/UserGuide_image00.png"></div>

Flume source 使用由外部源(如 web 服务器)交付给它的事件。外部源以目标 Flume source 能够识别的格式向 Flume 发送事件。例如，Avro Flume source 可用于从 Avro 客户端或流中的其他 Flume agent 接收来自 Avro 的事件。channel 是一个被动存储事件，直到它被 Flume sink 使用。file channel 就是一个例子——它由本地文件系统支持。sink 将事件从 channel 中移除，并将其放入外部存储库，如HDFS(通过Flume HDFS sink)，或将其转发到流中的下一个 Flume agent 的 Flume source。

事件在每个 agent的 channel 中暂存。然后事件被交付到 sink 中的下一个 agent 或终端存储库(如 HDFS )。事件仅在存储在下一个 agent 的 channel 或终端存储库中之后才会从当前 channel 中删除，当然 file channel 例外 它会将数据持久化在磁盘，而过不被 sink 消费就一直存在。这就是 Flume 中如何提供流的端到端的可靠性。

### **Flume 配置文件**

Flume 的启动配置文件一般只需要修改 Flume 根目录下 conf 目录中的 flume-env.sh 文件，修改内容如下

```bash
# 指定JAVA_HOME
export JAVA_HOME=/usr/local/jdk1.8.0_181/
# 可以将启动Flume时固定配置的参数放在JAVA_OPTS中（指定从终端打印数据并且指定监控数据访问端口http://本地ip:1234/metrics），可以不设置
JAVA_OPTS="-Dflume.root.logger=INFO,console -Dflume.monitoring.type=http -Dflume.monitoring.port=1234"
```

Flume 的启动命令一般包括特定的几个参数

```bash
/usr/local/flume/bin/flume-ng agent \  # Flume启动命令
    --conf /usr/local/flume/conf \  # 指定配置文件目录
    --conf-file /usr/local/flume/config/spooldir.conf \  # 指定agent配置文件
    --name a1 \  # 指定agent名称
    -Dflume.root.logger=INFO,console \  # 在控制台打印数据
    -Dflume.monitoring.type=http \  # 使用http监控Flume传输数据
    -Dflume.monitoring.port=1234  # 访问监控数据的本地端口（http://本地ip:1234/metrics）
```

Flume 每个 agent 的配置包括 SOURCE、SINK、CHANNEL 三大组件的配置，每个 agent 配置文件单独放在单独的 conf 文件中，启动 Flume 的时候指定既可，以下是一个官方示例，监听本地端口 4444 并将数据暂存在 memory channel 中由终端消费：

```bash
_# example.conf: A single-node Flume configuration_ 

_# Name the components on this agent_ 
a1.sources **=** r1 
a1.sinks **=** k1 
a1.channels **=** c1 

_# Describe/configure the source_ 
a1.sources.r1.type **=** netcat 
a1.sources.r1.bind **=** localhost 
a1.sources.r1.port **=** 44444 

_# Describe the sink_ 
a1.sinks.k1.type **=** logger 

_# Use a channel which buffers events in memory_ 
a1.channels.c1.type **=** memory 
a1.channels.c1.capacity **=** 1000 
a1.channels.c1.transactionCapacity **=** 100 

_# Bind the source and sink to the channel_ 
a1.sources.r1.channels **=** c1 
a1.sinks.k1.channel **=** c1
```

常见的 source 有 exec（执行一段代码）、spooldir（监控一个目录的新文件）、taildir（监控一个或多个文件）以及 netcat（监听一个服务器端口），其他的查询[官方文档](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html#flume-sources)

```bash
# exec
a1.sources = r1
a1.sources.r1.type = exec
a1.sources.r1.command = tail -f /usr/local/flume/data/exec.log

# spooldir
a1.sources = r1
a1.sources.r1.type = spooldir
a1.sources.r1.spoolDir = /usr/local/flume/data/spooldir
a1.sources.r1.fileHeader = true
a1.sources.r1.fileSuffix = .COMPLETED

# taildir
a1.sources = r1
a1.sources.r1.type = TAILDIR
a1.sources.r1.positionFile = /usr/local/flume/data/taildir/taildir_position.json
a1.sources.r1.filegroups = f1 f2
a1.sources.r1.filegroups.f1 = /usr/local/flume/data/taildir/file1
a1.sources.r1.filegroups.f2 = /usr/local/flume/data/taildir/.*txt
a1.sources.r1.fileHeader = true

# netcat
a1.sources.r1.type **=** netcat 
a1.sources.r1.bind **=** localhost 
a1.sources.r1.port **=** 44444 
```

常见的 channel 有 memory 、file 以及 kafaka ，其他的查看[官方文档](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html#flume-channels)

```bash
# memory
a1.channels **=** c1 
a1.channels.c1.type **=** memory 
a1.channels.c1.capacity **=** 10000 
a1.channels.c1.transactionCapacity **=** 10000 a1.channels.c1.byteCapacityBufferPercentage **=** 20 
a1.channels.c1.byteCapacity **=** 800000

# kafka
a1.channels **=** c1 
a1.channels.c1.type **=** org.apache.flume.channel.kafka.KafkaChannel 
a1.channels.c1.kafka.bootstrap.servers **=** kafka-1:9092,kafka-2:9092,kafka-3:9092 
a1.channels.c1.kafka.topic **=** c1 
a1.channels.c1.kafka.consumer.group.id **=** flume-consumer

# file
a1.channels **=** c1 
a1.channels.c1.type = file
a1.channels.c1.checkpointDir = /usr/local/flume/data/filechannel/checkpoint
a1.channels.c1.dataDirs = /usr/local/flume/data/filechannel/data
```

常见的 sink 有 logger（终端）、file\_roll（滚动文件）、avro（端口）、hdfs、hive、kafka、ES、HBASE 等等，其他的查看[官方文档](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html#flume-sinks)

```bash
# logger
a1.sinks = k1
a1.sinks.k1.type = logger

# file_roll
a1.sinks = k1
a1.sinks.k1.type = file_roll
a1.sinks.k1.sink.rollInterval = 30
a1.sinks.k1.sink.directory = /usr/local/flume/data/file_roll

# avro
a1.sinks **=** k1 
a1.sinks.k1.type **=** avro 
a1.sinks.k1.channel **=** c1 
a1.sinks.k1.hostname **=** 10.10.10.10 
a1.sinks.k1.port **=** 4545

# hive以及hdfs参数有点多，详情查看官方文档
```

最后放一个做了数据持久化的发送到hdfs的示例

```bash
# Name the components on this agent
a1.sources = r1
a1.sinks = k1 k2
a1.channels = c1 c2

# Describe/configure the source
a1.sources.r1.type = TAILDIR
a1.sources.r1.positionFile = /usr/local/flume/data/taildir/taildir_position.json
a1.sources.r1.filegroups = f1 f2 f3
a1.sources.r1.filegroups.f1 = /usr/local/flume/data/taildir/file1
a1.sources.r1.filegroups.f2 = /usr/local/flume/data/taildir/.*txt
a1.sources.r1.filegroups.f3 = /usr/local/flume/data/taildir/.*log
a1.sources.r1.fileHeader = true

# Describe the sink
a1.sinks.k1.type = logger
a1.sinks.k2.type **=** hdfs 
a1.sinks.k2.channel **=** c1 
a1.sinks.k2.hdfs.path **=** hdfs://hadoop102:9000/flume/events/%y-%m-%d/%H%M/%S 
a1.sinks.k2.hdfs.filePrefix **=** events- 
a1.sinks.k2.hdfs.round **=** true 
a1.sinks.k2.hdfs.roundValue **=** 10 
a1.sinks.k2.hdfs.roundUnit **=** minute
a1.sinks.k2.hdfs.useLocalTimeStamp = true

# Use a channel which buffers events in memory and file
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100
a1.channels.c2.type = file
a1.channels.c2.checkpointDir = /usr/local/flume/data/filechannel/checkpoint
a1.channels.c2.dataDirs = /usr/local/flume/data/filechannel/data

# Bind the source and sink to the channel
a1.sources.r1.channels = c1 c2
a1.sinks.k1.channel = c1
a1.sinks.k2.channel = c2
```
