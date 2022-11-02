---
title: HBase-03架构设计和读写过程
author: 汪寻
date: 2022-02-17
tags:
 - HBase
categories:
 - Software
---

对 HBase 的物理架构和读写过程做了详细的介绍。

<!-- more -->

### Hbase 物理架构

<div align=center><img src="HBase物理架构.png"></div>

#### StoreFile & HFile

StoreFile 以 HFile 格式保存在 HDFS 上  看下图 HFile 的数据组织格式：

<div align=center><img src="HFile.png"></div>

首先 HFile 文件是不定长的 长度固定的只有其中的两块 Trailer 和 FileInfo。正如图中所示：Trailer中有指 指向其他数据块的起始点；FileInfo中记录了文件的一些Meta信息，例如 AVG_KEY_LEN, AVG_VALUE_LEN, LAST_KEY, COMPARATOR, MAX_SEQ_ID_KEY等。

HFile分为六个部分： 

1. Data Block 段：保存表中的数据，这部分可以被压缩；
2. Meta Block 段(可选的)：保存用户自定义的key-value对，可以被压缩；
3. File Info 段：HFile的元信息，不压缩，用户也可以在这一部分添加自己的元信息；
4. Data Block Index 段：Data Block的索引，每条索引的key是被索引的block的第一条记录的key；
5. Meta Block Index 段(可选的)：Meta Block的索引；
6. Trailer段：这一段是定长的。保存了每一段的偏移量，读取一个HFile时，会先读取Trailer，Trailer保存了每个段的起始位置(段的Magic Number用来做安全check)，
   然后 DataBlock Index会被读取到内存中，这样当检索某个key时不需要扫描整个HFile，只需从内存中找到key所在的block，通过一次磁盘IO将整个block读取到内存中，再找到需要的key。DataBlock Index采用LRU机制淘汰机制。

HFile 的 Data Block，Meta Block 通常使用压缩方式存储，压缩之后可以大大减少网络IO和磁盘IO，随之而来的开销当然是花费cpu进行压缩和解压缩。目标HFile的压缩支持两种方式 Gzip 和 LZO。

Data Index 和 Meta Index 块记录了每个 Data 块和 Meta 块的起始点。

Data Block 是 HBase I/O 的基本单元，为了提高效率，HRegionServer 中有基于 LRU 的 Block Cache 机制。每个 Data 块的大小可以在创建一个 Table 的时候通过参数指定，大号的 Block 有利于顺序 Scan，小号 Block 利于随机查询。 每个 Data 块除了开头的 Magic 以外就是一个个 KeyValue 对拼接而成，Magic 内容就是一些随机数字，目的是防止数据损坏。

HFile 里面的每个 KeyValue 对就是一个简单的 byte 数组。但是每个 byte 数组里面包含了很多项，并且有固定的结构。我们来看看里面的具体结构：

<div align=center><img src="KeyValue.png"></div>

开始是两个固定长度的数值，分别表示 Key 的长度和 Value 的长度。紧接着是 Key，开始是固定长度的数值，表示RowKey的长度，紧接着是 RowKey，然后是固定长度的数值，表示 Family 的长度 然后是 Family，接着是 Qualifier，然后是两个固定长度的数值，表示TimeStamp和KeyType（Put/Delete）。Value 部分没有那么复杂的结构，就是纯粹的二进制数据了。

#### WAL & HLog

它用来做灾难恢复使用，类似于 MySQL 中的 binlog，HLog 记录所有的数据变更操作。HBase 采用类 LSM 的架构操作，数据没有直接写入 HBase，而是先写到 MemStore，等满足一定条件的时候再异步刷写到磁盘，为防止刷写期间进程发生异常导致数据丢失，所以会把数据按顺序写入 HLog 中，如果 RegionServer 发生宕机或其他异常，会从 HLog 恢复数据，保证数据不丢失。

WAL（Write-Ahead Logging）是一种高效的日志算法，几乎是所有非内存数据库提升写性能的不二法门，基本原理是在数据写入之前首先顺序写入日志，然后再写入缓存，等到缓存写满之后统一落盘。之所以能够提升写性能，是因为 WAL 将一次随机写转化为了一次顺序写加一次内存写。提升写性能的同时，WAL 可以保证数据的可靠性，即在任何情况下数据不丢失。假如一次写入完成之后发生了宕机，即使所有缓存中的数据丢失，也可以通过恢复日志还原出丢失的数据。

每个 RegionServer 维护一个 HLog，而不是每一个 Region 一个，这样做不同 Region 的日志会混在一起，同时写入多个文件时可以减少磁盘寻址次数。HLog 就是一个普通的 Hadoop Sequence File，它的 key 是 HLogkey 对象，记录了写入数据的归属信息，除了 table 和 region 名字以外，还包括 sequence number 和 timestamp；HLog 的value 是 HBase 的 KeyValue 对象，即对应 HFile 的 keyvalue。

#### MemStore & StoreFile

