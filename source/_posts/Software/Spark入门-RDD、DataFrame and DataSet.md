---
title: Spark入门-RDD、DataFrame and DataSet
author: 汪寻
date: 2021-09-08 18:26:44
update: 2021-09-08 18:41:44
tags:
 - Spark
categories:
 - Software
---

`RDD(Resilient Distributed Dataset)`叫做弹性分布式数据集，是 Spark 中最基本的数据处理模型。代码中是一个抽象类，它代表一个弹性的、不可变、可分区、里面的元素可并行 计算的集合。而 DataFrame 和 DataSet 分别是 Spark1.3 版本和 1.6 版本开始支持的数据集类型。它们之间彼此依赖也可以互相转换，分别应用在不同的场景下。

<!-- more -->

### RDD

RDD 是 Spark 计算的基础数据集合，之后的 DataFrame 和 DataSet 底层也是封装了 RDD ，所以掌握 RDD 对是学习Spark的第一步，源码中列出了 RDD 的五个特征，分别是：

- A list of partitions
- A function for computing each split
- A list of dependencies on other RDDs
- Optionally, a Partitioner for key-value RDDs (e.g. to say that the RDD is hash-partitioned)
- Optionally, a list of preferred locations to compute each split on (e.g. block locations for an HDFS file)

总结下来就是 RDD 数据结构中存在分区列表，用于执行任务时并行计算；Spark 在计算时使用的是分区函数对每个分区进行计算；RDD 是计算模型的封装，当需要将多个计算模型进行组合时，需要在 RDD 之间建立彼此之间的依赖关系；当数据为 KV 键值对时，可设定分区器自定义数据的分区，可选；计算时可根据节点的状态选择不同的节点位置进行计算，可选。

从代码或者数据方面考虑，RDD 只存储数据，不存在 Schema，例如给它由多个元组组成的 List，它并不知道每个元组的第一个元素代表姓名，第二个元素代表年龄，但我们可以使用样例类封装每个元组，让它知道每个元组代表一个 User，如下：

```scala
// 元组对组成的RDD
val rdd = sc.makeRDD(List(("Bob", 23), ("Alice", 22), ("John", 24)))

// 给每个元组对加上属性
val rdd01 = sc.makeRDD(List(User("Bob", 23), User("Alice", 22), User("John", 24)))

case class User(name: String, age: Int)  // 样例类要放在main方法外
```

### DataFrame

DataFrame 则是为了使 Spark 可以处理结构化数据或者半结构化数据而产生的数据集合，它可以从多个数据源读取数据加以处理，处理方式也可以使用我们熟知的 SQL 或者 Spark 独有的 DSL 语言，你可以将它想象成 RDD 中的每个元素都拥有了 Schema，有了字段名描述数据，但是没有了属性，最新版的 Spark 已经把 DataFrame 作为 DataSet 的一种特殊形式来构建，源码：`type DataFrame = Dataset[Row]`。

```scala
// 从RDD转换
val rdd = sc.makeRDD(List(("Bob", 23), ("Alice", 22), ("John", 24)))
val df = rdd.toDF("name", "age")

// 从文件中获取
spark.read.json("data/user.json")

// DSL
df.select("name", "age", $"age" + 1 as "new_age")
df.filter($"age" > 21)

// SQL
df.createOrReplaceTempView("user")
spark.sql("select *, age + 1 as new_age from user").show()
```

### DataSet

DataSet 是具有强类型的数据集合，需要提供对应的类型信息。在后期的 Spark 版本中，DataSet 有可能会逐步取代 RDD 和 DataFrame 成为唯一的 API 接口。

```scala
import spark.implicits._  // spark是SparkSession对象名，如果涉及到转换，需要引入转换规则

// 从RDD创建
val rdd = sc.makeRDD(List(User("Bob", 23), User("Alice", 22), User("John", 24)))
rdd.toDS  // RDD具有属性时可以直接转，Schema和属性都有了

// 从DF创建
val df = rdd.toDF("name", "age")
df.as[User]  // 需要给DF明确属性

// 需要注意的是从文件中导入的数据在没有指定属性的情况下默认都是DataFrame，加上属性转换就可以转换为DataSet

case class User(name: String, age: Int)  // 样例类要放在main方法外
```

