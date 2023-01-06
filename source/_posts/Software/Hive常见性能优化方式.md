---
title: Hive常见性能优化方式
author: 汪寻
date: 2021-08-06 15:28:56
update: 2021-08-06 15:39:20
tags:
 - Hive
 - 优化
categories:
 - Software
---

从设计优化、数据存储优化和 Job 作业优化三方面提升 Hive 处理性能。

<!-- more -->

Hive 底层存储使用的是 HDFS ，计算使用的是资源调度 Yarn ，Hive 仅仅是将 HDFS 上存储的文件数据映射一张表，将这些存储和映射信息放入元数据管理系统，用户操作数据仓库的时候是先查询元数据管理系统，拿到如数据存储位置和存储方式数据压缩方式等元数据后，再将 SQL 转化为 MapReduce 程序运行，完成后返回给用户。既然如此可供优化的场景就有 HDFS 数据存储层，Yarn 数据计算层以及数据仓库元数据管理以及执行查询操作作业转化流程

## Hive 表设计优化

谈表设计优化主要是谈分区表、分桶表以及索引（ Hive3 已经弃用）的优化，通过建立分区表和分桶表提升数据查询效率。

### 分区表的设计使用

分区表比较容易理解，假设你的数据有一个字段是省份，用来区分数据所属省份，那么就可以将它当做分区列，Hive 就会按省份这一列将数据分为每个省份一个目录，将数据存入其中，这样做的好处是我们在后续查询数据使用省份字段筛选的时候就不用扫描包含所有省份的全部数据，只需要扫描 where 后指定省份对应的文件。减少全表扫描，对数据进行分区裁剪。

```sql
-- 设置支持动态分区以及非严格模式-严格模式分区表中必须至少有一个静态分区
set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nonstrict;

create table if not exists usa_covid_orignal(
    count_date string,
    country string,
    state string,
    fips int,
    cases int,
    deaths int
) comment '美国新冠疫苗初始表'
row format delimited fields terminated by ','
location '/warehouse/test/dql/usa_covid_orignal';
-- 普通表导入数据后查看执行计划
explain extended select * from usa_covid_orignal where state='Guam' or state='New Mexico';
```

<div align=center><img src="image-20210727145515100.png"></div>

注意看扫描的是整张表，将条件放到了筛选操作中。

```sql
-- 创建分区表
create table if not exists usa_covid(
    country string,
    fips int,
    cases int,
    deaths int
) comment '美国新冠疫苗动态分区表'
partitioned by(count_date string, state string)
row format delimited fields terminated by ','
location '/warehouse/test/dql/usa_covid';
-- 使用表中已有字段作为分区字段就是动态分区，这里会将select后最后两个字段作为分区字段
insert into table usa_covid partition(count_date, state)
select country, fips, cases, deaths, count_date, state from usa_covid_orignal;
show partitions usa_covid;  -- 查看表中所有的分区，若分区太多谨慎使用

explain extended select * from usa_covid where state='Guam' or state='New Mexico';
```

我分开放了两张图，因为我选了两个条件，所以它扫描了两个分区，使用上述语句查看详细语法树中有扫描文件地址。

<div align=center><img src="image-20210727150305971.png"></div>

<div align=center><img src="image-20210727150356657.png"></div>

常见的分区表是以时间分区，每年每个月的数据放到一个分区，在对时间做筛选的时候就可以减少扫描数据，所以以哪个字段分区取决于查询的时候以哪个字段筛选。分区字段分为静态分区和动态分区，静态分区是在插入数据的时候我可以指定我所要插入的数据是属于哪个分区的，例如`province='beijing'`，动态分区则是根据已有的某个字段对数据进行分区。需要注意的是分区字段是不在底层文件中存储的，虽然`select *`它会显示出来。关于分区表的存储可以查看元数据中存储的 PARTITIONS 相关表以及 SDS 表。

### 分桶表的设计使用

