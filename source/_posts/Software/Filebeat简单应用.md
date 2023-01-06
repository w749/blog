---
title: Filebeat简单应用
author: 汪寻
date: 2021-03-31 19:21:32
updated: 2021-03-31 19:36:57
tags:
 - ETL
categories:
 - Software
---

Filebeat 是一个轻量级的部署应用简单的数据收集工具，一般应用在日志收集场景下。从配置文件的构成来看，分为了三部分，inputs、outputs和其他全局配置，其中 inputs 模块接受的数据来源常见的有 kafka、redis、本地文件和 TCP（监听一个服务器端口传送过来的数据），outputs 模块则可以支持传输到 ES、Logstash、kafka、redis、命令行和本地文件。

<!-- more -->

Filebeat 由两个主要组件构成： prospector 和 harvesters。这两类组件一起协同完成 Filebeat 的工作，从指定文件中把数据读取出来，然后发送事件数据到配置的 output中。Harvesters 负责进行单个文件的内容收集，在运行过程中，每一个 Harvester 会对一个文件逐行进行内容读取，并且把读写到的内容发送到配置的 output 中。Prospector 负责管理 Harvsters，并且找到所有需要进行读取的数据源。如果 input type 配置的是 log 类型，Prospector 将会去配置度路径下查找所有能匹配上的文件，然后为每一个文件创建一个 Harvster。

其中 Harvesters 会根据文件的状态来读取增量数据，所谓的状态就是每次读取之后会记录文件的偏移量，以保证下次直接从最新的数据行开始读取。同时还支持断点续传，在定义的输出被阻塞并且没有确认所有事件的情况下，Filebeat 将继续尝试发送事件，直到输出确认它已经接收到事件。如果 Filebeat 在发送事件的过程中关闭，它在关闭之前不会等待输出确认所有事件。任何发送到输出但在 Filebeat 关闭之前未确认的事件，将在 Filebeat 重新启动时再次发送。

本地日志传输到 ElasticSearch 或者 logstash（也可以去[官方文档](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)或者其他人整理好的[博客](https://cloud.tencent.com/developer/article/1006051)查看）

```bash
filebeat.inputs:
- type: log
  enabled: true
  paths:
   - /usr/share/filebeat/data/*.log

setup.dashboards.enabled: true
setup.kibana:
  host: "kibana:5601"

# ElasticSearch
output.elasticsearch:
  hosts: ["node1:9200", "node2:9201", "node3:9202"]
# Logstash
output.logstash:
  hosts: ["localhost:5044"]
```

传输到 ElasticSearch 的默认索引为 "%{\[fields.log\_type\]}-%{\[agent.version\]}-%{+yyyy.MM.dd}" ，但是需要同时设置 `setup.template.name` 和 `setup.template.pattern` 参数，我还没搞明白咋设置。
