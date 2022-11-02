---
title: Logstash简单应用
author: 汪寻
date: 2021-04-08
tags:
 - ETL
categories:
 - Software
---

**Elasticsearch**是当前主流的分布式大数据存储和搜索引擎，可以为用户提供强大的全文本检索能力，广泛应用于日志检索，全站搜索等领域。**Logstash**作为Elasicsearch常用的实时数据采集引擎，可以采集来自不同数据源的数据，并对数据进行处理后输出到多种输出源，是Elastic Stack 的重要组成部分。

<!-- more -->

### **Logstash工作原理**

**处理过程**

![](https://main.qcloudimg.com/raw/7367005a46890c48d27e8518a14a1772.png)

如上图，Logstash的数据处理过程主要包括：Inputs, Filters, Outputs 三部分， 另外在Inputs和Outputs中可以使用Codecs对数据格式进行处理。这四个部分均以插件形式存在，用户通过定义pipeline配置文件，设置需要使用的input，filter，output, codec插件，以实现特定的数据采集，数据处理，数据输出等功能

（1）Inputs：用于从数据源获取数据，常见的插件如file, syslog, redis, beats 等\[[详细参考](https://www.elastic.co/guide/en/logstash/current/input-plugins.html)\]  
（2）Filters：用于处理数据如格式转换，数据派生等，常见的插件如grok, mutate, drop, clone, geoip等\[[详细参考](https://www.elastic.co/guide/en/logstash/current/filter-plugins.html)\]  
（3）Outputs：用于数据输出，常见的插件如elastcisearch，file, graphite, statsd等\[[详细参考](https://www.elastic.co/guide/en/logstash/current/output-plugins.html)\]  
（4）Codecs：Codecs不是一个单独的流程，而是在输入和输出等插件中用于数据转换的模块，用于对数据进行编码处理，常见的插件如json，multiline\[[详细参考](https://www.elastic.co/guide/en/logstash/current/codec-plugins.html)\]

#### **执行模型**

（1）每个Input启动一个线程，从对应数据源获取数据  
（2）Input会将数据写入一个队列：默认为内存中的有界队列（意外停止会导致数据丢失）。为了防止数丢失Logstash提供了两个特性：  
[Persistent Queues](https://www.elastic.co/guide/en/logstash/current/persistent-queues.html)：通过磁盘上的queue来防止数据丢失  
[Dead Letter Queues](https://www.elastic.co/guide/en/logstash/current/dead-letter-queues.html)：保存无法处理的event（仅支持Elasticsearch作为输出源）  
（3）Logstash会有多个pipeline worker, 每一个pipeline worker会从队列中取一批数据，然后执行filter和output（worker数目及每次处理的数据量均由配置确定）

#### **简单应用**

首先是Logstash的配置文件，也可以不用配置，不会对数据采集和传输产生很大影响，当需要精细化的参数调整时再配置指定的参数即可。

```bash
xpack.management.enabled: false
xpack.monitoring.elasticsearch.hosts: ["node1:9200","node2:9201"]
xpack.monitoring.enabled: true
```

接下来就是配置数据传输的conf文件，需要制定inputs、filter和outputs三个模块。首先是从文件收集数据，filter解析后传入ElasticSearch。

```bash
input {
  file {
    path => ["/usr/share/logstash/data/file/CouponProduct.csv"]  # 必须使用绝对路径
    # sincedb记录现在有一个与之关联的最后活动时间戳。如果在最近N天内没有在跟踪文件中检测到任何更改，则它的sincedb跟踪记录将过期，并且不会被持久保存。默认14天
    sincedb_clean_after => "2 weeks"
    sincedb_path => "/usr/share/logstash/data/file/sincedb"  # sincedb存储地址
    start_position => "beginning"  # 选择Logstash最初开始读取文件的位置:开始或结束。默认行为将文件视为实时流（end），因此从末尾开始。
  }
}
filter{
  csv {
    separator => ","  # 分隔符，默认是逗号
    # quote_char => "\""  # 定义用于引用CSV字段的字符，默认是双引号
    columns => ["id", "code", "name", "enname", "points", "creater", "updater", "money", "createtime", "updatetime"]  # 指定列名
    autodetect_column_names => false  # 是否检测列名，默认为false
    skip_header => false  # 是否跳过第一行，和autodetect_column_names一起设置，全为true或false
    autogenerate_column_names => false  # 是否设置默认的列名，默认为true
    convert => {  # 指定数据类型
      "money" => "integer"
      "createtime" => "date"
      "updatetime" => "date"
    }
    skip_empty_columns => false  # 跳过空列，默认false
    skip_empty_rows => false  # 跳过空行，默认false
  }
  mutate {
    add_field => {"insert_time" => "%{@timestamp}"}  # 新增字段，%{已有字段}可以引用现有字段
    remove_field => ["message","@version","updater","host","@timestamp"]  # 删除字段
  }
}
output {
  stdout{
  }
  elasticsearch {
    hosts => ["node1:9200","node2:9201"]  # 输出到ES，和logstash.yml保持一致
    index => "coupon_product"  # 索引名称
  }
}
```

以下是传输从filebeat收集的数据，对数据内容使用grok解析，再对filebeat传过来的log.file.path和host.name使用ruby代码进行解析并传入数据。

```bash
input {
  beats {
    port => 5044  # 指定filebeat的端口
    host => logstash  # 指定filebeat的主机
    add_hostname => true  # 将主机名添加到数据中，默认为false
  }
}
filter {
  grok {  # 使用正则表达式解析日志
    match => {"message" => "%{IP:ip} %{WORD:method} %{URIPATHPARAM:request} %{NUMBER:bytes} %{NUMBER:duration}"}
  }
  ruby {  # 运行ruby代码，解析filebeat传过来的log.file.path和host.name
    code => "
      path = event.get('log')['file']['path']
      hostname = event.get('host')['name']
      event.set('path', path)
      event.set('hostname', hostname)
    "
  }
  mutate {
    add_field => {"insert_time" => "%{@timestamp}"}
    remove_field => ["ecs","host","@timestamp","agent","log","@version","input","tags","message"]
  }
}
output {
  stdout{
  }
  elasticsearch {
    hosts => ["node1:9200","node2:9201"]  # 输出到ES，和logstash.yml保持一致
    index => "filebeat_logstash"  # 索引名称
  }
}
```

关于一个Logstash进程的运行则需要使用bin目录下的logstash命令加-f参数制定配置文件进行。当我们修改配置文件之后需要杀死进程重新启动Logstash才可以更新处理流程，--config.reload.automatic参数可以使Logstash自动嗅探配置文件的变化并对此进程的收集和处理进行纠正，默认嗅探时间是15s。

```bash
logstash -f ./config/filebeat.conf --config.reload.automatic
```

### **Logstash和Flume相比**

*   Logstash比较偏重于字段的预处理，在异常情况下可能会出现数据丢失，只是在运维日志场景下，一般认为这个可能不重要；而Flume偏重数据的传输，几乎没有数据的预处理，仅仅是数据的产生，封装成event然后传输；传输的时候flume比logstash多考虑了一些可靠性。因为数据会持久化在channel中，数据只有存储在下一个存储位置（可能是最终的存储位置，如HDFS；也可能是下一个Flume节点的channel），数据才会从当前的channel中删除。这个过程是通过事务来控制的，这样就保证了数据的可靠性。
*   Logstash有几十个插件，配置比较灵活；flume强调用户自定义开发，开发难度相对较高。
*   Logstash的input和filter还有output之间都存在buffer，进行缓冲；Flume直接使用channel做持久化。
*   Logstash性能以及资源消耗比较严重，且不支持缓存。
*   综上所述，Logstash偏重于与ELK Stack结合使用，当然也可以output到kafka再做后续使用，侧重点是数据的预处理；而Flume虽然开发难度较高，基本不存在数据预处理，但在生产环境中比较安全，有分布式和channel的双重保障，侧重点是数据的传输。两者根据不同的使用环境做不同的选择。