关于分桶表刚开始我认为它和分区表没什么区别，但实际上不管是建表方式还是计算方式以及优化目的都不相同。分区表是指定分区或者动态分区来区分属于哪个区，存入对应的目录，而分桶表是将数据按某个字段的 hash 值分到对应的桶并存入不同的文件；分区表优化的方向是按字段筛选查询，分桶表优化的是多表之间的join操作。

假设两张需要 join 的表，它们用来 join 的字段都是分桶字段（分桶的数量最好相同，确保同一个数据落在相同的桶中），在 join 操作时 Hive 就会对两个字段中同一个桶中的数据进行 join 操作，目的是减少两表join操作不必要的笛卡尔积数量。当然分桶表在数据抽样中也有应用，但实际用的较少。

```sql
-- 分别有四张表bucket_emp01和bucket_emp02数据相同，bucket_emp02按deptno分桶；
-- bucket_dept01和bucket_dept02数据相同，bucket_dept02按deptno分桶，语句太多就不贴了

-- 开启分桶SMB(Sort-Merge-Bucket) join
set hive.optimize.bucketmapjoin=true;
set hive.auto.convert.sortmerge.join=true;
set hive.optimize.bucketmapjoin.sortedmerge=true;

-- 分别查看两个未分桶表和分桶表的join执行计划
explain extended select * from bucket_emp01 e join bucket_dept01 d on e.deptno = d.deptno;
explain extended select * from bucket_emp02 e join bucket_dept02 d on e.deptno = d.deptno;
```

<div align=center><img src="image-20210727173900380.png"></div>

可以看到需要在 reduce 计算进行 join 操作，而且就算普通的 inner join ，届时会对两张表进行常规 join 操作。

<div align=center><img src="image-20210727175040539.png"></div>

而对两个分桶的表进行 join 则可以看到利用分桶对 map 操作进行优化，使用的是 SMB join 操作，而且没有 reduce 操作。

## Hive 表数据存储优化

Hive 的数据存储在 Hadoop 的 HDFS 上，所以数据的读写 操作都是针对 HDFS 的。对 HDFS 存储优化也是对 Hive 查询效率的提升。这里涉及的优化主要是数据的存储、传输、压缩的优化，优缺点也有优点，关键在于使用合适的优化方法。

### 文件存储格式（TEXT、ORC、Parquet）

#### TextFile

Hive数据默认的存储格式是 TextFile ，就是平时看到的以分隔符分隔的文本文件，建表时不指定`stored as`操作符数据则默认以 TextFile 存储在 HDFS 上。同时我们使用`load data`的时候是将数据直接搬到Hive表指定的路径下，不会对数据做任何处理。

- TextFile 的优点是按行存储，操作理解导入方便，可使用任意分隔符分割数据，直接在 HDFS 使用命令查看数据，并且可以搭配压缩一起使用；
- 缺点是耗费存储空间，I/O 性能较低，结合压缩时不能进行文件切分合并，不能进行并行操作，按行存储导致读取列时效率低下。适用于小量数据的查询，在 ODS 层一般使用这种存储方式。

#### SequenceFile

SequenceFile 是 Hadoop 中用来存储序列化即二进制的一种文件格式，可以作为 Map 和 Reduce 端的输入和输出，Hive 也支持这种数据格式。

- 它的优点是以二进制 kv 键值对形式存储数据，与底层交互更加友好，性能更快，可压缩和分隔，优化磁盘利用率和 I/O，可并行操作数据，查询效率更快；
- 缺点是存储时消耗的空间较大，与非 Hadoop 生态系统之外的工具兼容性较差，构建 SequenceFile 需要通过 TextFile 文件转化而来。适用于小量数据查询并且查询列比较多的情况。

#### Parquet

Parquet 是一种支持嵌套结构的列式存储文件格式，作为 OLAP 查询的优化方案，已被多种查询引擎支持，通过数据编码和压缩，以及映射下推和谓词下推，它的性能比大多数文件格式都要更好。

