---
title: Flume深入理解
author: 汪寻
date: 2021-04-14 14:24:19
updated: 2021-04-14 14:44:10
tags:
 - ETL
categories:
 - Software
---

### 事务性

Flume 为了保持数据传递的可靠性使用两个独立的事务分别负责从`soucrce`到`channel`（Put事务），以及从`channel`到`sink`（Take事务）的事件传递。在这两个事务中，任何一个下游组件（channel或sink）未能正确的接受数据都会触发事务回滚，标志这次数据传输失败，尝试重新传输或者将数据保存在上游队列等待重新传输。

<!-- more -->

比如：`spooling directory source` 为文件的每一行创建一个事件，一旦事务中所有的事件全部传递到`channel`且提交成功，那么`source`就将该文件标记为完成（在传输完成的文件后加后缀名.COMPLETED）。同理，事务以类似的方式处理从`channel`到`sink`的传递过程，如果因为某种原因使得事件无法记录，那么事务将会回滚。且所有的事件都会保持到`channel`中，等待重新传递。

### Flume Agent  连接

为了跨多个 agent 或 flume 传输数据，前一个agent的`sink`和当前 flume 的`source`需要是`avro`类型，`sink`指向`source`的主机名(或IP地址)和端口，后一个`source`则使用`avro`类型的`source`监听本机端口。

<div align=center><img src="http://flume.apache.org/_images/UserGuide_image03.png"></div>

有了这个基础的 Flume Agent 串联才有了后续的聚合。

### Flume Agent  聚合

Flume Agent 聚合的应用场景在于将多个源的数据聚合在一起传输到一个`sink`中，例如：Agent1 2 3 是部署在三台生成log的机器上，用来收集各自的 log 日志，收集完成后再统一发布到 Agent 4 机器的端口上，使用的就是`avro`类型的`source`和`sink`，这里有两种选择方式，第一种是 Agent 1 2 3 所有的`sink`发送到 Agent 4 机器上的同一个端口，这样 Agent 4 只需要监听一个端口；第二种是 Agent 1 2 3 各自的sink发送到 Agent 4 不同的端口上，Agent 4 配置`sources`同时监听三个端口，再将所有数据传输给 Agent 4 的`channel`，第一种是在 Agent 4 的`source`部分完成数据合并，第二种则是在`channel`部分完成合并。

<div align=center><img src="http://flume.apache.org/_images/UserGuide_image02.png"></div>

### Channel 选择器

数据通过`sources`组件后，会进入`channel`组件，在这个过程中有几个步骤，分别是拦截器、Channel 选择器和 Put 事务，其中 Channel 选择器的作用是将`sources`组件传过来的数据分配到不同的`channel`中，官方有两种类型：`Replicating Channel Selector (default)`和`Multiplexing Channel Selector`。

**Replicating Channel Selector ** 是默认选项，它会将`sources`传过来的数据发送到所有`channel`，第一个单纯复制的 Channel 选择器。

**Multiplexing Channel Selector**  则是多路复用`channel`选择器，它通过从`sources`传输过来的数据所携带的 header 信息判断会将数据发送给哪个`channel`，需要自定义 sources header。

<div align=center><img src="http://flume.apache.org/_images/UserGuide_image01.png"></div>

### Sink 组故障转移和负载均衡

Sink 组主要是解决数据从`channel`到`sink`的故障转移和负载均衡需求，官方有两种类型：`Failover Sink Processor`和`Load balancing Sink Processor`。

**Failover Sink Processor**根据一个按优先级排列的sink列表，确保只要有一个`sink`可用，事件就会被处理(交付)。故障转移机制的工作原理是将失败的`sink`转移到失败池中，在失败池中为它们分配一个冷却期，在这个冷却期到达之前不会尝试发送到这个`sink`。一旦`sink`成功地发送了一个事件，它就会被恢复到活动池。每个`sink`有一个优先级，数值越大，优先级越高。如果一个`sink`在发送事件时失败，下一个具有最高优先级的`sink`将被尝试下一步发送事件。

**Load balancing Sink Processor** 提供了在多个 sink 上负载平衡的能力。它根据一个活动接收的`sink`列表进行分发负载。通过设置`processor.selector`参数可以指定通过轮训或者随机分发的方式传输到每个`sink`。

### Flume 数据可靠性

#### File Channel

