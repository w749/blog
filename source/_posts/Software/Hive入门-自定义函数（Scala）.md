---
title: Hive入门-自定义函数（Scala）
author: 汪寻
date: 2021-10-31
tags:
 - Hive
categories:
 - Software

---

Hive 自定义函数的开发，使用 Scala 语言开发，目前只有 UDF 函数

<!-- more -->

首先需要导入相关的依赖，注意自己的 Hive 和 Hadoop 版本。其次是 @Description 装饰，name 是函数名，value 是函数及参数以及函数介绍，extended 则是函数的详细使用方法，这些信息在 Hive 中`desc function extended func_name`的时候会显示出来（但是我测试失败了）

```xml
<dependencies>
    <!--hadoop版本信息-->
    <dependency>
        <groupId>org.apache.hadoop</groupId>
        <artifactId>hadoop-client</artifactId>
        <version>3.1.3</version>
    </dependency>

    <!--hive版本信息-->
    <dependency>
        <groupId>org.apache.hive</groupId>
        <artifactId>hive-exec</artifactId>
        <version>3.1.2</version>
    </dependency>
</dependencies>
```

Hive UDF函数需要继承`org.apache.hadoop.hive.ql.exec.udf`类，不需要重写函数，只需要在继承的类中定义 evaluate 方法即可，main 方法是为了测试函数。

```scala
package hive_scala

import org.apache.hadoop.hive.ql.exec.UDF
import org.apache.hadoop.hive.ql.exec.Description

@Description(
  name = "concat_name",
  value = "concat_name(str) - Concat 'name:' to str\n",
  extended = "    SELECT concat_name('wxk');\n" +
    "    'name:wxk'")
/**
 * 给输入的字符串加上Name：前缀
 */
object UDFConcatName extends UDF {

  private val name: String = "Name: "

  def evaluate(str: String): String = {
    name + str
  }

  def main(args: Array[String]): Unit = {
    println(evaluate("wxk"))
  }
}
```

然后是在 Hive 中注册使用，首先是将代码打包，然后可以在代码中直接使用命令将 jar 包添加到 classpath 中，再注册使用，不过仅限于当前会话，也可以将 jar 包传入 HDFS 创建永久函数，多个会话可以多次使用

```sql
-- 当前会话中使用
add jar /home/warehouse/UDFConcatName-1.0.jar;
list jars;  -- 查看当前job的classpath
create temporary function concat_name as 'hive_scala.UDFConcatName';
select concat_name('张三') as concatName;
drop temporary function if exists concat_name;

-- 注册永久函数
hadoop fs -put /home/warehouse/UDFConcatName-1.0.jar /warehouse/functions/
create function concat_name as 'hive_scala.UDFConcatName' using 'hdfs://warehouse/functions/UDFConcatName-1.0.jar';
select concat_name('张三') as concatName;
drop function if exists concat_name;
reload functions;  -- 其他会话可以使用使用reload更新函数
```

UDAF 和 UDTF 看不懂，还是用 Spark 吧。。。

