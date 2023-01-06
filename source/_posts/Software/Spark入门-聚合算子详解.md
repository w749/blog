---
title: Spark入门-聚合算子详解
author: 汪寻
date: 2021-08-30 12:14:58
updated: 2021-08-30 12:53:21
tags:
 - Spark
categories:
 - Software
---

Spark 中常用的算子加起来有三四十个，其中针对 key 的聚合算子有五个，分别是`groupBy、groupByKey、reduceByKey、aggregateByKey 和 flodByKey`，有几个底层其实调用的都是一个方法，只不过传入的参数不一样产生了这几个算子，但我仍打算分开来详解每个算子的计算过程，加深理解。

<!-- more -->

## Overview

这几个聚合算子要解决的问题都是将所需操作的 RDD 中的 key 值相同的 value 值聚合在一起然后两两做计算也就是聚合最终得出一个结果，这里有三个点需要注意，一是两两聚合的初始值，是从外部传入还是使用默认值；二是分区内聚合方式，因为 RDD 默认是并行计算，会分成多个分区，每个分区内部可以指定聚合方式；三是分区间聚合方式，拿到分区内的聚合结果就要考虑分区间的聚合方式了，这个参数也可以指定。所以这几种算子的区别就是因为传入了不同的参数。

## groupBy

先来说说 groupBy，它是最容易理解的，就是把 key 值相同的 value 值放在一起形成`(key, iter)`的键值对，聚合的话需要使用 map 再对每个 key 对应的 iter 内容做聚合。

```scala
groupBy[K](f: T => K)(implicit kt: ClassTag[K]): RDD[(K, Iterable[T])]
```

先来看看源码，需要传入一个 group 方法 f ，这个f方法传入待分组的元素，返回另外一个值 K，而这个 K 就是分组的依据，注意看最后 groupBy 返回的结果类型也是以 K 和相同 K 的初始元素生成的迭代器所组成的元组，需要对相同K下的 iter 进行聚合就需要再进行 map 操作。

```scala
// 计算初始RDD不同首字母开头的元素数量
val rdd: RDD[String] = sc.makeRDD(List("Hello", "Java", "Python", "PHP", "Help"))
// ('H', ("Hello", "Help")), ('J', ("Java")), ('P', ("Python", "PHP"))
val groupRDD: RDD[(Char, Iterable[String])] = rdd.groupBy(_.charAt(0))
// ('H', 2), ('J', 1), ('P', 2)
val sizeRDD: RDD[(Char, Int)] = groupRDD.map(_._2.size)
sizeRDD.collect().foreach(println)
```

具体过程可以参考下图，第二步添加了 File 落盘动作，因为 group 操作会计算每个分区所有单词的首字母并缓存下来，如果放在内存中若数据过多则会产生内存溢出；再就是第三步从文件读取回来，并不一定是三个分区，这里只是为了便于理解。

<div align=center><img src="groupBy.png"></div>

## groupByKey

groupByKey 相比于 groupBy 不同的是，groupBy 需要指定分组的 key ，而 groupByKey 是将元组这种类型的第一个值作为 key ，对第二个值进行分组的操作。

```scala
groupByKey(): RDD[(K, Iterable[V])]
```

可以看到这个算子不需要传入参数，就是针对元组这种 KV 类型定义的，至于返回值的类型，K 就是元组的第一个值，`Iterable(V)`则是相同 K 值的所有 V 组成的迭代器，那么同时处理元组类型时 groupByKey 和 groupBy 的不同之处就是这里的 V 是元组内的第二个值，而 groupBy 是初始的元素值，具体看下面的例子：

```scala
// 根据RDD内元组的第一个元素将数据分类并对第二个元素求和
val rdd: RDD[(String, Int)] = sc.makeRDD(List(("a", 1), ("a", 3), ("a", 4), ("b", 2)))
// ("a", (1, 3, 4)), ("b", (2))
val groupByKeyRDD: RDD[(String, Iterable[Int])] = sc.groupByKey()
// ("a", (("a", 1), ("a", 3), ("a", 4))), ("b", ("b", 2))
val groupByRDD: RDD[(String, Iterable[(String, Int)])] = sc.groupBy(_._1)

// 当然聚合方式也不相同
groupByKeyRDD.map(_._2.sum)
groupByRDD.map(_._2.map(_._2).sum)
```

groupByKey 也需要落盘操作，会导致数据打乱重组，存在 shuffle 操作，效率相对来说比较低下，这也就引出了 reduceByKey，下面再详细比较两者的不同之处。

<div align=center><img src="groupByKey.png"></div>

## reduceByKey

reduceByKey 相比于 groupByKey 就是把 map 操作集成在算子当中了，不需要再额外进行 map 操作，它和aggregateByKey以及 flodByKey 的操作类似，只不过细节之处需要传入不同的参数区分彼此不同的功能。