Channel 组件的类型有 memory、file 和 kafka ，暂且不论 kafka ，`file channel`对于生产环境来说是一个相对可靠的选择，避免宕机后`memory`中的数据都会丢失，`file channel`在数据未被`sink`消费时可以保存在硬盘上，服务恢复后将`sink`的`channel`绑定为`file channel`就可以取到未被`sink`消费的数据了。

#### 数据持久化

虽然 Flume 在安全性和可靠性的地方已经做得很好了，有 File Channel、Put 和 Take 事务和 Sink 组等等，但为了数据的安全性考虑还是需要考虑持久化操作，其实做起来也很简单，就是将`sources`传输过来的数据分别发送给`memory channel`和`file channel`，然后`memory channel`对接 HDFS 或者 hive sink，`file channel`对接`file sink`，这样`file channel`和`file sink`就是对数据的双重保障，

### Flume 监控

对于 Flume 的运行，我们需要一个能展示 Flume 实时收集数据动态信息的界面或者统计信息，包括 Flume 成功收集的日志数量、成功发送的日志数量、Flume 启动时间、停止时间、以及 Flume 一些具体的配置信息，像通道容量等，于是顺利成章的监控能帮我们做到这些，有了这些数据，在遇到数据收集瓶颈或者数据丢失的时候，通过分析监控数据来分析、解决问题。

### http 监控

一般来说使用自带的 http 监控就可以看到大部分有用的数据。使用这种监控方式，只需要在启动 Flume 的时候在启动参数上面加上监控配置，例如这样：

```
bin/flume-ng agent --conf conf --conf-file conf/flume_conf.properties --name collect -Dflume.monitoring.type=http -Dflume.monitoring.port=1234
```

其中`-Dflume.monitoring.type=http`表示使用 http 方式来监控，后面的`-Dflume.monitoring.port=1234`表示我们需要启动的监控服务的端口号为 1234，这个端口号可以自己随意配置。然后启动 Flume 之后，通过`http://ip:1234/metrics`就可以得到 Flume 的一个 json 格式的监控数据。

#### ganglia 监控

这种监控方式需要先安装 ganglia 然后启动 ganglia ，然后在启动 Flume 的时候加上监控配置，例如：

```
bin/flume-ng agent --conf conf --conf-file conf/producer.properties --name collect -Dflume.monitoring.type=ganglia -Dflume.monitoring.hosts=ip:port
```

其中`-Dflume.monitoring.type=ganglia`表示使用 ganglia 的方式来监控，而`-Dflume.monitoring.hosts=ip:port`表示 ganglia 安装的 ip 和启动的端口号。

### 拦截器

拦截器是简单的插件式组件，设置在 source 和 channel 之间。source 接收到的事件，在写入 channel 之前，拦截器都可以进行转换或者删除这些事件。每个拦截器只处理同一个 source 接收到的事件。可以自定义拦截器。Flume 内置了很多拦截器，并且会定期的添加一些拦截器，在这里列出一些 Flume 内置的，经常使用的拦截器。

**1、Timestamp Interceptor (时间戳拦截器)**

Flume 中一个最经常使用的拦截器 ，该拦截器的作用是将时间戳插入到 Flume 的事件报头中。如果不使用任何拦截器，Flume 接受到的只有 message 。时间戳拦截器`type`参数默认值为`timestamp`，`preserveExisting`默认为`false`，如果设置为`true`，若事件中报头已经存在，不会替换时间戳报头的值。

```
# source连接到时间戳拦截器的配置
a1.sources.r1.interceptors = timestamp
a1.sources.r1.interceptors.timestamp.type=timestamp
a1.sources.r1.interceptors.timestamp.preserveExisting=false
```

**2、Host Interceptor (主机拦截器)**

主机拦截器插入服务器的 ip 地址或者主机名，agent 将这些内容插入到事件的报头中。时间报头中的 key 使用 hostHeader 配置，默认是 host。主机拦截器`type`参数默认值为 host，host.useIP 如果设置为 false，host 则放入主机名，`timestamp.preserveExisting`默认为`false`，如果设置为`true`，若事件中报头已经存在，不会替换时间戳报头的值。

```
# source连接到主机拦截器的配置
a1.sources.r1.interceptors = host
a1.sources.r1.interceptors.host.type=host
a1.sources.r1.interceptors.host.useIP=false
a1.sources.r1.interceptors.timestamp.preserveExisting=true
```

**3、Static Interceptor (静态拦截器)**

静态拦截器的作用是将 k/v 插入到事件的报头中，channel 或者 sink 可以根据指定的 k/v 值操作数据。配置如下：

