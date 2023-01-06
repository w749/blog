---
title: Spark入门-Dependencies、Lineage and Stage
author: 汪寻
date: 2021-09-10 19:20:57
updated: 2021-09-10 19:43:42
tags:
 - Spark
categories:
 - Software
---

Spark 中比较重要的一块就是血缘关系和阶段划分，虽说并不能像累加器或者广播变量解决特定的需求，但对于理解 Spark 计算的任务执行调度有很大的帮助。

<!-- more -->

### Lineage（血缘关系）

RDD 只支持粗粒度转换，即在大量记录上执行的单个操作。将创建 RDD 的一系列 Lineage (血统)记录下来，以便恢复丢失的分区。RDD 的 Lineage 会记录 RDD 的元数据信息和转换行为，当该 RDD 的部分分区数据丢失时，它可以根据这些信息来重新运算和恢复丢失的数据分区。

RDD 不保存数据，在没有缓存和检查点的情况下如果需要重复使用 RDD 或者分区丢失只能通过依赖上游的血缘关系恢复当前 RDD 的操作。

```scala
val fileRDD: RDD[String] = sc.textFile("input/1.txt")
println("-----------textFile-----------")
println(fileRDD.toDebugString)

val wordRDD: RDD[String] = fileRDD.flatMap(_.split(" "))
println("-----------flatMap-----------")
println(wordRDD.toDebugString)

val mapRDD: RDD[(String, Int)] = wordRDD.map((_,1))
println("-----------map-----------")
println(mapRDD.toDebugString)

val resultRDD: RDD[(String, Int)] = mapRDD.reduceByKey(_+_)
println("-----------reduceByKey-----------")
println(resultRDD.toDebugString)

resultRDD.collect()
```

以上是 WordCount 的步骤，将每一个步骤中的 RDD 的血缘关系打印出来就会发现它们彼此之间存在联系相互依赖。

```shell
-----------textFile-----------
(2) data/WordCount01 MapPartitionsRDD[1] at textFile at RRR.scala:12 []
 |  data/WordCount01 HadoopRDD[0] at textFile at RRR.scala:12 []
-----------flatMap-----------
(2) MapPartitionsRDD[2] at flatMap at RRR.scala:15 []
 |  data/WordCount01 MapPartitionsRDD[1] at textFile at RRR.scala:12 []
 |  data/WordCount01 HadoopRDD[0] at textFile at RRR.scala:12 []
-----------map-----------
(2) MapPartitionsRDD[3] at map at RRR.scala:18 []
 |  MapPartitionsRDD[2] at flatMap at RRR.scala:15 []
 |  data/WordCount01 MapPartitionsRDD[1] at textFile at RRR.scala:12 []
 |  data/WordCount01 HadoopRDD[0] at textFile at RRR.scala:12 []
-----------reduceByKey-----------
(2) ShuffledRDD[4] at reduceByKey at RRR.scala:21 []
 +-(2) MapPartitionsRDD[3] at map at RRR.scala:18 []
    |  MapPartitionsRDD[2] at flatMap at RRR.scala:15 []
    |  data/WordCount01 MapPartitionsRDD[1] at textFile at RRR.scala:12 []
    |  data/WordCount01 HadoopRDD[0] at textFile at RRR.scala:12 []
```

上方输出结果一目了然，下游依次依赖上游直至创建 RDD 的最初状态，看下图可以更直观的感受这个血缘关系。

<div align=center><img src="血缘关系.png"></div>

### Dependencies（依赖关系）

这里所谓的依赖关系，其实就是两个相邻 RDD 之间的关系。查看依赖使用 dependencies 属性，不过并没有血缘关系展示的直观。

```scala
val fileRDD: RDD[String] = sc.textFile("data/WordCount01")
println("-----------textFile-----------")
println(fileRDD.dependencies)

val wordRDD: RDD[String] = fileRDD.flatMap(_.split(" "))
println("-----------flatMap-----------")
println(wordRDD.dependencies)

val mapRDD: RDD[(String, Int)] = wordRDD.map((_,1))
println("-----------map-----------")
println(mapRDD.dependencies)

val resultRDD: RDD[(String, Int)] = mapRDD.reduceByKey(_+_)
println("-----------reduceByKey-----------")
println(resultRDD.dependencies)

resultRDD.collect()
```

输出

```shell
-----------textFile-----------
List(org.apache.spark.OneToOneDependency@787e4357)
-----------flatMap-----------
List(org.apache.spark.OneToOneDependency@21ea996f)
-----------map-----------
List(org.apache.spark.OneToOneDependency@6af5b246)
-----------reduceByKey-----------
List(org.apache.spark.ShuffleDependency@3079c26a)
```

RDD 之间的依赖又分为窄依赖和宽依赖，它其实是根据前后两个 RDD 之间的转变是否打乱分区决定的，看图

<div align=center><img src="窄依赖.png"></div>

