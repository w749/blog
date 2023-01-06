---
title: Spark源码-Shuffle读写流程
author: 汪寻
date: 2022-12-28 12:24:30
update: 2022-12-28 12:58:56
tags:
  - Spark
categories:
  - Software
---

Spark Shuffle 流程以及 Shuffle Writer 和 Shuffle Reader 过程

<!-- more -->
> 源码版本是Spark 3.1.2
​ 
## ShuffleManager
一个用来管理Shuffle系统的可插拔接口，它在driver和executor的SparkEnv中被创建。主要包含了三个方法：registerShuffle(注册并返回ShuffleHandle，用来处理不同的ShuffleManager)、getWriter(用来创建ShuffleWriter，用于map端shuffle数据写出)、getReader(创建ShuffleReader，用于reduce端获取对应的shuffle数据)

### Initialization
ShuffleManager的初始化包含在SparkEnv中
```scala
  // Let the user specify short names for shuffle managers
  val shortShuffleMgrNames = Map(
    "sort" -> classOf[org.apache.spark.shuffle.sort.SortShuffleManager].getName,
    "tungsten-sort" -> classOf[org.apache.spark.shuffle.sort.SortShuffleManager].getName)
  val shuffleMgrName = conf.get(config.SHUFFLE_MANAGER)
  val shuffleMgrClass =
    shortShuffleMgrNames.getOrElse(shuffleMgrName.toLowerCase(Locale.ROOT), shuffleMgrName)
  val shuffleManager = instantiateClass[ShuffleManager](shuffleMgrClass)
```

可以看到初始化哪个ShuffleManager由参数`spark.shuffle.manager`决定，而支持的sort和tungsten-sort初始化的都是SortShuffleManager，至于HashShuffleManager在1.6.0版本以后已经不再使用

### SortShuffleManager
SortShuffleManager的原理可以参考MapReduce的shuffle，它不会为每个Task创建单独的文件，而是将所有结果写入一个文件。该文件中的记录首先是按照PartitionID排序，每个Partition内部再按照key排序，MapTask运行期间会顺序写每个Partition的数据，同时还会生成一个索引文件，记录每个Partition的大小和所在文件的偏移量。

ReduceTask在拉取数据时使用ExternalAppendOnlyMap数据结构，该内存结构在内存不够用时会主动刷写到磁盘，避免出现OOM。

#### registerShuffle
首先需要向ShuffleManager注册，目的就是返回ShuffleHandle，针对不同的计算环境会提供不同的ShuffleHandle
1. BypassMergeSortShuffleHandle
- 下游分区数少于`spark.shuffle.sort.bypassMergeThreshold`(默认200)
- 不需要map端combain

它的特点是直接为每个Partition打开一个临时文件将数据写入其中，最后将所有临时文件数据写入最终数据文件并生成一个索引文件，使用这种方式在分区数较小时效率较高，分区数较大时它会同时打开多个临时文件会对文件系统造成很大的压力
2. SerializedShuffleHandle
- 序列化操作支持重定位操作（Java序列化不支持，Kyro序列化支持）
- 不需要map端combain
- 下游分区数少于16777216

它的特点是将数据序列化后再写入堆外内存，效率会更高
3. BaseShuffleHandle
- 剩下的所有情况

#### getWriter
为每个Partition获取ShuffleWriter，在executor的MapTask上调用，这里根据registerShuffle获取的不同ShuffleHandle返回不同的ShuffleWriter
1. BypassMergeSortShuffleHandle -> BypassMergeSortShuffleWriter
2. SerializedShuffleHandle -> UnsafeShuffleWriter
3. \* -> SortShuffleWriter

#### getReader

## ShuffleWriter

## ShuffleReader