```
# source连接到****静态拦截器****的配置
a1.sources.r1.interceptors = static
a1.sources.r1.interceptors.static.type=static
a1.sources.r1.interceptors.static.key=logs
a1.sources.r1.interceptors.static.value=logFlume
a1.sources.r1.interceptors.static.preserveExisting=false
```

**4、Regex Filtering Interceptor (正则过滤拦截器)**

在日志采集的时候，可能有一些数据是我们不需要的，这样添加过滤拦截器，可以过滤掉不需要的日志，也可以根据需要收集满足正则条件的日志。配置如下：

```
# source连接到正则过滤拦截器的配置，这样配置的拦截器就只会接收日志消息中带有rm 或者kill的日志：
a1.sources.r1.interceptors = regex
a1.sources.r1.interceptors.regex.type=REGEX_FILTER
a1.sources.r1.interceptors.regex.regex=(rm)|(kill)
a1.sources.r1.interceptors.regex.excludeEvents=false
```

**5、Regex Extractor Interceptor**

通过正则表达式来在 header 中添加指定的 key , value 则为正则匹配的部分。

**6、UUID Interceptor**

用于在每个 events header 中生成一个 UUID 字符串，例如：b5755073-77a9-43c1-8fad-b7a586fc1b97。生成的 UUID 可以在 sink 中读取并使用。

### 配置文件示例

本想着分开来写，但想到针对每个功能都要写好几个配置文件，所以就写了个大杂烩，生产环境中就别这样配了，没什么用。其中包含静态筛选器、多路复用 Channel 选择器、File Channel 以及数据持久化，Flume Agent 聚合以及 Sink 组故障转移需要多个 Agent 来完成，就没在文件中配置，生产中使用 avro source 和 sink 连接多个 Agent 就行了，其他的详见[官方文档](http://flume.apache.org/releases/content/1.9.0/FlumeUserGuide.html#flume-sink-processors)。

```bash
# Name
a1.sources = r1 r2
a1.sinks = k1 k2
a1.channels = c1 c2

# hive source
a1.sources.r1.type = TAILDIR
a1.sources.r1.positionFile = /usr/local/flume/data/multiplexing/position_hive.json
a1.sources.r1.filegroups = f1
a1.sources.r1.filegroups.f1 = /usr/local/flume/data/multiplexing/hive.log
a1.sources.r1.fileHeader = true

# nginx source
a1.sources.r2.type = TAILDIR
a1.sources.r2.positionFile = /usr/local/flume/data/multiplexing/position_nginx.json
a1.sources.r2.filegroups = f2
a1.sources.r2.filegroups.f2 = /usr/local/flume/data/multiplexing/nginx.log
a1.sources.r2.fileHeader = true

# channel selector
a1.sources.r1.selector.type = multiplexing
a1.sources.r1.selector.header = type
a1.sources.r1.selector.mapping.hive = c1
a1.sources.r1.selector.mapping.nginx = c2
# a1.sources.r1.selector.default = c3

a1.sources.r2.selector.type = multiplexing
a1.sources.r2.selector.header = type
a1.sources.r2.selector.mapping.hive = c1
a1.sources.r2.selector.mapping.nginx = c2
# a1.sources.r2.selector.default = c3

# sources interceptors
a1.sources.r1.interceptors = static
a1.sources.r1.interceptors.static.type = static
a1.sources.r1.interceptors.static.key = type
a1.sources.r1.interceptors.static.value = hive
a1.sources.r1.interceptors.static.preserveExisting = false

a1.sources.r2.interceptors = static
a1.sources.r2.interceptors.static.type = static
a1.sources.r2.interceptors.static.key = type
a1.sources.r2.interceptors.static.value = nginx
a1.sources.r2.interceptors.static.preserveExisting = false

# Describe the sink
a1.sinks.k1.type = logger

a1.sinks.k2.type = file_roll
a1.sinks.k2.sink.rollInterval = 30
a1.sinks.k2.sink.directory = /usr/local/flume/data/file_roll

# Use a channel which buffers events in memory and file
a1.channels.c1.type = memory
a1.channels.c1.capacity = 1000
a1.channels.c1.transactionCapacity = 100

a1.channels.c2.type = file
a1.channels.c2.checkpointDir = /usr/local/flume/data/filechannel/checkpoint
a1.channels.c2.dataDirs = /usr/local/flume/data/filechannel/data

# Bind the source and sink to the channel
a1.sources.r1.channels = c1 c2
a1.sources.r2.channels = c1 c2

a1.sinks.k1.channel = c1
a1.sinks.k2.channel = c2
```