- 它的优点是采用列式存储，具有更高效的压缩和编码，可编码可分割，优化磁盘利用率和 I/O，可用于多种数据处理框架；
- 缺点是不支持 update、delete、insert 等 ACID 操作。适用于字段数量非常多，只查询无更新的数据操作。

#### ORC

ORC 文件格式也是 Hadoop 生态圈的列式存储格式，最初产生自 Hive，用来降低存储空间提高查询效率，后被分离出来成为独立的 Apache 项目。目前被 Hive、Spark SQL、Presto 等查询引擎支持。

- 它的优点是列式存储，存储效率非常高，可压缩，查询效率也较高，支持索引和矢量化查询；
- 缺点是加载时消耗资源较大，读取全量数据时性能较差，并且需要通过 TextFile 转化而来。适用于 Hive 中大型数据的存储和查询，只要系统资源配置高，对数据的存储和查询效率将会是一个很大的提升。

```sql
create table if not exists tmp_orc
    like bucket_dept01
    stored as orc
    location '/warehouse/test/tmp_orc';
insert into table tmp_orc select * from bucket_dept01;
```

### 数据压缩设置（ORC、Snappy）

Hive 底层运行 MapReduce 程序时，磁盘 I/O 操作、网络数据传输、shuffle 和 merge 都会花费大量时间，为了使资源最大化合理利用，数据压缩就显得十分有必要。Hive 压缩实际上就是 MapReduce 压缩。

<div align=center><img src="u=1113059533,2007703106.png"></div>

压缩是优点是减少文件存储所占空间，加快文件传输效率，降低磁盘 I/O 次数；压缩的缺点是使用数据时要先对数据进行解压，加重 CPU 负载，压缩算法越复杂，解压时间就越长。下面是几种常用的压缩算法。

<div align=center><img src="image-20210728110759174.png"></div>

使用压缩需要开启以及指定几项参数，开启后新建表指定使用 orc 存储文件以及 snappy 压缩算法。

```sql
-- 开启hive中间传输数据压缩功能
set hive.exec.compress.intermediate=true;
-- 开启mapreduce中map输出压缩功能
set mapreduce.map.output.compress=true;
-- 设置mapreduce中map输出数据的压缩方式
set mapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.SnappyCodec;

-- 开启Reduce输出阶段压缩
-- 开启hive最终输出数据压缩功能
set hive.exec.compress.output=true;
-- 开启mapreduce最终输出数据压缩
set mapreduce.output.fileoutputformat.compress=true;
-- 设置mapreduce最终数据输出压缩方式
set mapreduce.output.fileoutputformat.compress.codec = org.apache.hadoop.io.compress.SnappyCodec;
-- 设置mapreduce最终数据输出压缩为块压缩
set mapreduce.output.fileoutputformat.compress.type=BLOCK;

create table if not exists tmp_orc_snappy
    like tmp_orc
    stored as orc
    location '/warehouse/test/tmp_orc_snappy'
    tblproperties ("orc.compress"="SNAPPY");
insert into table tmp_orc_snappy select * from tmp_orc;
```

### 小文件场景

HDFS 并不利于小文件存储，因为一个小文件就会产生一条元数据信息，这对 NameNode 以及 Hive 元数据管理都会造成很大的负荷，而且一个小文件也会启动一个 MapTask 计算处理，导致资源的浪费，所以在使用 Hive 处理分析时，应尽量避免小文件的生成。Hive 提供了一个特殊的机制，可以自动判断是否为小文件，如果是则自动将小文件合并。

```sql
-- 如果hive的程序，只有maptask，将MapTask产生的所有小文件进行合并
set hive.merge.mapfiles=true;
-- 如果hive的程序，有Map和ReduceTask,将ReduceTask产生的所有小文件进行合并
set hive.merge.mapredfiles=true;
-- 每一个合并的文件的大小（244M）
set hive.merge.size.per.task=256000000;
-- 平均每个文件的大小，如果小于这个值就会进行合并(15M)
set hive.merge.smallfiles.avgsize=16000000;
```