上图为窄依赖，父 RDD 的一个分区只会被子 RDD 的一个分区依赖。RDD 操作前后的分区数和分区内的数据是不变的，不用打乱 Shuffle，一般 map、foreach 这种操作都会形成窄依赖。

<div align=center><img src="宽依赖.png"></div>

上图为宽依赖，父 RDD 的一个分区会被子 RDD 的多个分区依赖(涉及到 shuffle )。如果有 group、reduce 这些会产生 Shuffle 打乱原 RDD 分区的操作，那么两个 RDD 之间就是宽依赖。

那么为什么要设计宽窄依赖呢，对于窄依赖：它的多个分区可以并行计算，而且每一个分区的数据如果丢失只需要重新计算对应的分区的数据就可以了。而对于宽依赖：它是划分 Stage 的依据，宽依赖必须等到上一阶段计算完成才能计算下一阶段。

### Stage（阶段划分）

#### DAG

DAG(Directed Acyclic Graph 有向无环图)指的是数据转换执行的过程，有方向，无闭环(其实就是 RDD 执行的流程)；原始的 RDD 通过一系列的转换操作就形成了 DAG 有向无环图，任务执行时，可以按照 DAG 的描述，执行真正的计算(数据被操作的一个过程)。

DAG 的边界是通过 Action 行动算子来划分的，开始：通过 SparkContext 创建的 RDD；结束：触发 Action，一旦触发 Action 就形成了一个完整的 DAG。

#### DAG 划分 Stage

<div align=center><img src="Stage.png"></div>

- 一个 Spark 程序中可以有多个 DAG（有几个 Action 算子就有几个 DAG，上图有一个 Action 算子就只有一个 DAG ），一个 DAG 可以有多个 Stage（根据宽依赖 / Shuffle 进行划分）。
- 同一个 Stage 可以有多个 Task 并行执行（ Task 数=分区数，上图有三个 Task 就有三个分区，需要注意这和有几个 executor 没关系，每台机器分配几个核就有几个 executor，然后根据这台机器上运行几个 Task 来决定每个 executor 运行几个 Task ）。可以看到上图 DAG 中只有 reduceByKey 操作是一个宽依赖，Spark 内核会以此为边界将其前后划分成不同的 Stage。
- 同时我们可以注意到，在图中 Stage1 中，从 textFile 到 flatMap 到 map 都是窄依赖，这几步操作可以形成一个流水线操作，通过 flatMap 操作生成的 partition 可以不用等待整个 RDD 计算结束，而是继续进行 map 操作，这样大大提高了计算的效率。

#### 为何要划分 Stage

一个复杂的业务逻辑如果有 shuffle，那么就意味着前面阶段产生结果后，才能执行下一个阶段，即下一个阶段的计算要依赖上一个阶段的数据。那么我们按照 shuffle / 宽依赖进行划分，就可以将一个 DAG 划分成多个 Stage / 阶段，在同一个 Stage 中，会有多个算子操作，可以形成一个 pipeline 流水线，流水线内的多个平行的分区可以并行执行。

对于窄依赖划分 Stage 时，partition 的转换处理在 Stage 中完成计算，不划分(将窄依赖尽量放在在同一个 Stage 中，可以实现流水线计算)。对于宽依赖，由于有 Shuffle 的存在，只能在父 RDD 处理完成后，才能开始接下来的计算，也就是说需要划分 Stage 。

Spark 会根据 Shuffle / 宽依赖使用回溯算法来对 DAG 进行 Stage 划分，从后往前，遇到宽依赖就断开，遇到窄依赖就把当前的 RDD 加入到当前的 Stage / 阶段中，这一点可以使用 RDD 的 toDebugString 方法查看，看到`+-`符号就是断开划分阶段。

DAGScheduler 按照 ShuffleDependency 作为 Stage 的划分节点对 RDD 的 DAG 进行 Stage 划分（上游的 Stage 将为 ShuffleMapStage）。因此一个 Job 可能被划分为一到多个 Stage 。Stage 分为 ShuffleMapStage 和 ResultStage 两种。

### Job 和 Task

- Job：用户提交的作业。当 RDD 及其 DAG 被提交给 DAGScheduler 调度后，DAGScheduler 会将所有 RDD 中的转换及动作视为一个 Job。一个 Job 由一到多个 Task 组成。
- Task：具体执行任务。一个 Job 在每个 Stage 内都会按照 RDD 的 Partition 数量，创建多个 Task。Task 分为 ShuffleMapTask 和 ResultTask 两种。ShuffleMapStage 中的 Task 为 ShuffleMapTask，而 ResultStage 中 的 Task 为 ResultTask。ShuffleMapTask 和 ResultTask 类似于 Hadoop 中的 Map 任务和 Reduce 任务。
oozie job -oozie http://localhost:11000/oozie -rerun 0000411-180116183039102-oozie-hado-C