```scala
reduceByKey(func: (V, V) => V): RDD[(K, V)]
```

可以看到 reduceByKey 接收一个 func 参数，而这个 func 参数接收两个 V 类型的参数并返回一个 V 类型的结果，这里的 V 其实就是初始 RDD 中的元素，这里需要传入的 func 就是元素两两计算的逻辑。

```scala
// 根据RDD内元组的第一个元素将数据分类并对第二个元素求和
val rdd: RDD[(String, Int)] = sc.makeRDD(List(("a", 1), ("a", 3), ("a", 4), ("b", 2)))
val ReduceByKeyRDD: RDD[(String, Int)] = rdd.reduceByKey(_ + _)  // ("a", 8), ("b", 2)
ReduceByKeyRDD.collect().foreach(println)
```

从下图中的第一张图看相对于 groupByKey 只是少了 map 的步骤将它整合在 reduceByKey 中，但是实际上 reduceByKey 的作用不止于此，第二张图才是实际的运行模式，它提供了 Combine 预聚合的功能，支持在分区中先进行聚合，称作分区内聚合，然后再落盘等待分区间聚合。这样下来它不只是减少了 map 的操作，同时提供了分区内聚合使得 shuffle 落盘时的数据量尽量小，IO 效率也会提高不少。最后它引出了分区内聚合和分区间聚合，reduceByKey 的分区内聚合和分区间聚合是一样的。

<div align=center><img src="reduceByKey.png"></div>

## aggregateByKey

aggregateByKey 是对 reduceByKey 的高级应用，它可以分开来指定分区内聚合和分区间聚合，并提供了一个计算初始值。

```scala
aggregateByKey[U: ClassTag](zeroValue: U)(seqOp: (U, V) => U, combOp: (U, U) => U): RDD[(K, U)]
```

来看上方源码，它采用柯里化操作，第一个参数列表接收一个参数 zeroValue，它提供一个初始值，不同于 reduceByKey 直接开始计算第一个元素和第二个元素，aggregateByKey 允许先用初始值和第一个元素进行两两计算；第二个参数列表接收两个参数，第一个是 seqOp 表示分区内聚合方式，它接收两个参数返回一个参数，注意接收的参数一个 U 的类型和 zeroValue 类型相同，另外一个是初始元素的类型，返回类型是 U 类型，说明返回类型是由 zeroValue 决定的，这很重要；第二个参数 combOp 表示分区间聚合方式，接收两个 U 类型的参数并返回一个 U 类型的参数。最终返回初始元素和聚合后的元素。

```scala
// 给定初始RDD并指定两个分区，分区内计算最大值分区间求和
val rdd: RDD[(String, Int)] = sc.makeRDD(
    List(("a",1), ("a", 2), ("b", 3), ("a", 4), ("a", 5), ("b", 6)), 
    numSlices = 2
)
// (("a", 8), ("b", 8))
val aggregateByKeyRDD: RDD[(String, Int)] = rdd.aggregateByKey(0)(
    (x, y) => math.max(x, y),  // 分区内求最大值
    (x, y) => x + y  // 分区间求和
)
aggregateByKeyRDD.collect().foreach(println)
```

看运行过程就更清晰了，相比于 reduceByKey 只是将分区内聚合和分区间聚合分开来了，并且提供了一个初始值，这个初始值作为第一个元素与初始 RDD 的第一个元素计算，这也就使得初始值不一样哪怕聚合方式相同结果也可能不一样，详情看下图。其次就是分区数量对结果的影响，上方例子如果按三个分区计算结果又不一样了，它作为 aggregateByKey 的第四个决定结果的隐形参数在聚合时也需要考虑在内。

<div align=center><img src="aggregateByKey.png"></div>

## flodByKey

flodByKey 是 aggregateByKey 的特例情况，在分区内聚合方式和分区间聚合方式相同的时候使用。

```scala
foldByKey(zeroValue: V)(func: (V, V) => V): RDD[(K, V)]
```

仍然是柯里化传参，第一个参数列表给定一个初始值，第二个参数列表传入一个聚合函数 func，在一定条件下和 reduceByKey 的结果和聚合方式是相同的。

```scala
// 计算初始值与所有元素的和
val rdd: RDD[Int] = sc.makeRDD(List(("a", 1), ("a", 3), ("a", 4), ("a", 2)), 2)
val foldByKeyRDD: RDD[Int] = rdd.foldByKey(10)(_ + _)  // 10 + 1 + 3 + 10 + 4 + 2 = 30
```

看运行过程还是比较容易理解的，尤其需要注意初始值的设定，不然会产生意想不到的结果。

<div align=center><img src="foldByKey.png"></div>

## Compare

前面把每个算子的详细计算过程都画了一遍，接下来从源码中函数的接收参数中继续看`reduceByKey、aggregateByKey和flodByKey`这三个算子的联系和不同之处，它们的源码中都调用了一个函数`combineByKeyWithClassTag`，接下来来看一看传入的参数。从它们源码调用的函数就可以很清楚的区分这几个算子了，结合不同环境使用不同的算子。

