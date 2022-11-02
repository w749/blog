---
title: HBase-02API操作
author: 汪寻
date: 2022-02-15
tags:
 - HBase
categories:
 - Software
---

HBase 的基础 API 操作，批量读写主要整合 Spark 来做数据的导入导出。

<!-- more -->

### Client API

代码主要使用 Scala 编写，只列出了基本的操作方法。新的 API 有两个入口，分别是 Admin 和 Table，Admin 管理表，Table 操作表数据，命令行支持的所有方法基本都能在这两个接口下找到。

#### HBase Connection

需要新建一个 HBase 配置，可以直接 addResource 或者使用 set 方法指定连接所需配置信息，然后再使用 Conenction 工厂方法创建连接，connection 用完记得 close。

```scala
val conf = HBaseConfiguration.create()
conf.addResource("hbase-site.xml")
val connection = ConnectionFactory.createConnection(conf)
```

#### Create

调用 Connection 的 getAdmin 方法返回 Admin 对象，检查表不存在后再建表。建表需要传入 ColumnFamilyDescriptor 对象，使用 ColumnFamilyDescriptorBuilder.newBuilder 创建对象并在里面指定建表所需的参数，最后直接调用 Admin 对象的 createTable 方法，参数可以传入单个或多个 ColumnFamilyDescriptor 对象。若要指定 namespace 直接跟表名写在一起：space:table，Admin对象用完需要 close。

```scala
def createTable(tableName: String, columnFamily: List[String]): Unit = {
  val admin = connection.getAdmin
  if (admin.tableExists(TableName.valueOf(tableName))) {
    LOG.warn(s"表 ${tableName} 已存在")
  } else {
    val cfs = columnFamily.map(cf => ColumnFamilyDescriptorBuilder.newBuilder(Bytes.toBytes(cf)).build())
    val desc = TableDescriptorBuilder
      .newBuilder(TableName.valueOf(tableName))
      .setColumnFamilies(cfs.asJavaCollection)
      .build()
    admin.createTable(desc)
    LOG.info(s"表 ${tableName} 创建成功")
  }
  admin.close()
}

createTable("test", "info")
```

#### Put

put 需要在 Table 对象下操作，使用 getTable 并传入 TableName 对象得到 Table，然后新建一个 Put 对象，添加列簇、列限定符和数据等信息，再将它传给 Table 对象的 put 方法即可，最后再关闭 Table对象。

```scala
def putData(tableName: String, rowKey: String, cf: String, column: String, value: String): Unit = {
  val table = connection.getTable(TableName.valueOf(tableName))
  val put = new Put(Bytes.toBytes(rowKey))
  put.addColumn(Bytes.toBytes(cf), Bytes.toBytes(column), Bytes.toBytes(value))
  table.put(put)
  LOG.info(s"table '${tableName}' rowKey '${rowKey}' insert complete")
  table.close()
}

putData("test", "1", "info", "name", "Bob")
```

#### Get/Scan

我把 get 和 scan 功能整合在一个方法中，使用 Scan 构造对象的时候可以将 Get 对象传进去转为 Scan 对象。

首先还是先构建 Table 对象，这里先对列簇和列限定符参数做了一些判断。不指定列簇则返回所有列簇内的所有字段，列簇和 cfColumn 不可以同时指定，指定列簇则返回列簇包含的所有字段。指定列限定符则是通过 Map 的方式传进去，然后调用 Scan 的 addColumn 方法逐个新增到对象中。

调用 getScanner 方法后即可返回 Result 对象组成的列表，Result 对象内包含着一条记录的所有内容，它是由多个 Cell 组成的，每个 Cell 包含了`rowKey, columnFamily, qualifier, value`等数据，新版本中则使用 CellUtil.cloneRow(cell) 等方法取出对应的数据，除过 getTimestamp 方法其他的 Cell 获取属性的成员方法已经弃用，应避免使用。

最后别忘记关闭 scanner 和 table。

```scala
def getData(tableName: String,
            rowKey: String = "",
            cf: String = "",
            cfColumn: Map[String, String] = Map[String, String]()): Unit = {
  var scan = new Scan()
  val table = connection.getTable(TableName.valueOf(tableName))
  if (cf.nonEmpty && cfColumn.nonEmpty) {
    throw new RuntimeException("限定字段在cfColumn中指定，cf和cfColumn不可同时指定")
  }
  if (rowKey.nonEmpty) {
    val get = new Get(Bytes.toBytes(rowKey))
    scan = new Scan(get)
  }
  if (cf.nonEmpty) {
    scan.addFamily(Bytes.toBytes(cf))
  }
  if (cfColumn.nonEmpty) {
    cfColumn.foreach(col => scan.addColumn(Bytes.toBytes(col._1), Bytes.toBytes(col._2)))
  }

  val scanner = table.getScanner(scan)
  scanner.asScala.toList.foreach {
    result => result.rawCells().foreach {
      cell => {
        val data = MyCell.builder(CellUtil.cloneRow(cell),
          CellUtil.cloneFamily(cell),
          CellUtil.cloneQualifier(cell),
          CellUtil.cloneValue(cell),
          cell.getTimestamp).toString
        println(data)
      }
    }
  }
  scanner.close()
  table.close()
}

getData("test", "1")  // get
getData("test", "1", cfColumn = Map("info" -> "name"))  // get指定列限定符
getData("test")  // scan
```