若是遇到需要处理的数据小文件过多，Hive 也提供了一种输入类，它支持合并小文件之后再做数据处理，也就是跨文件读取。

```sql
-- 设置Hive中底层MapReduce读取数据的输入类：将所有文件合并为一个大文件作为输入
set hive.input.format=org.apache.hadoop.hive.ql.io.CombineHiveInputFormat;
```

<div align=center><img src="image-20210728114831871.png"></div>

### ORC 索引、ORC 矢量化

#### ORC 索引

在使用 ORC 格式的文件时，为了加快读取文件内容，ORC 支持了两种索引机制：`Row Group Index`和`Bloom Filter Index`可以帮助用户提高查询 ORC 文件的性能。当用户写入数据时可以指定构建索引，当用户查询数据时，可以根据索引提前对数据进行过滤，避免不必要的扫描。

**Row Group Index**

- 一个 ORC 文件包含一个或多个 **stripes(groups of row data)**，每个 stripe 中包含了每个 column 的 **min/max** 值的索引数据；
- 当查询中有大于等于小于的操作时，会**根据 min/max 值，跳过扫描不包含的 stripes**。
- 而其中为每个 stripe 建立的包含 min/max 值的索引，就称为 Row Group Index 行组索引，也叫 min-max Index 大小对比索引，或者 Storage Index 。

<div align=center><img src="image-20210728135739336.png"></div>

- 建立 ORC 格式表时，指定表参数`"orc.create.index"="true"`之后，便会建立 Row Group Index ；
- 为了使 Row Group Index 有效利用，向表中加载数据时，**必须对需要使用索引的字段进行排序**。

```sql
create table if not exists tmp_orc_index
    stored as orc
    location '/warehouse/test/tmp_orc_index'
    tblproperties ("orc.create.index"="true")
    as
    select * from tmp_orc
    distribute by deptno
    sort by deptno;
select * from tmp_orc_index where deptno between 10 and 20;
```

**Bloom Filter** **Index**

- 建表时候通过表参数`"orc.bloom.filter.columns"="columnName"`来指定为哪些字段建立 BloomFilter 索引，在生成数据的时候，会在每个 stripe 中，为该字段（或多字段）建立 BloomFilter 的数据结构；
- 当查询条件中包含对该字段的等值过滤时候，先从 BloomFilter 中获取以下是否包含该值，如果不包含，则跳过该 stripe ，如果包含则可能存在，进一步扫描该 stripe 。

```sql
create table if not exists tmp_orc_bloom_index
    stored as orc
    location '/warehouse/test/tmp_orc_bloom_index'
    tblproperties ("orc.create.index"="true", "orc.bloom.filter.columns"="deptno,deptno")
    as
    select * from tmp_orc
    distribute by deptno
    sort by deptno;
select count(deptno) from tmp_orc_bloom_index where deptno between 10 and 20;
```

#### ORC 矢量化查询

Hive 的默认查询执行引擎一次处理一行，而矢量化查询执行是一种 Hive 针对 ORC 文件操作的特性，目的是按照每批1024行读取数据，并且一次性对整个记录整合（而不是对单条记录）应用操作，提升了像过滤, 联合, 聚合等等操作的性能。要使用矢量化查询执行，就必须以 ORC 格式存储数据。

```sql
-- 开启矢量化查询
set hive.vectorized.execution.enabled = true;
set hive.vectorized.execution.reduce.enabled = true;
```

## Job 执行作业优化

### Explain 执行计划

