---
title: HBase-01基础概念
author: 汪寻
date: 2022-02-10 20:17:20
update: 2022-02-10 20:37:28
tags:
 - HBase
categories:
 - Software
---

针对 HBase 的集群架构和表逻辑结构做了简单的介绍。

<!-- more -->

### HBase 介绍

1. Apache HBase™ is the Hadoop database, a distributed, scalable, big data store.

2. Use Apache HBase™ when you need random, realtime read/write access to your Big Data.

3. This project's goal is the hosting of very large tables -- billions of rows X millions of columns -- atop clusters of commodity hardware.

4. Apache HBase is an open-source, distributed, versioned, non-relational database modeled after Google's Bigtable: A Distributed Storage System for Structured Data by Chang et al. Just as Bigtable leverages the distributed data storage provided by the Google File System, Apache HBase provides Bigtable-like capabilities on top of Hadoop and HDFS.

HBase 是 BigTable 的开源（源码使用Java编写）版本。是 Apache Hadoop 的数据库，是建立在HDFS 之上，被设计用来提供高可靠性、高性能、列存储、可伸缩、多版本的 NoSQL 的分布式数据存储系统，实现对大型数据的实时、随机的读写访问。详情查看 [HBase 官网](https://hbase.apache.org/)

### 集群架构

<div align=center><img src="HBase集群架构.png"></div>

1. HBase 采用主从架构，HMaster 作为集群的管理节点，主要负责监视集群中的所有 RegionServer 实例，并且建表、修改表、删除表等原数据操作也是 HMaster 在负责，同时它支持部署多个 backup 机器防止 HMaster 意外挂掉接管它的工作。

2. RegionServer 管理所有的表数据操作和存储，对于数据的增删更新查都由它负责，在集群中有多个 RegionServer 节点。每个 RegionServer 中有多个 Store 负责数据的缓存和存储，最终数据以 HFile 的格式保存到 HDFS 的 DataNode 中。在数据写入 MemStore 之前会事先写入 WAL（HLog），以防数据在 MemStore 还未刷写到 HFile之前丢失。

3. Client 访问数据前首先需要访问 Zookeeper，找到 meta（记录了每个 HBase 表数据所在的 RegionServer 和 Region 等元数据信息）表的位置后访问 meta 表，把表数据缓存从本地，从表中找到目标 Region 再去与 Region 通信。

4. Zookeeper 负责维护集群的状态，HMaster 的选举以及 RegionServer 是否在线，存储 meta 表的位置等等。

### 核心物理概念

#### NameSpace（表命名空间）

类似于 MySQL 中的数据库，表现在文件系统中一个表命名空间就是一个文件夹，和 MySQL不同的是它不是强制要求的，类似于 Hive，不指定的时候所有的表都存储在 default 目录下，一般用来隔离业务数据。

#### Table

逻辑上可类比为 Hive 中的表，HBase 表结构逻辑视图：

<div align=center><img src="HBase表结构逻辑视图.png"></div>

每条数据有唯一的 rowkey，它的字段可以存储在不同的 columnFamily 中，使用 columnFamily:qualifer 指定字段即可取出最新的 value（timestamp 最大）。定位一条数据的流程：`table -> rowkey -> columnFamily -> qualifier(column) -> timestamp -> value`。

在一个 HBase 表中，存在多个列簇，每个列簇包含多个字段，每个字段对应的数据有多个版本，最小粒度的一条数据也就是一个 Cell。表内部 RowKey 是按顺序排列的，如果数据量太大，会按 RowKey 将数据切分为多个 Region，不同的 Region 是可以存储在不同的 RegionServer 中的，一个 Region 中的数据一定是在同一个 RegionServer 中。最后 Store 也是逻辑上的概念，客户端读写数据最终都由 Store 与底层磁盘存储的 HFile 文件联系，Store 中还有 MemStore 和 BlockCache 等内存数据的概念，MemStore 用来刷写 HFile 文件，BlockCache 则是读缓存，这部分后续再详细介绍。

#### RowKey（行键）

RowKey 是检索一条记录的主键，访问 HBase Table 的行，每个 RowKey 在表中都是唯一的。

检索数据只有三种方式：

- 通过单个 rowKey 返回一条记录

- 通过 rowKey 的 range 范围返回对应的多条数据

- scan 扫描全表的数据

RowKey 可以是任意字符（最大长度为64KB），在 HBase 内部，rowKey 保存为字节数组，存储时会按照 rowKey 的字典序排序后存储。

#### Region（区域）

Table 按行分为多个 Region。Region是按数据量分割的，刚开始只有一个 Region，随着数据量的增加会自动分割为新的 Region，Region是 HBase 分布式存储和负载均衡的最小单元，分布在不同的 RegionServer中。

#### Store

每个 Region 中有一个或多个 Store，每个 Store 保存着一个 Column Family 中的数据。往 HBase 中写数据时，Store内部由 Memstore 刷写到 StoreFile（HFile）中，为保证数据的安全性，数据会先写入 WAL，再写入 MemStore。读数据时，如果是首次读操作，会先扫描 StoreFile，并把数据缓存到 BlockCache 中，下次读就直接从内存中把数据读出来，默认采用 LRUBlockCache 策略。

#### Column Family（列簇）

HBase 表中的每个列都归属于某个列簇，列簇作为表的 Schema（列不是），建表的时候至少要指定一个列簇，列簇支持增加和修改，删除会连带它所包含的列以及数据全部删除。

查询数据时需要指定列簇 columnFamily:column。列簇也不是越多越好，假如要返回一个数据的所有字段，那么就需要遍历每个列簇取出它下面的所有字段，列簇越多 IO 次数就越多，搜寻文件就越多，效率就越低，官方推荐小于等于3，最好就一个。列簇在在文件系统中就是一个文件夹。

#### Timestamp（时间戳）

HBase 通过 rowKey 和 column 确定一个存储单元 Cell，每个存储单元存储着同一份数据的不同版本，版本通过时间戳来索引。

支持版本索引以及最大版本数在建表时指定：`create 'Student', {NAME => 'Stulnfo', VERSIONS => 3}, {NAME =>'Grades', BLOCKCACHE => true}`，不同列簇的最大版本数可以不相同。

插入数据的时候可以显式指定时间戳，不指定的话系统会默认帮我们指定为当前时间戳。查询数据默认返回最近的时间戳（版本）对应的数据，若要返回不同版本的数据需指定时间戳。

#### Cell（单元格）

一个字段可以存储多个版本的数据，而每一个版本就称为一个 Cell，所以 HBase 中的最小数据粒度是一条数据的某个版本，也就是一个 Cell，而不是这一条数据。Cell 中的数据是没有类型的，底层全部使用字节码存储。

# 