一个 HRegion 由多个 Store 组成，每个 Store 包含一个列簇的所有数据。Store 包括位于内存的 MemStore 和位于磁盘的 StoreFile（也就是 HFile），写操作时会先写入 MemStore，当数据量达到一定阈值的时候，HRegionServer 会启动 flushcache 进程写刷写到 StoreFile，每次写入形成一个单独的 HFile 文件。当客户端检索数据时，会优先在 MemStore 查找，找不到才会去 StoreFile 检索。

#### Flush

数据在更新时首先写入 HLog（WAL Log），再写入 MemStore 中，MemStore（存储结构 CocurrentSkipListMap，优点就是 增删改查 key-value 效率都很高）中的数据是排序的，当 MemStore 累计到一定阈值（默认是128M，局部控制）时，就会创建一个新的 MemStore，并且将老的 MemStore 添加到 flush 队列，由单独的线程 flush 到磁盘上，成为一个 StoreFile。与此同时，系统会在 ZooKeeper 中记录一个 redo point，表示这个时刻之前的变更已经持久化了。当系统出现意外时，可能导致内存 MemStore 中的数据丢失，此时使用 HLog（WAL Log）来恢复 checkpoint 之后的数据。Memstore 执行刷盘操作的的触发条件：

1. 全局内存控制：当所有 memstore 占整个 heap 的最大比例的时候，会触发刷盘的操作。这个参数是 hbase.regionserver.global.memstore.upperLimit，默认为整个heap 内存的40%。这个全局的参数是控制内存整体的使用情况，但这并不意味着全局内存触发的刷盘操作会将所有的 MemStore 都进行刷盘，而是通过另外一个参数 hbase.regionserver.global.memstore.lowerLimit 来控制，默认是整个 heap 内存的35%。当 flush 到所有 memstore 占整个 heap 内存的比率为35%的时候，就停止刷盘。这么做主要是为了减少刷盘对业务带来的影响，实现平滑系统负载的目的。

2. 局部内存控制：当 MemStore 的大小达到 hbase.hregion.memstore.flush.size 大小的时候会触发刷盘，默认128M大小。

3. HLog 的数量：前面说到 HLog 为了保证 HBase 数据的一致性，那么如果 HLog 太多的话，会导致故障恢复的时间太长，因此 HBase 会对 HLog 的最大个数做限制。当达到 HLog 的最大个数的时候，会强制刷盘。这个参数是 hase.regionserver.max.logs，默认是32个。

4. 手动操作：可以通过 HBase Shell 或者 Java API 手动触发 flush 的操作。

#### Split & Compact

HBase 的三种默认的 Split 策略：`ConstantSizeRegionSplitPolicy（常数数量）、IncreasingToUpperBoundRegionSplitPolicy（递增上限）、SteppingSplitPolicy（步增上线）`。StoreFile 是只读的，一旦创建后就不可以再修改。因此 HBase 的更新/修改其实是不断追加的操作。当一个 Store 中的 StoreFile 达到一定的阈值后，就会进行一次合并（minor_compact、major_compact），将对同一个 key 的修改合并到一起，形成一个大的 StoreFile，当 StoreFile 的大小达到一定阈值后，又会对 StoreFile 进行 split，等分为两个 StoreFile。由于对表的更新是不断追加的，compact 时，需要访问 Store 中全部的 StoreFile 和 MemStore，将他们按 rowkey 进行合并，由于都是经过排序的并且还有索引，合并的过程会比较快。

Minor_Compact 和 Major_Compact 的区别：Minor 操作只用来做部分文件的合并操作以及包括 minVersion=0 并且设置 ttl 的过期版本清理，不做任何删除数据、多版本数据的清理工作；Major 操作是对 Region下的 HStore下的所有 StoreFile 执行合并操作，最终的结果是整理合并出一个文件。

Client 写入 -> 存入 MemStore，一直到 MemStore 达到阈值 -> Flush 成一个 StoreFile，直至增长到一定阈值 -> 触发 Compact 合并操作 -> 多个 StoreFile 合并成一个 StoreFile，同时进行版本合并和数据删除 -> 当 StoreFiles Compact 后，逐步形成越来越大的 StoreFile -> 单个 StoreFile 大小超过一定阈值（默认10G）后，触发 Split 操作，把当前 Region Split 成2个 Region，Region 会下线，新 Split 出的两个子 Region 会被 HMaster 分配到相应的 HRegionServer 上，使得原先一个 Region 的压力得以分流到两个 Region 上。由此过程可知，HBase 只是增加数据，所有的更新和删除操作，都是在 Compact 阶段做的，所以，用户写操作只需要进入到内存即可立即返回，从而保证I/O高性能。

### RegionServer 工作机制

#### Region 分配

