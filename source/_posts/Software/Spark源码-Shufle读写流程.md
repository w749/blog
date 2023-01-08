---
title: Spark源码-Shuffle读写流程
author: 汪寻
date: 2022-12-28 20:14:47
updated: 2022-12-28 20:41:28
tags:
  - Spark
categories:
  - Software
---

Spark Shuffle流程以及Shuffle Writer和Shuffle Reader过程

<!-- more -->
> 源码版本是Spark 3.1.2
​ 
## ShuffleManager
一个用来管理Shuffle系统的可插拔接口，它在driver和executor的SparkEnv中被创建。主要包含了三个方法：registerShuffle(注册并返回ShuffleHandle，用来处理不同的ShuffleManager)、getWriter(用来创建ShuffleWriter，用于map端shuffle数据写出)、getReader(创建ShuffleReader，用于reduce端获取对应的shuffle数据)

### shuffle流程
对于Spark来讲，一些Transformation或Action算子会让RDD产生宽依赖，即parent RDD中的每个Partition被child RDD中的多个Partition使用，这时便需要进行Shuffle，根据Record的key对parent RDD进行重新分区。

以Shuffle为边界，Spark将一个Job划分为不同的Stage，这些Stage构成了一个大粒度的DAG。Spark的Shuffle分为Write和Read两个阶段，分属于两个不同的Stage，前者是Parent Stage的最后一步，后者是Child Stage的第一步。如下图所示:

<div align=center><img src="shuffle流程.png"></div>

执行Shuffle的主体是Stage中的并发任务，这些任务分ShuffleMapTask和ResultTask两种，ShuffleMapTask要进行Shuffle，ResultTask负责返回计算结果，一个Job中只有最后的Stage采用ResultTask，其他的均为ShuffleMapTask。如果要按照map端和reduce端来分析的话，ShuffleMapTask可以即是map端任务，又是reduce端任务，因为Spark中的Shuffle是可以串行的；ResultTask则只能充当reduce端任务的角色。

Write阶段发生于ShuffleMapTask对该Stage的最后一个RDD完成了map端的计算之后，首先会判断是否需要对计算结果进行聚合，然后将最终结果按照不同的reduce端进行区分，写入当前节点的本地磁盘。

Read阶段开始于reduce端的任务读取ShuffledRDD之时，首先通过远程或本地数据拉取获得Write阶段各个节点中属于当前任务的数据，根据数据的Key进行聚合，然后判断是否需要排序，最后生成新的RDD。

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
获取ShuffleReader的唯一实现类BlockStoreShuffleReader

#### unregisterShuffle
从taskIdMapsForShuffle中移除shuffleId和mapTaskIds的映射关系，并且删除shuffleId对应的数据文件和索引文件

## ShuffleWriter
### BypassMergeSortShuffleWriter
BypassMergeSortShuffleWriter和Hash Shuffle中的HashShuffleWriter实现基本一致， 唯一的区别在于，map端的多个输出文件会被汇总为一个文件。 所有分区的数据会合并为同一个文件，会生成一个索引文件，是为了索引到每个分区的起始地址，可以随机 access 某个partition的所有数据。

但是需要注意的是，这种方式不宜有太多分区，因为过程中会并发打开所有分区对应的临时文件，会对文件系统造成很大的压力。

具体实现就是给每个分区分配一个临时文件，对每个 record的key 使用分区器（模式是hash，如果用户自定义就使用自定义的分区器）找到对应分区的输出文件句柄，直接写入文件，没有在内存中使用 buffer。 最后copyStream方法把所有的临时分区文件拷贝到最终的输出文件中，并且记录每个分区的文件起始写入位置，把这些位置数据写入索引文件中。

### UnsafeShuffleWriter

### SortShuffleWriter

## ShuffleReader


