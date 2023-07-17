---
title: Kafka常用命令
author: 汪寻
date: 2023-07-17 10:12:43
updated: 2023-07-17 10:13:43
tags:
 - Kafka
categories:
 - Software
---

### Topic
1. 查看当前的集群topic列表
    `./bin/kafka-topics.sh --list --zookeeper 10.10.3.10:2181`

2. 查看topic的详细信息
    `./bin/kafka-topics.sh --describe --zookeeper 10.10.3.10:2181 --topic test`

3. 创建topic
    `./bin/kafka-topics.sh --create --zookeeper 10.10.3.10:2181 --replication-factor 3 --partitions 1 --topic test`

4. 删除topic
    删除 topic 之前，需要确保配置 delete.topic.enable=true
    `./bin/kafka-topics.sh --delete --zookeeper 10.10.3.10:2181 --topic test`

5. 生产数据
    `./bin/kafka-console-producer.sh --broker-list 10.10.3.10:9092 --topic test`

6. 消费数据
    `./bin/kafka-console-consumer.sh --bootstrap-server 10.10.3.10:9092 --topic test --from-beginning`
    --from-beginning 表示从最初的未过期的 offset 处开始消费数据。不加该参数，表示从最新 offset 处开始消费数据

7. 指定 partition 和 offset 消费
    `./bin/kafka-console-consumer.sh --bootstrap-server 10.10.3.10:9092 --topic test --partition 0 --offset 1663520`

8. 查询指定topic offset最大值
    `./bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list 10.10.3.10:9092 -topic test [--time -1]`

9. 增加分区
    `./bin/kafka-topics.sh --alter --zookeeper 10.10.3.10:2181 --topic test --partitions 3`

### 消费者组
1. 查看所有消费者组
    `./bin/kafka-consumer-groups.sh --bootstrap-server 10.10.3.10:9092 --list`

2. 查看消费者组的消费进度
    `./bin/kafka-consumer-groups.sh --bootstrap-server 10.10.3.10:9092 --group console-consumer-3665  --describe`

### 单独配置
1. 为topic单独设置参数（topic只保留一天的数据）
    `./bin/kafka-configs.sh --zookeeper 10.10.3.10:2181  --entity-type topics --entity-name test --alter --add-config retention.ms=86400000,cleanup.policy=delete`

2. 查看这个topic单独设置的参数
    `./bin/kafka-configs.sh --zookeeper 10.10.3.10:2181  --entity-type topics --entity-name test --describe`

3. 查看kafka日志文件
    `./bin/kafka-run-class.sh kafka.tools.DumpLogSegments --files /data/kafka_data/logs/test-0/00000000000001049942.log --print-data-log --deep-iteration > secLog.log`

### 重点配置
| config                         | describe                                                                       | default        |
| ------------------------------ | ------------------------------------------------------------------------------ | -------------- |
| beoker.id                      | broker id，每个broker都需要唯一                                                | 0              |
| listeners                      | broker地址 PLAINTEXT://10.10.3.10:9092                                         | localhost:9092 |
| delete.topic.enable            | 删除topic是否删除数据                                                          | false          |
| unclean.leader.election.enable | leader挂掉后副本是否参与选举，若为true可能会丢数，不为true可能会导致分区不可用 | false          |
| num.network.threads            | broker处理消息的最大线程数，推荐为cpu核数加1                                   | 3              |
| num.io.threads                 | broker处理磁盘IO的线程数，推荐为cpu核数的两倍                                  | 8              |

### 优化参数
1. JVM堆内存
    `vim bin/kafka-server-start.sh ` -> 调整`KAFKA_HEAP_OPTS="-Xmx16G -Xms16G"`的值。推荐HEAP SIZE的大小不超过主机内存的50%。

2. socket server可接受数据大小(防止OOM异常)
    `socket.request.max.bytes=2147483600`，参数值为int，所以不能超过int最大值

3. 网络和ios操作线程配置优化
    ```
    # broker处理消息的最大线程数
    num.network.threads=9
    # broker处理磁盘IO的线程数
    num.io.threads=16
    ```
    num.network.threads主要处理网络io，读写缓冲区数据，基本没有io等待，配置线程数量为cpu核数加1
    num.io.threads主要进行磁盘io操作，高峰期可能有些io等待，因此配置需要大些。配置线程数量为cpu核数2倍，最大不超过3倍

4. 日志保留策略
    ```bash
    # 日志保留时长
    log.retention.hours=72
    # 段文件配置
    log.segment.bytes=1073741824
    ```

5. replica复制配置
    ```bash
    num.replica.fetchers=3
    replica.fetch.min.bytes=1
    replica.fetch.max.bytes=5242880
    ```
    每个follow从leader拉取消息进行同步数据，follow同步性能由这几个参数决定，分别为:
    拉取线程数(num.replica.fetchers):fetcher配置多可以提高follower的I/O并发度，单位时间内leader持有更多请求，相应负载会增大，需要根据机器硬件资源做权衡，建议适当调大；
    最小字节数(replica.fetch.min.bytes):一般无需更改，默认值即可；
    最大字节数(replica.fetch.max.bytes)：默认为1MB，这个值太小，推荐5M，根据业务情况调整
    最大等待时间(replica.fetch.wait.max.ms):follow拉取频率，频率过高，leader会积压大量无效请求情况，无法进行数据同步，导致cpu飙升。配置时谨慎使用，建议默认值，无需配置

6. 分区数量配置
    ```bash
    num.partitions=5
    ```
    默认partition数量1，如果topic在创建时没有指定partition数量，默认使用此值。Partition的数量选取也会直接影响到Kafka集群的吞吐性能，配置过小会影响消费性能