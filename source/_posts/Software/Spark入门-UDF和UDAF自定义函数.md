---
title: Spark入门-UDF和UDAF自定义函数
author: 汪寻
date: 2021-09-09 17:24:18
updated: 2021-09-09 17:46:41
tags:
 - Spark
categories:
 - Software
---

在 Spark 处理数据的过程中，虽然 DataSet 下的算子不多，但已经可以处理大多数的数据需求，但仍有少数需求需要自定义函数。UDF(User Defined Functions) 是普通的不会产生 Shuffle 不会划分新的阶段的用户自定义函数，UDAF(User Defined Aggregator Functions) 则会打乱分区，用户自定义聚合函数。

<!-- more -->

### UDF

因为 UDF 不需要打乱分区，直接对 RDD 每个分区中的数据进行处理并返回当前分区，所以可以直接注册 UDF 函数，甚至可以传入匿名函数。

```scala
import org.apache.spark.sql.functions  // DSL中定义UDF需要

val rdd: RDD[User] = spark.sparkContext.makeRDD(
  List(User("Bob", 23), User("Alice", 22), User("John", 24)))
val ds: Dataset[User] = rdd.toDS
ds.createOrReplaceTempView("user")

// SQL中使用就需要注册UDF
spark.udf.register("add_name", (str: String) => { "Name: " + str })
spark.sql("select name, add_name(name) as new_name from user").show()

// 使用DSL则不用注册，定义好直接使用即可
val add_name2: UserDefinedFunction = functions.udf((str: String) => {
  "Name: " + str
})
ds.withColumn("name", add_name2($"name")).show()  
```

### UDAF

相比较 UDF 而言因为 UDAF 是聚合函数所以要打乱分区，所以也就比较复杂，并且需要重写指定的方法来定义。需要注意的是针对弱类型的 UserDefinedAggregateFunction 已经弃用，普遍使用强类型的 Aggregator ，同时若想在 Spark3.0 版本之前使用强类型 UDAF 和 Spark3.0 版本之后的定义方式略有不同。数据如下，计算每家门店的用户数量以及总付款额

```shell
store,user,payment
1,Bob,12.00
1,Alice,44.12
1,John,23.20
2,Davin,79.00
2,Lim,33.30
...
```

#### UserDefinedAggregateFunction

首先是已经弃用的 UserDefinedAggregateFunction，以防生产环境中仍有使用老版本的 Spark。它使用的是弱类型，所以在编写过程中你会看到使用 0 或者 1 来指定位置，这十分不方便。先是数据构建和调用部分

```scala
// 注册并调用UDAF，写在main方法中
val ds: Dataset[Record] = spark
  .sparkContext
  .makeRDD(
    List(Record(1, "Bob", 12.00), Record(1, "Alice", 44.12), Record(1, "John", 23.20),
      Record(2, "Davin", 79.00), Record(2, "Lim", 33.30))).toDS

ds.createOrReplaceTempView("record")
spark.udf.register("myudaf01", new MyUDAF01)  // 注册UDAF函数
spark.sql(
  """
    |select store, myudaf01(payment) as summary from record group by store
    |""".stripMargin).show(truncate = false)

// 样例类，写在main方法外
case class Record(store: Int, name: String, payment: Double)
```

下面是 UDAF 类

```scala
// UDAF部分，写在main方法外
class MyUDAF01 extends UserDefinedAggregateFunction {
  
	// 聚合函数输入参数的数据类型
  override def inputSchema: StructType = {
    StructType(Array(StructField("payment", DoubleType)))
  }
  
	// 聚合函数缓冲区中值的类型
  override def bufferSchema: StructType = {
    StructType(Array(
      StructField("total_user", IntegerType),
      StructField("total_payment", DoubleType)
    ))
  }
  
	// 函数返回的数据类型
  override def dataType: DataType = StringType
  
	// 对于相同的输入是否一直返回相同的输出
  override def deterministic: Boolean = true
  
	// 函数buffer缓冲区初始化，初始值
  override def initialize(buffer: MutableAggregationBuffer): Unit = {
    buffer(0) = 0  // 人数初始值
    buffer(1) = 0.00  // 总额初始值
  }
  
	// 更新缓冲区中的数据
  override def update(buffer: MutableAggregationBuffer, input: Row): Unit = {
    buffer(0) = buffer.getInt(0) + 1
    buffer(1) = buffer.getDouble(1) + input.getDouble(0)
  }
  
	// 合并缓冲区（类似于reduce，属于两个元素的合并规则）
  override def merge(buffer1: MutableAggregationBuffer, buffer2: Row): Unit = {
    buffer1(0) = buffer1.getInt(0) + buffer2.getInt(0)
    buffer1(1) = buffer1.getDouble(1) + buffer2.getDouble(1)
  }
  
	// 计算最终结果
  override def evaluate(buffer: Row): Any = 
  "user: " + buffer.getInt(0) + ",payment: " + buffer.getDouble(1)
}
```