- HQL是一种类 SQL 的语言，从编程语言规范来说是一种声明式语言，用户会根据查询需求提交声明式的 HQL 查询，而 Hive 会根据底层计算引擎将其转化成`Mapreduce/Tez/Spark`的job；
- explain 命令可以帮助用户了解一条 HQL 语句在底层的实现过程。通俗来说就是 Hive 打算如何去做这件事。
- explain 会解析 HQL 语句，将整个 HQL 语句的实现步骤、依赖关系、实现过程都会进行解析返回，可以了解一条 HQL 语句在底层是如何实现数据的查询及处理的过程，辅助用户对 Hive 进行优化。

```sql
EXPLAIN [FORMATTED|EXTENDED|DEPENDENCY|AUTHORIZATION|] query
-- FORMATTED：对执行计划进行格式化，返回JSON格式的执行计划
-- EXTENDED：提供一些额外的信息，比如文件的路径信息
-- DEPENDENCY：以JSON格式返回查询所依赖的表和分区的列表 
-- AUTHORIZATION：列出需要被授权的条目，包括输入与输出
```

### MapReduce 属性优化

#### 本地模式

使用Hive的过程中，对于数据量不大的表计算它也会提交给 YARN ，申请分配资源，这对于集群来说增加了不必要的开销，而且执行效率也会更慢。Hive 沿用了 MapReduce 的设计，提供本地计算模式，允许程序不提交给 YARN ，直接在本地计算并返回结果，以便提高小数据量程序的性能。

```sql
-- 开启本地模式，自动判断是否在本地运行
set hive.exec.mode.local.auto = true;
```

<div align=center><img src="image-20210729101144410.png"></div>

这项配置默认是关闭的，开启后 Hive 会根据几个阈值判断是否需要使用本地模式，分别是整体输入的数据量小于 128M，所有 Map-Task 的个数少于 4 个，Reduce-Task 的个数等于 1 或者 0，只有满足这几项条件 Hive 才会在本地执行，否则就提交给 YARN 集群执行。

#### JVM 重用（Hadoop3 已弃用）

- Hadoop 默认会为每个 Task 启动一个 JVM 来运行，而在 JVM 启动时内存开销大；
- Job 数据量大的情况，如果单个 Task 数据量比较小，也会申请 JVM ，这就导致了资源紧张及浪费的情况；
- JVM 重用可以使得 JVM 实例在同一个 job 中重新使用 N 次，当一个 Task 运行结束以后，JVM 不会进行释放，而是继续供下一个 Task 运行，直到运行了 N 个 Task 以后，就会释放；
- N 的值可以在 Hadoop 的 mapred-site.xml 文件中进行配置，通常在 10-20 之间。

```sql
-- Hadoop3之前的配置，在mapred-site.xml中添加以下参数
-- Hadoop3中已不再支持该选项
mapreduce.job.jvm.numtasks=10 
```

#### 并行执行

Hive 在执行程序时，会生成多个 Stage（explain 查看），有些 Stage 之间存在依赖关系，只能串行执行，但有些 Stage 之间没有关联关系，彼此之间的执行互不影响，例如 union、join 语句等。这时就可以开启并行执行，当多个 Stage 之间没有关联关系时，允许多个 Stage 并行执行，提高性能。

```sql
-- 开启Stage并行化，默认为false
SET hive.exec.parallel=true;
-- 指定并行化线程数，默认为8
SET hive.exec.parallel.thread.number=16;
```

### Join优化

Hive 针对 Join 操作的优化分为 Map 端 Join 、Reduce 端 Join 以及 Bucket Join ，针对不同的数据量以及环境选用不同的优化方法。

#### Map 端 Join

适用于小表 Join 大表或者小表 Join 小表。原理是将小表的那份数据给每个 MapTask 的内存都放一份（ Distribute Cache ），这样大表的每个部分都可以与小表进行 Join 操作，底层不需要 Shuffle 阶段，但需要耗费内存空间存储小表数据。Hive中尽量适用 Map 端 Join 来实现 Join 过程，默认开启了 Map 端 Join ，而对于小表的大小定义则有指定的参数控制。