```scala
// reduceByKey
combineByKeyWithClassTag[V]((v: V) => 
                            v,  // 就是初始RDD的值，当作每个分区开始计算的初始值，不需要指定
                            func,  // 分区内聚合
                            func,  // 分区间聚合
                            partitioner)
// aggregateByKey
combineByKeyWithClassTag[U]((v: V) => 
                            cleanedSeqOp(createZero(), v),  // 初始值，柯里化的第一个参数列表
                            cleanedSeqOp,  // 分区内聚合，柯里化的第二个参数列表
                            combOp,  // 分区间聚合，与分区内聚合不相同
                            partitioner)
// flodByKey
combineByKeyWithClassTag[V]((v: V) => 
                            cleanedFunc(createZero(), v),  // 初始值，柯里化的第一个参数列表
                            cleanedFunc,  // 分区内聚合，柯里化的第二个参数列表
                            cleanedFunc,  // 分区间聚合，与分区内聚合相同
                            partitioner)
```

## Application

1. 获取首字母相同 key 数据的和

```scala
val rdd: RDD[(String, Int)] = sc.makeRDD(
  List(("Hello", 1), ("Java", 3), ("Python", 5), ("PHP", 7), ("Help", 9)))

rdd.map(kv => (kv._1.charAt(0), kv._2))  // 先将原始RDD的首字母提出来
  .reduceByKey(_ + _)  // 再按照key进行求和
  .collect()
  .foreach(println)  // ("P",12), ("H", 10), ("C", 3)
```

2. 获取相同 key 数据的平均值

```scala
val rdd: RDD[(String, Int)] = sc.makeRDD(
  List(("a", 1), ("a", 2), ("b", 3), ("b", 4), ("a", 5), ("a", 6), ("b", 7), ("b", 8)), 2)

rdd.aggregateByKey((0.0, 0))(  // 元组第一个元素接收求和数据，0.0避免求均值强转为Int，第二个接收数据计数
  (k, v) => (k._1 + v, k._2 + 1),  // 分区内按key累加、计数
  (k, v) => (k._1 + v._1, k._2 + v._2)  // 分区间将分区内的统计结果累加
)
  .map(kv => (kv._1, kv._2._1 / kv._2._2))  // 求均值
  .collect()
  .foreach(println)  // ("a",3.5), ("b", 5.5)
```

3. 获取相同 key 的数据分区内求均值分区间求和的结果

```scala
rdd.aggregateByKey((0.0, 0))(
  (k, v) => ((k._1 + v), k._2 + 1),
  (k, v) => (k._1 / k._2 + v._1 / v._2, k._2 + v._2)  // 直接在这一步先计算分区内均值再求和
)
  .collect()
  .foreach(println) // ("a",(7.0, 4)), ("b", (11.0, 4))
```

4. 数据如下所示每一行数据是一条点击记录，字段分别为（时间戳 省份 市 用户 广告），计算每个省份点击次数前三名的广告。

```shell
1516609143867 6 7 64 16
1516609143869 9 4 75 18
1516609143869 1 7 87 12
1516609143869 2 8 92 9
1516609143869 6 7 84 24
1516609143869 1 8 95 5
1516609143869 8 1 90 29
1516609143869 3 3 36 16
1516609143869 3 3 54 22
1516609143869 7 6 33 5
```

思考的重点是中间数据结构的转换，刚开始计算的 key 是省份 + 广告，后面的 key 就只有省份了，需要在省份内部做计算。计算过程如下：

```scala
val original: RDD[String] = sc.textFile("data/agent.log")  // 时间戳 省份 市 用户 广告
val mapRDD: RDD[((String, String), Int)] = original.map(str => {
  val strings: Array[String] = str.split(" ")  // 拆分数据并取到省份和广告字段
  ((strings(1), strings(4)), 1)
})
// 计算每个省份每条广告的点击人数
val reduceRDD: RDD[((String, String), Int)] = mapRDD.reduceByKey(_ + _)  
// 转换数据结构，因为最终是计算每个省份内的，所以省份是key，将广告跟点击数放一起
val newMapRDD: RDD[(String, (String, Int))] = reduceRDD.map{ 
  case ((pro, ad), sum) => (pro, (ad, sum)) 
}
// groupBy省份，将所有省份下的所有广告点击数放一起
val groupRDD: RDD[(String, Iterable[(String, Int)])] = newMapRDD.groupByKey()
// 在每个省份内排序，取前三条数据
val mapValuesRDD: RDD[(String, List[(String, Int)])] = groupRDD.mapValues(iter => {
  iter.toList.sortWith(_._2 > _._2).take(3) // sortBy(_._2)(Ordering.Int.reverse)
})
mapValuesRDD.collect().foreach(println)
```