### Spark 读写

#### Read

主要用到 SparkContext 的 newAPIHadoopRDD 将数据读为 RDD，再定义好 schema 转为 DataFrame，测试使用的是 Spark 2.3.2，中间会有些问题，但 debug 时数据确实可以取出来，生产中用到了再研究吧。

```scala
  /**
   * 使用Spark将HBase数据读取为DataFrame
   * @param connection Connection
   * @param session SparkSession
   * @param table table名字
   * @param cf 列簇
   * @param fields 字段
   * @return
   */
  def readAsDf(connection: Connection, session: SparkSession, table: String, cf: String, fields: List[String]): DataFrame = {
    // 配置要读取的表和字段
    val hbaseConf: Configuration = connection.getConfiguration
    hbaseConf.set(TableInputFormat.INPUT_TABLE, table)
    fields.filter(field => !field.equalsIgnoreCase("rowkey"))
    hbaseConf.set(TableInputFormat.SCAN_COLUMNS,
      fields
        .filter(field => !field.equalsIgnoreCase("rowkey"))
        .map(field => s"${cf}:${field}")
        .mkString(" "))

    // 将数据读为RDD
    val hbaseRDD: RDD[(ImmutableBytesWritable, Result)] = session.sparkContext.newAPIHadoopRDD(
      hbaseConf,
      classOf[TableInputFormat],
      classOf[ImmutableBytesWritable],
      classOf[Result])

    // 解析读出来的数据为目标RDD
    val rowRDD = hbaseRDD.map{row => {
      val values: ListBuffer[String] = new ListBuffer[String]
      val result: Result             = row._2
      val cells = result.rawCells()
      for (cell <- cells) {
        println(Bytes.toString(CellUtil.cloneRow(cell)))
        println(Bytes.toString(CellUtil.cloneValue(cell)))
      }
      for (i <- fields.indices) {
        if (fields(i).equalsIgnoreCase("rowkey")) {
          values += Bytes.toString(result.getRow)
        } else {
          values += Bytes.toString(result.getValue(Bytes.toBytes(cf), Bytes.toBytes(fields(i))))
        }
      }
      Row.fromSeq(values.toList)
    }}

    // 构建DataFrame Schema并创建
    val schema = StructType(
      fields.map(field => DataTypes.createStructField(field, DataTypes.StringType, true)))
    val dataFrame = session.createDataFrame(rowRDD, schema)

    session.close()
    dataFrame
  }
```

#### Write

主要是用到 HBase 的 BulkLoad 功能，原理是直接将数据写入 HFile 再加载到 Region 中，好处是少了写入 MemStore 和 WAL，没了刷写的步骤，效率提升不少，但数据写入期间如果丢失无法恢复。在批量写入大量数据时可以选择这种方法。

```scala
  /**
   * 通过Spark写入DataFrame到HBase
   * @param connection Connection
   * @param session SparkSession
   * @param data DataFrame数据
   * @param tableName 表名
   * @param rowKey 以哪一列作为rowKey字段
   * @param cf 写入到哪个列簇
   */
  def writeFromDf(connection: Connection, session: SparkSession, data: DataFrame, tableName: String, rowKey: String, cf: String): Unit = {
    val hbaseConf: Configuration = connection.getConfiguration
    var fields = data.columns
    val table = TableName.valueOf(tableName.getBytes())
    val stagingDir = "/tmp/HBaseBulkLoad"  // 不会覆盖，需要手动删除或每次用完后删除

    //去掉rowKey字段
    fields = fields.dropWhile(_ == rowKey)

    val hbaseContext = new HBaseContext(session.sparkContext, hbaseConf)

    //将DataFrame转换bulkLoad需要的RDD格式
    val rddTmp: RDD[Array[(Array[Byte], Array[(Array[Byte], Array[Byte], Array[Byte])])]] = data.rdd.map(row => {
      val rk = row.getAs[String](rowKey)

      fields.map(field => {
        val value = row.getAs[String](field)
        (Bytes.toBytes(rk), Array((Bytes.toBytes(cf), Bytes.toBytes(field), Bytes.toBytes(value))))
      })
    })
    val rddNew: RDD[(Array[Byte], Array[(Array[Byte], Array[Byte], Array[Byte])])] = rddTmp.flatMap(array => array)
    rddNew.hbaseBulkLoad(hbaseContext, table,
      t => {
        val rowKey = t._1
        val family:Array[Byte] = t._2(0)._1
        val qualifier = t._2(0)._2
        val value = t._2(0)._3
        val keyFamilyQualifier= new KeyFamilyQualifier(rowKey, family, qualifier)

        Seq((keyFamilyQualifier, value)).iterator
      },
      stagingDir)

    // bulk load start
    val loader = new LoadIncrementalHFiles(hbaseConf)
    loader.doBulkLoad(new Path(stagingDir), connection.getAdmin, connection.getTable(table),
      connection.getRegionLocator(table))

    session.close()
  }
```

#### 整合 Spark DataSource