DataSet 和 DataFrame 的最大区别是每一行的类型，也就是强类型和弱类型，我们在处理数据的时候是按行处理的，对每一行的不同字段进行处理就需要定位指定的字段，而 DataFrame 每一行是没有属性的，或者说它是 DataSet 每一行属性固定为 Row 的特例，取指定的值只能通过位置，这有很大的不确定性，并且也不好维护；而 DataSet 在一行内可以使用属性.字段的方式定位属性并加以操作。在自定义 UDF 函数的时候就能感受到强类型和弱类型的区别了。

### 三者的联系与区别

三者的共性、区别和相互之间的转换。

#### 三者的共性

- RDD 、DataFrame 、DataSet 全都是 Spark 平台下的分布式弹性数据集，为处理超大型数据提供便利;
- 三者都有惰性机制，在进行创建、转换，如 map 方法时，不会立即执行，只有在遇到 Action 如 foreach 时，三者才会开始遍历运算;
- 三者有许多共同的函数，如 filter，排序等;
- 在对 DataFrame 和 Dataset 进行操作许多操作都需要这个包：`import spark.implicits._`(在创建好 SparkSession  对象后尽量直接导入)；
- 三者都会根据 Spark 的内存情况自动缓存运算，这样即使数据量很大，也不用担心会内存溢出；
- 三者都有 partition 的概念；
- DataFrame 和 DataSet 均可使用模式匹配获取各个字段的值和类型。

#### 三者的区别

1. **RDD**
   - RDD 一般和 Spark Mllib 同时使用；
   - RDD 不支持 Spark SQL 操作；
2. **DataFrame**
   - 与 RDD 和 Dataset 不同，DataFrame 每一行的类型固定为 Row，每一列的值没法直接访问，只有通过解析才能获取各个字段的值；
   - DataFrame 与 DataSet 一般不与 Spark Mllib 同时使用；
   - DataFrame 与 DataSet 均支持 Spark SQL 的操作，比如 select，groupby 之类，还能注册临时表/视窗，进行 SQL 语句操作；
   - DataFrame 与 DataSet 支持一些特别方便的保存方式，比如保存成 csv，可以带上表头；
3. **DataSet**
   - Dataset 和 DataFrame 拥有完全相同的成员函数，区别只是每一行的数据类型不同；
   - DataFrame 其实就是 DataSet 的一个特例 `type DataFrame = Dataset[Row]`；
   - DataFrame 也可以叫 Dataset[Row] ，每一行的类型是 Row ，不解析，每一行究竟有哪些字段，各个字段又是什么类型都无从得知，只能用上面提到的 getAS 方法或者共性中的第七条提到的模式匹配拿出特定字段。而 Dataset 中，每一行是什么类型是不一定的，在自定义了 case class 之后可以很自由的获得每一行的信息。

#### 相互转换

```scala
import spark.implicits._  // spark是SparkSession对象名，如果涉及到转换，需要引入转换规则

// RDD
val rdd = sc.makeRDD(List(("Bob", 23), ("Alice", 22), ("John", 24)))
rdd.toDF("name", "age")  // RDD转DataFrame
val rdd01 = rdd.map(User(_._1, _._2))  // 需要给RDD带上属性才可以直接转DataSet
rdd01.toDS  // RDD转DataSet

// DataFrame
val df = rdd.toDF("name", "age")
df.rdd  // DataFrame转RDD
df.as[User].toDS  // Dataframe转DataSet，加上属性直接转

// DataSet
val ds = rdd.toDs
ds.rdd  // DataSet转RDD
ds.toDF  // DataSet转DataFrame

case class User(name: String, age: Int)
```

只需要记住每个数据集合的特征就可以灵活的相互转换。RDD 可以是无属性的数据元素，也可以是有属性的数据元素，但是没有 Schema；DataFrame 是有 Schema 的数据元素，但是没有属性；DataSet是有Schema有属性的数据集合，所以从 RDD 到 DataFrame 再到 DataSet 是依次递进的过程。