```sql
-- 开启Map端Join
set hive.auto.convert.join=true;
-- Hive2.0版本之前的控制属性
set hive.mapjoin.smalltable.filesize=25M;
-- Hiv2.0版本之后的参数控制
set hive.auto.convert.join.noconditionaltask.size=512000000;
```

#### Reduce 端 Join

那么对于大表 Join 大表的情况下 Map 端 Join 就不在适用了，将大表放在每个 MapTask 的内存中无论是存储还是传输都会使效率降低。这是就会启用 Reduce 端 Join，原理是将两张表的数据在 Shuffle 阶段的分组来将数据按照关联字段进行 Join，必须经过 Shuffle。Hive 会自动判断是否满足 Map 端 Join，如不满足则自动使用 Reduce 端 Join。

#### Bucket Join

关于 Bucket Join 在最前面分桶表的设计使用那一节就讲的很清楚了，它的目的就是加快表与表之间 Join 的效率。那么关于分桶表的新建和原理就不多说了，这里再细说一下普通的 Bucket Join 和 SMB。

一般情况下按照 Join 字段为分桶字段新建两个分桶表，开启 bucketmapjoin 优化参数即可，但是还有效率更高的 SMB，它是先将字段排序再分桶，这样确保每个桶中的数据都是有序的，在 Join 时效率会更高，同时它也需要开启多个属性参数。

```sql
-- 普通Bucket Join
set hive.optimize.bucketmapjoin = true;

-- SMB（Sort Merge Bucket Join）
set hive.optimize.bucketmapjoin = true;
set hive.auto.convert.sortmerge.join=true;
set hive.optimize.bucketmapjoin.sortedmerge = true;
set hive.auto.convert.sortmerge.join.noconditionaltask=true;
```

需要注意的是 Join 时最好使用分桶字段，否则将不会有任何效率提升，在建表和导入数据的时候还会产生额外的资源开销。

### 关联优化

当一个程序中如果有一些操作彼此之间有关联性，是可以在一个 MapReduce 中实现的，但是 Hive 会不智能的选择，Hive 会使用两个 MapReduce 来完成这两个操作。

例如：当我们执行`select …… from table group by id order by id desc`。该 SQL 语句转换为 MapReduce 时，我们可以有两种方案来实现：

**方案一**

- 第一个 MapReduce 做 group by，经过 shuffle 阶段对 id 做分组；
- 第二个 MapReduce 对第一个 MapReduce 的结果做 order by，经过 shuffle 阶段对 id 进行排序。

**方案二**

- 因为都是对 id 处理，可以使用一个 MapReduce 的 shuffle 既可以做分组也可以排序。

在这种场景下，Hive 会默认选择用第一种方案来实现，这样会导致性能相对较差；可以在 Hive 中开启关联优化，对有关联关系的操作进行解析时，可以尽量放在同一个 MapReduce 中实现，这项配置在 Hive3 默认开启。

```sql
set hive.optimize.correlation=true;
```

### 优化器引擎

Hive 默认的优化器在解析一些聚合统计类的处理时，底层解析的方案有时候不是最佳的方案。例如当前有一张表【共 1000 条数据】，id构建了索引，id =100 值有 900 条。需求：查询所有 id = 100 的数据，SQL 语句为：`select * from table where id = 100`;

**方案一**：由于 id 这一列构建了索引，索引默认的优化器引擎 RBO，会选择先从索引中查询 id = 100 的值所在的位置，再根据索引记录位置去读取对应的数据，但是这并不是最佳的执行方案。

**方案二**：有 id=100 的值有 900 条，占了总数据的 90%，这时候是没有必要检索索引以后再检索数据的，可以直接检索数据返回，这样的效率会更高，更节省资源，这种方式就是 CBO 优化器引擎会选择的方案。

#### **RBO**

`rule basic optimise`：基于规则的优化器，根据设定好的规则来对程序进行优化。

