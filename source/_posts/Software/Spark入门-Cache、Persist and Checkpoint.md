---
title: Spark入门-Cache、Persist and Checkpoint
author: 汪寻
date: 2021-09-11 10:11:51
updated: 2021-09-11 10:55:21
tags:
 - Spark
categories:
 - Software
---

Spark 在运算过程中提供了几个不同程度的持久化操作，通过将数据保存在内存中、磁盘中或者 HDFS 中来满足我们计算中的持久化需求。

<!-- more -->

### 持久化（Persist、Cache）

在实际开发中某些 RDD 的计算或转换可能会比较耗费时间，如果这些 RDD 后续还会频繁的被使用到，那么可以将这些 RDD 进行持久化/缓存，这样下次再使用到的时候就不用再重新计算了，提高了程序运行的效率。Spark 提供了 Persist 和 Cache 两个操作对 RDD 的运算结果进行持久化。

先看一个例子，我们要对一个文件内的单词进行 WordCount 操作，就按 textFile、flatMap、map、reduceByKey 这个顺序执行，然后有一个新需求，需要按单词将所有出现的单词放到一起，这样我们想到了直接使用上一步操作 WordCount 时 map 操作的结果，想象它可以直接使用这一步的数据进行两步操作，但事实上 RDD 是不存储数据的，如果再用到这个数据的话只能是依据它的血缘关系再计算一遍它所依赖的 RDD ，就像下图这样执行。

<div align=center><img src="RDD未缓存.png"></div>

那么 Spark 就给我们提供了 Cache 持久化操作，它允许我们将感兴趣的 RDD 中的数据暂时存储到内存中，以供其他计算再次使用而不需要重新计算之前的 RDD ，这样就达到了我们想要的效果。

<div align=center><img src="RDD缓存.png"></div>

Cache 是 Persist 操作的一个特例，源码`def cache(): this.type = persist()`直接调用的就是无参默认的 Persist ，Persist 需要提供一个参数，默认是MEMORY_ONLY，有 `MEMORY_ONLY（只存储在内存中）、MEMORY_ONLY_SER（在内存中存储序列化数据）、DISK_ONLY（只存储在磁盘中）、DISK_ONLY_2（在内存中存取副本）、MEMORY_AND_DISK（存储在内存中和磁盘中）`等等。只有触发行动算子的时候才会对数据进行缓存操作，需要注意的是 Cache 和 Persist 都只是在 Application 运行过程中存在，一旦 Job 运行完成这些数据就会销毁。

```scala
// persist持久化操作会将RDD数据存储在内存或者磁盘用来复用或是保存重要数据，当前作业完成就会清理掉
rdd.persist(StorageLevel.MEMORY_ONLY)
rdd.cache()  // cache其实就是persist传入MEMORY_ONLY参数值
```

### 检查点（Checkpoint）

持久化 / 缓存可以把数据存储在内存或是磁盘中，但也不是最靠谱的，因为可能会发生宕机或者磁盘损坏，所以就有了检查点 Checkpoint 。它可以将数据存储在 HDFS 上，提供了更高的容错机制，同样也可以选择存储在磁盘上，而且数据也不会随着程序的结束而销毁，对于一些重要数据可以选择 Checkpoint 进行存储。使用它需要指定检查点的存放目录，并在需要的 RDD 下开启它。

关于检查点还有一点需要注意，缓存当前 RDD 时会在它计算完成时将数据缓存到内存或者磁盘中，而检查点并不是，它会重新启动一个 Task 专门为检查点计算数据，所以当前 RDD 会被执行两次，一般为了减少不必要的计算所造成的开销会先将数据缓存到内存中，这样检查点就可以直接从内存中取数并落盘。

```scala
sc.setCheckpointDir("hdfs://node01:9000//spark/checkpoint")  // 设置检查点目录，一般放在HDFS
rdd.cache()
rdd.checkpoint()  // 开启检查点
```

最后是检查点和缓存的血缘关系问题，缓存时会将当前 RDD 的数据以及血缘关系全部保存下来，哪怕分区丢失也可以重新计算，而检查点会将之前的血缘关系全部强制转为 PersistCheckpoint ，无法根据血缘关系再重新计算，这也算是它的一个弊端。
