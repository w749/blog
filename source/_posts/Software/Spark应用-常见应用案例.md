---
title: Spark应用-常见应用案例
author: 汪寻
date: 2021-09-26 11:29:46
update: 2021-09-26 11:33:28
tags:
 - Spark
categories:
 - Software
---

Spark常见应用案例，连接数据库，压缩，输入输出等操作方法。

<!-- more -->

## 工具函数
[Utils](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/Utils.scala)

常用工具函数

## 读写 Excel
[ExcelTest](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/io/ExcelTest.scala)

导入Maven依赖：

```xml
<dependency>
  <groupId>com.crealytics</groupId>
  <artifactId>spark-excel_2.12</artifactId>
  <version>0.13.7</version>
</dependency>
```

使用的是 crealytics 的 [spark-excel]((https://codechina.csdn.net/mirrors/crealytics/spark-excel)) （CSDN 的国内镜像仓库）解决 Excel 的读写问题，可以直接读取为 DataFrame ，
常用的表头、读取 sheet 以及读取位置等参数都可以配置，写入的话支持写入到单个 Excel 文件而不是目录，常用的参数有写入表头、写入位置以及写入模式都参数配置，还支持同一个Excel文件多次写入。

## 读写 MySQL
[MysqlTest](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/io/MysqlTest.scala)

Spark分别使用RDD和DataFrame读写Mysql

## Spark正则多模匹配
[HyperScanJava](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/HyperScanJava.scala)

使用 [hyperscan-java](https://github.com/gliwka/hyperscan-java) 完成多个正则表达式快速匹配一个字符串的需求，
它其实是对C语言编写的HyperScan做了封装，使得效率大大提升，具体查看 [hyperscan](https://github.com/intel/hyperscan) 。如果要在项目中使用在运行时还需添加几个依赖，hyperscan的动态库目前支持windows, linux (glibc >=2.12) and osx for x86_64：
- [javacpp-1.5.4.jar](https://repo1.maven.org/maven2/org/bytedeco/javacpp/1.5.4/javacpp-1.5.4.jar)
- [javacpp-platform-1.5.4.jar](https://repo1.maven.org/maven2/org/bytedeco/javacpp-platform/1.5.4/javacpp-platform-1.5.4.jar)
- [javacpp-1.5.5-linux-x86_64.jar](https://repo1.maven.org/maven2/org/bytedeco/javacpp/1.5.5/javacpp-1.5.5-linux-x86.jar)
- [hyperscan-5.4.0-2.0.0.jar](https://repo1.maven.org/maven2/com/gliwka/hyperscan/hyperscan/5.4.0-2.0.0/hyperscan-5.4.0-2.0.0.jar)
- [native-5.4.0-1.0.0.jar](https://repo1.maven.org/maven2/com/gliwka/hyperscan/native/5.4.0-1.0.0/native-5.4.0-1.0.0.jar)
- [native-5.4.0-1.0.0-linux-x86_64.jar](https://repo1.maven.org/maven2/com/gliwka/hyperscan/native/5.4.0-1.0.0/native-5.4.0-1.0.0-linux-x86_64.jar)
- [native-5.4.0-1.0.0-windows-x86_64.jar](https://repo1.maven.org/maven2/com/gliwka/hyperscan/native/5.4.0-1.0.0/native-5.4.0-1.0.0-windows-x86_64.jar)
- [native-5.4.0-1.0.0-macosx-x86_64.jar](https://repo1.maven.org/maven2/com/gliwka/hyperscan/native/5.4.0-1.0.0/native-5.4.0-1.0.0-macosx-x86_64.jar)

<div align=center><img src="16657181106060.png"></div>

## Spark解压缩tar.gz
[TarGzipCodec](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/TarGzipCodec.scala)

自定义CompressionCodec实现输入输出tar.gz压缩格式。其中读取数据的实现没什么问题，压缩为tar.gz的时候会有一些问题，
创建tar输出流时必须指定一个TarArchiveEntry的size，代表需要归档的数据大小，但是spark运行时无法获取最终写入的数据大小，所以就无法通过这种方式写入，
最终想到一个办法是先将需要写入的数据放在一个ArrayBuffer中，close流的时候再遍历写入，这种方法在输出数据量特别大时可能会造成内存溢出

[compressTextFile](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/TarGzipCodec.scala#L48)

还可以通过另外一种方式就是先输出为text file，然后再将它压缩为tar.gz文件，缺点是先要写出到一个临时目录中，而且text file会占用大量空间，不过好在这种方式速度并不会很慢

## Spark多目录输出
[MultipleOutputFormat](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/MultipleOutputFormat.scala)

自定义MultipleTextOutputFormat，满足根据key自定义输出目录以及输出文件名称的需求，并且不输出key

## Spark获取输入的数据所属文件名称
[GetInputFileName](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/GetInputFileName.scala)

Spark获取输入的数据所属文件名称，如需获取全路径可以在getPath后调用toUri方法再调用getName

## Spark指定每个分区的输出大小
[ControlPartitionSize](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/ControlPartitionSize.scala)

Spark指定每个分区的输出大小，提供了三种方法，分别是自定义分区器（repartitionData）、重分区（restoreData），这两种方法主要利用了FileSystem的getContentSummary方法获取到输入数据的大小，计算出输出指定大小的分区所需的分区数量，
第三种方法通过控制split size的目的达到控制每个分区的数据大小，但是这种方法会将超出指定大小的数据单存到一个文件中（128M会分为100M和28M），达不到所有文件的大小相等，经过测试restoreData方法最靠谱。

这几种方式必须是输入和输出数据相同未经过过滤或者flat，如果输入输出数据大小不相同可以借助临时目录

## SparkListener事件监听
[SparkListenerCase](https://github.com/w749/bigdata-example/blob/master/spark-test/src/main/scala/org/example/spark/cases/SparkListenerCase.scala)

SparkListener监听器，负责监视Spark作业运行时的状态，可以自定义实现SparkListener收集运行时的状态