#### **CBO**

`cost basic optimise`：基于代价的优化器，根据不同场景所需要付出的代价来合适选择优化的方案。对数据的分布的信息（数值出现的次数，条数，分布）来综合判断用哪种处理的方案是最佳方案。

Hive 中支持 RBO 与 CBO 这两种引擎，默认使用的是 RBO 优化器引擎。很明显 CBO 引擎更加智能，所以在使用 Hive 时，我们可以配置底层的优化器引擎为 CBO 引擎。

```sql
set hive.cbo.enable=true;
set hive.compute.query.using.stats=true;
set hive.stats.fetch.column.stats=true;
```

#### Analyze 分析器

CBO 引擎是基于代价的优化引擎，那么 CBO 是如何确定每种方案的运行代价呢，这就用到了 Analyze 分析器。它用于提前运行一个 MapReduce 程序将表或者分区的信息构建一些元数据（表的信息、分区信息、列的信息），搭配 CBO 引擎一起使用。

```sql
-- 为表中的分区构建元数据信息
analyze table usa_covid partition (count_date,state) compute statistics;
-- 为字段构建元数据信息
analyze table students compute statistics for columns age;
-- 查看字段的详细元数据信息，包含最大最小值，非重复计数等数据
desc formatted students age;
```

### 谓词下推（PPD）

谓词：用来描述或判定客体性质、特征或者客体之间关系的词项。比如"3 大于 2"中"大于"是一个谓词。谓词下推 Predicate Pushdown（PPD）基本思想：将过滤表达式尽可能移动至靠近数据源的位置，以使真正执行时能直接跳过无关的数据。简单点说就是在不影响最终结果的情况下，尽量将过滤条件提前执行，而不是 join 或者其他计算完成后才进行条件筛选。

Hive 中谓词下推后，过滤条件会下推到 map 端，提前执行过滤，减少 map 到 reduce 的传输数据，提升整体性能。参数默认开启。

```sql
-- 开启谓词下推
set hive.optimize.ppd=true;

-- 举例说明-方式一就类似谓词下推的优化，先过滤再join
select a.id, a.value1, b.value2 from table1 a
join (select b.* from table2 b where b.ds>='20181201' and b.ds<'20190101') c
on (a.id=c.id)；

select a.id, a.value1, b.value2 from table1 a
join table2 b on a.id=b.id
where b.ds>='20181201' and b.ds<'20190101'；
```

下面给出了一张图，是常用的一些 join 操作，第一列显示语句是否采用了谓词下推优化。

<div align=center><img src="image-20210729115237472.png"></div>

举例说明一下，分别有两张表，现需要 join 操作，两表分别有 where 条件约束，那么就有以下结论：

- 对于 Join(Inner Join)、Full outer Join ，条件写在 on 后面，还是 where 后面，性能上面没有区别；
- 对于 Left outer Join ，右侧的表条件写在 on 后面、左侧的表条件写在 where 后面，性能上有提高；
- 对于 Right outer Join ，左侧的表条件写在 on 后面、右侧的表条件写在 where 后面，性能上有提高；
- 当条件分散在两个表时，谓词下推可按上述结论 2 和 3 自由组合。

<div align=center><img src="1627531125343.png"></div>

### 数据倾斜

分布式计算中最常见的，最容易遇到的问题就是数据倾斜；数据倾斜的现象是，当提交运行一个程序时，这个程序的大多数的 Task 都已经运行结束了，只有某一个 Task 一直在运行，迟迟不能结束，导致整体的进度卡在 99% 或者 100%，这时候就可以判定程序出现了数据倾斜的问题。

#### 数据分配

当程序中出现 group by 或者 count（distinct）等分组聚合的场景时，如果数据本身是倾斜的，根据 MapReduce 的 Hash 分区规则，肯定会出现数据倾斜的现象。根本原因是因为分区规则导致的，所以可以通过以下几种方案来解决 group by 导致的数据倾斜的问题。