### Aggregator（Spark3.0版本以后）

接下来是 Aggregator，使用的是强类型编写，需要实现不同的特质，将输入、Buffer 以及输出全部定义在了泛型中，这样编写过程中就不需要使用位置来定位了，而且重写方法也简单易懂。

```scala
spark.udf.register("myudaf02", functions.udaf(new MyUDAF02))  // 注册UDAF函数
spark.sql(
  """
    |select store, myudaf02(payment) from record group by store
    |""".stripMargin).show(truncate = false)
```

下面是 UDAF 类

```scala
case class StoreSummary(var user: Int, var payment: Double)  // 强类型UDAF函数Buffer类型

class MyUDAF02 extends Aggregator[Double, StoreSummary, String] {
  
  // 初始化Buffer中的字段
  override def zero: StoreSummary = {
    StoreSummary(0, 0.00)
  }

  // 输入到Buffer的聚合
  override def reduce(b: StoreSummary, a: Double): StoreSummary = {
    b.user += 1
    b.payment += a
    b
  }

  // 合并Buffer
  override def merge(b1: StoreSummary, b2: StoreSummary): StoreSummary = {
    b1.user += b2.user
    b1.payment += b2.payment
    b1
  }

  // 最终的计算结果
  override def finish(reduction: StoreSummary): String = {
    "user: " + reduction.user + ",payment: " + reduction.payment
  }

  // Dataset默认编码器，用于序列化，固定写法
  override def bufferEncoder: Encoder[StoreSummary] = Encoders.product

  override def outputEncoder: Encoder[String] = Encoders.STRING
}
```

可以看到不管是从代码量还是调用参数相比于弱类型便捷了很多，需要注意的是注册函数时需要调用 functions 下的 udaf 方法，还有一点就是这是 Spark3.0 以后的写法，Spark3.0 以前如果想用强类型有其他的写法。

输出使用强弱类型 UDAF 查询的结果

```shell
+-----+----------------------+----------------------+
|store|myudaf01(payment)     |myudaf02(payment)     |
+-----+----------------------+----------------------+
|1    |user: 3,payment: 79.32|user: 3,payment: 79.32|
|2    |user: 2,payment: 112.3|user: 2,payment: 112.3|
+-----+----------------------+----------------------+
```

### Aggregator（Spark3.0版本以前）

早期版本中不能在 SQL 中使用强类型 UDAF ，但是可以在 DSL 中使用，代码编写和调用方式都有所不同，DSL 注重的是类型，所以在 UDAF 输入类型这里传入的应该是 DataSet 每一行的类型，而不是固定字段的某个类型。

```scala
val myudaf03: TypedColumn[Double, String] = (new MyUDAF03).toColumn
ds.select(myudaf03).show  // 输出的并没有按门店分组，与预想结果不同，没深究
```

下面是 UDAF 类

```scala
class MyUDAF03 extends Aggregator[Record, StoreSummary, String] {
    override def zero: StoreSummary = {
      StoreSummary(0, 0.00)
    }

    override def reduce(b: StoreSummary, a: Record): StoreSummary = {
      b.user += 1
      b.payment += a.payment
      b
    }

    override def merge(b1: StoreSummary, b2: StoreSummary): StoreSummary = {
      b1.user += b2.user
      b1.payment += b2.payment
      b1
    }

    override def finish(reduction: StoreSummary): String = {
      "user: " + reduction.user + ",payment: " + reduction.payment
    }

    override def bufferEncoder: Encoder[StoreSummary] = Encoders.product

    override def outputEncoder: Encoder[String] = Encoders.STRING
  }
```

其实就是将输入类型改成了 DataSet 的类型，代码中再调用指定的字段即可。
