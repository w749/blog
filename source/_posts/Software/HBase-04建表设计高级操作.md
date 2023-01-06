---
title: HBase-04建表设计高级操作
author: 汪寻
date: 2022-02-21 21:12:41
updated: 2022-02-21 21:52:16
tags:
 - HBase
categories:
 - Software
---

HBase 的常用建表属性介绍和表设计，以及数据热点问题等。

<!-- more -->

### 建表属性

在这讲 HBase 的建表属性其实是列簇的属性，HBase 支持对每个列簇设置不同的属性，默认的属性可以使用`create 'table', 'a'`命令并使用`describe 'table'`命令查看，一般常用的就是 `VERSIONS、TTL和COMPRESSION`参数。

```scala
{
  NAME => 'a',  // 列簇名称
  // 布隆过滤器类型，有ROW、ROWCOL和NONE三种选择，分别是按rowkey建索引、按rowkey和qualifier联合建索引以及不使用布隆过滤器
  // 将在每次插入行时将对应的rowkey哈希插入到布隆
  BLOOMFILTER => 'ROW',  
  VERSIONS => '1',  // 数据版本，若为3则最多保留三次版本数据
  IN_MEMORY => 'false',  // 数据是否存储在内存
  KEEP_DELETED_CELLS => 'FALSE', 
  DATA_BLOCK_ENCODING => 'NONE', 
  TTL => 'FOREVER',  // 数据有效期，默认是2147483647s
  COMPRESSION => 'NONE',  // 压缩方式，默认不压缩，数据压缩有GZIP, SNAPPY，LZO
  MIN_VERSIONS => '0',  // 数据过期后至少保存多少个版本数据，默认不保留任何版本数据，只有在设置了TTL的时候生效，compact操作的时候执行
  BLOCKCACHE => 'true',  // 读数据时是否使用块缓存
  BLOCKSIZE => '65536',  // 块缓存大小
  REPLICATION_SCOPE => '0'
}
```

### HBase预分区

默认情况下，创建 HBase 表时只有一个 Region，插入的所有数据都会被存到这个 Region 中，直到数据量达到默认值才会分割成两个 Region，HBase 提供了一种加快批量写入的方法就是预分区，通过预先创建一些空的 Region，这样数据写入 HBase 时，会写入不同的 Region 中，在集群内做数据的负载均衡。

```shell
# create table with specific split points 
hbase>create 'table1','f1',SPLITS => ['\x10\x00', '\x20\x00', '\x30\x00', '\x40\x00'] 
# create table with four regions based on random bytes keys 
hbase>create 'table2','f1', { NUMREGIONS => 8 , SPLITALGO => 'UniformSplit' } 
# create table with five regions based on hex keys 
hbase>create 'table3','f1', { NUMREGIONS => 10, SPLITALGO => 'HexStringSplit' }
```

HBase 提供了几种预分区策略，可以使用 shell 或者 Java API 构建预分区。具体的 Region 区间可以在 HBase WebUI 查看。

### 表设计

#### 列簇设计

追求的原则是：列簇长度尽量小，列簇数量尽量少。

列簇长度最好是一个字符，列簇数量最好在三个以下，因为扫描表的时候需要遍历所有列簇下的 qualifier，列簇越多遍历次数就越多，增加IO负载。

#### RowKey 设计

HBase 的数据是按 RowKey 排序放在一个或多个 Region 当中，查询数据的时候也是根据 RowKey 检索数据并返回，所以 RowKey 设计就显得十分重要，设计的合适与否决定了数据的查询效率。

RowKey 的设计遵循三个原则：长度原则、散列原则和唯一原则。

- 长度原则：一个 Cell 中除了存储了 一个 key-value 之外也存储了 rowKey 值（Client 查询出一条记录遍历 Result 的时候就可以取出来），底层存储数据的时候 RowKey 也会占用额外的空间，所以 RowKey 的设计要尽量短，建议10-100个字节，不过最好不要超过16个字节。

- 散列原则：如果 RowKey 是按时间戳方式递增，建议对高位加散列前缀，由程序循环生成，低位放时间戳，这样可以避免数据都存在一个 RegionServer 中形成热点现象，这样做可以使得数据存储在多个 RegionServer 中，查询时提高查询效率。

- 唯一原则：RowKey 必须保持唯一性，底层是按照 RowKey 顺序存储的，所以设计 RowKey 的时候最好将经常读取的数据放在一起，提升读取效率。

#### 数据热点

HBase 中的行是按 RowKey 字典顺序排序存储的，这种设计优化了 scan 操作，可以将相关的或者经常读取的数据放在一起便于 scan。但如果 RowKey 设计糟糕的话，就会造成数据热点现象，热点发生在大量的 client 直接访问集群中的一个 Region 或极少的 Region，大量访问会导致 热点 Region 所在的单个机器超出自身承受能力，引起性能下降甚至 Region 不可用。所以在设计 RowKey 的时候就要必要热点 Region 的产生。

避免数据热点有几种常见的方法：数据加盐、哈希和反转

- 数据加盐：具体的做法就是在 RowKey 前增加随机数前缀，排序后就避免了数据存储在同一个 Region。

- 哈希：哈希和加盐的不同之处是哈希的前缀是确定的（前提当然是使用同一个哈希算法），使用哈希可以让客户端重构完整的 RowKey，可以使用 get 准确的获取到某一行数据，加随机数的话不便于实现准确的 get。

- 反转：反转并不是直接将 RowKey 反转，而是根据 RowKey 的特征，比如手机号可以将前七位挪到后面，将年月日中的年放到月日后面。

在处理数据热点的时候不能太过散列，也不能太过集中，应该结合实际业务进行设计。例如频繁获取单个 RowKey 的话那么应该让它们尽量分散；范围查询大量数据的时候，数据如果很分散就需要去多个 Region 去查询，如果太过集中，所有的查询请求都会压在一个节点；全表扫描的话就不用考虑这么多了。