任何时刻，一个 Region 只能分配给一个 RegionServer。Master 记录了当前有哪些可用的 RegionServer。以及当前哪些 Region 分配给了哪些 RegionServer，哪些 Region 还没有分配。当需要分配的新的 Region，并且有一个 RegionServer 上有可用空间时，Master 就给这个 RegionServer 发送一个装载请求，把 Region 分配给这个 RegionServer。RegionServer 得到请求后，就开始对此 Region 提供服务，包括：该 Regoin 的 compact 和 split 以及该 Region 的IO读写。

#### RegionServer 上线

Master 使用 Zookeeper 来跟踪 RegionServer 状态。当某个 RegionServer 启动时，会首先在 ZooKeeper 上的 server 目录下建立代表自己的 znode。由于 Master 订阅了 server 目录上的变更消息，当 server 目录下的文件出现新增或删除操作时，Master 可以得到来自 ZooKeeper 的实时通知。因此一旦 RegionServer 上线，Master 能马上得到消息。

#### RegionServer 下线

当 RegionServer 下线时，它和 Zookeeper 的会话断开，ZooKeeper 会自动释放代表这台 server 的文件上的独占锁。Master 就可以确定 RegionServer 挂了。无论哪种情况，RegionServer 都无法继续为它的 Region 提供服务了，此时 Master 会删除 server 目录下代表这台 RegionServer 的 znode 数据，并将这台 RegionServer 的 Region 分配给其它还活着的同志。

### Master 工作机制

#### Master上线

Master启动进行以下步骤：

1. 从 ZooKeeper 上获取唯一一个代表 Active Master 的锁，用来阻止其它 Master 成为 Master。使用 zookeeper 实现了分布式独占锁；
2. 扫描 ZooKeeper 上的 server 父节点，获得当前可用的 RegionServer 列表。 rs 节点下的 regionserver 列表；
3. 和每个 RegionServer 通信，获得当前已分配的 Region 和 RegionServer 的对应关系。 每个表有多少个 regoin, 哪些 regionserver 保管了那些 region...
4. 扫描 META 表中 Region 的集合，计算得到当前还未分配的 Region，将他们放入待分配 Region 列表。 有一些 regoin 是无人认领的。

#### Master 下线

由于 Master 只维护表和 Region 的元数据，而不参与表数据IO的过程，Master 下线仅导致所有元数据的修改被冻结(无法创建删除表，无法修改表的 schema，无法进行 Region 的负载均衡，无法处理 Region 上下线，无法进行 Region 的合并，唯一例外的是 Region 的 split 可以正常进行，因为只有 RegionServer 参与)，表的数据读写还可以正常进行。因此 Master 下线短时间内对整个 HBase 集群没有影响。

从上线过程可以看到，Master 保存的信息全是可以冗余信息（都可以从系统其它地方收集到或者计算出来）。因此，一般 HBase 集群中总是有一个 Master 在提提供服务，还有一个以上的 Master 在等待时机抢占它的位置。

### 读写过程

<div align=center><img src="Get过程.png"></div>

1. 客户端通过 ZooKeeper 查询到 META 表的 RegionServer 和 Region 所在主机位置，随后去 META 表查询目标 key 所在的 RegionServer 和 Region

2. 联系 RegionServer 查询目标数据

3. RegionServer 定位到目标数据所在的 Region，发出查询数据请求

4. Region 先在 Memstore 中查找，查到则返回，查不到会去 BlockCache 查找

5. 如果还找不到，则在 StoreFile 中扫描，因为 HFile 的特殊设计，所以扫描起来不会很慢。为了判断要查的数据在不在当前的 StoreFile 中，应用到了 BloomFilter。BloomFilter（布隆过滤器）可以判断一个元素是不是在一个庞大的集合内，但是他有一个弱点，它有一定的误判率

<div align=center><img src="Put过程.png"></div>

1. Client 先根据 RowKey 找到对应的 Region 所在的 RegionServer

2. Client 向 RegionServer 提交写请求

3. RegionServer 找到目标 Region

4. Region 检查数据是否与 Schema一致

5. 如果客户端没有指定版本，则获取当前系统时间作为数据版本

6. 将更新写入 WAL Log

7. 将更新写入 Memstore

8. 判断Memstore的是否需要 flush 为 StoreFile 文件

写入数据的过程补充：

每个 HRegionServer 中都会有一个HLog对象，HLog 是一个实现 Write Ahead Log 的类，每次用户操作写入 Memstore 的同时，也会写一份数据到 HLog 文件，HLog 文件定期会滚动更新，并删除旧的文件(已持久化到 StoreFile 中的数据)。当 HRegionServer 意外终止后，HMaster 会通过 ZooKeeper 感知，HMaster 首先处理遗留的 HLog 文件，将不同 Region 的 log 数据拆分，分别放到相应 Region 目录下，然后再将失效的 Region（带有刚刚拆分的log）重新分配，领取到这些Region的 HRegionServer 在 load Region 的过程中，会发现有历史 HLog 需要处理，因此会 Replay HLog 中的数据到 MemStore 中，然后 flush 到 StoreFiles，完成数据恢复。