**方案一：开启 Map 端聚合**

```sql
hive.map.aggr=true;
```

通过减少 shuffle 数据量和 Reducer 阶段的执行时间，避免每个 Task 数据差异过大导致数据倾斜。

**方案二：实现随机分区**

```sql
select * from table distribute by rand();
```

distribute by 用于指定底层按照哪个字段作为 Key 实现分区、分组等。通过 rank 函数随机值实现随机分区，避免数据倾斜。

**方案三：数据倾斜时自动负载均衡**

```sql
hive.groupby.skewindata=true;
```

开启该参数以后，当前程序会自动通过两个 MapReduce 来运行。

- 第一个 MapReduce 自动进行随机分布到 Reducer 中，每个 Reducer 做部分聚合操作，输出结果；
- 第二个 MapReduce 将上一步聚合的结果再按照业务（group by key）进行处理，保证相同的分布到一起，最终聚合得到结果。

#### Join 数据倾斜

Join 操作时，如果两张表比较大，无法实现 Map Join ，只能走 Reduce Join ，那么当关联字段中某一种值过多的时候依旧会导致数据倾斜的问题；面对 Join 产生的数据倾斜，核心的思想是尽量避免 Reduce Join 的产生，优先使用 Map Join 来实现；但往往很多的 Join 场景不满足 Map Join 的需求，那么可以以下几种方案来解决 Join 产生的数据倾斜问题：

**方案一：提前过滤，将大数据变成小数据，实现 Map Join**

```sql
-- 先过滤再join，避免两张大表先join再过滤
select a.id,a.value1,b.value2 from table1 a
join (select b.* from table2 b where b.ds>='20181201' and b.ds<'20190101') c
on (a.id=c.id)
```

**方案二：使用 Bucket Join**

如果使用方案一，过滤后的数据依旧是一张大表，那么最后的 Join 依旧是一个 Reduce Join 。这种场景下，可以将两张表的数据构建为分桶表，实现 Bucket Map Join  ，避免数据倾斜。

**方案三：使用 Skew Join**

Skew Join 是Hive 中一种专门为了避免数据倾斜而设计的特殊的 Join 过程。这种 Join 的原理是将 Map Join 和 Reduce Join 进行合并，如果某个值出现了数据倾斜，就会将产生数据倾斜的数据单独使用 Map Join 来实现；其他没有产生数据倾斜的数据由 Reduce Join 来实现，这样就避免了 Reduce Join 中产生数据倾斜的问题。最终将 Map Join 的结果和Reduce Join的结果进行 Union 合并。

<div align=center><img src="image-20210729142028259.png"></div>

使用 Skew Join 需要开启一些配置：

```sql
-- 开启运行过程中skewjoin
set hive.optimize.skewjoin=true;
-- 如果这个key的出现的次数超过这个范围
set hive.skewjoin.key=100000;
-- 在编译时判断是否会产生数据倾斜
set hive.optimize.skewjoin.compiletime=true;
-- 不合并，提升性能
set hive.optimize.union.remove=true;
-- 如果Hive的底层走的是MapReduce，必须开启这个属性，才能实现不合并
set mapreduce.input.fileinputformat.input.dir.recursive=true;
```

常用的需要掌握或者了解的优化操作就这么多，生产过程中完全可以按照表设计优化、存储优化、执行作业优化这三个方面根据实际环境进行操作，其中的底层原理还需要通过源码以及实践深入理解。当然这里面少了执行引擎的优化，这就不用多说了，一般 MapReduce 和 Spark 引擎用的比较多，若对实效性要求较高就选择 Spark ，若对实效性要求不高且数据量巨大再加上硬件条件较差就是用 MapReduce 空闲时间慢慢跑，在执行脚本中通过`set hive.execution.engine=mr/spark/tez`切换执行引擎，Tez 则是夹在两者之间不被常用。
