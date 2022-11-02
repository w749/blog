---
title: HDFS架构及基础命令
author: 汪寻
date: 2021-05-04
tags:
 - Hadoop
categories:
 - Software
---

HDFS (Hadoop Distribluted File System)是Apache Hadoop项目的一个子项目。 Hadoop非常适于存储大型数据(比如TB和PB)，其就是使用HDFS作为存储系统HDFS使用多台计算机存储文件，并且提供统一的访问接口，像是访问一个普通文件系统一样使用分布式文件系统。

<!-- more -->

### HDFS的应用场景

#### 适合的应用场景

*   适合的应用场景存储非常大的文件：这里非常大指的是几百M、G、或者TB级别，需要高吞吐量，对延时没有要求
*   采用流式的数据访问方式：即一次写入、多次读取，数据集经常从数据源生成或者拷贝一次,然后在其上做很多分析工作
*   运行于商业硬件上：Hadoop不需要特别贵的机器，可运行于普通廉价机器，节约成本
*   需要高容错性
*   为数据存储提供所需的扩展能力

#### 不适合的应用场景

*   低延时的数据访问对延时要求在毫秒级别的应用，不适合采用HDFS。HDFS是为高吞吐数据传输设计的，因此可能牺牲延时
*   大量小文件文件的元数据保存在NameNode的内存中，整个文件系统的文件数量会受限于NameNode的内存大小。经验而言，一个文件/目录/文件块一般占有150字节的元数据内存空间。如果有100万个文件,每个文件占用1个文件块，则需要大约300M的内存。因此十亿级别的文件数量在现有商用机器上难以支持。
*   多方读写，需要任意的文件修改HDFS采用追加(append-only)的方式写入数据、不支持文件任意offset的修改。不支持多个写入器(writer)

### HDFS的架构

HDFS是一个主从（master/slave）体系结构

HDFS主要由四部分构成，分别是：HDFS Client、Name node、Secondary Name node和Data node

![](https://wangxukun.top/wp-content/uploads/2021/05/hdfs-Architecture.jpg)

#### Client

*   文件切分。文件上传HDFS的时候，Client将文件切分成一个一个的Block，然后进行存储
*   与NameNode交互，获取文件的位置信息
*   与DataNode交互，读取或者写入数据
*   Client提供一些命令来管理和访问HDFS，比如启动或者关闭HDFS，读写文件等

#### NameNode

*   管理HDFS的名称空间
*   管理数据块(Block)映射信息
*   配置副本策略
*   处理客户端读写请求

#### DataNode

*   存储实际的数据块
*   执行数据块的读/写操作

#### Secondary NameNode

*   并非NameNode的热备。当NameNode挂掉的时候，它并不能马上替换NameNode并提供服务
*   辅助NameNode，分担其工作量
*   定期合并fsimage和fsedits，并推送给NameNode
*   在紧急情况下，可辅助恢复NameNode

#### NameNode和DataNode

**NameNode和DataNode**是HDFS中最重要的两个组件，对于各自的属性以及作用有以下理解

![](https://wangxukun.top/wp-content/uploads/2021/05/hdfs-NameNode-DataNode.jpg)

#### NameNode作用

*   NameNode在内存中保存着整个文件系统的名称空间和文件数据块的地址映射
*   整个HDFS可存储的文件数受限于NameNode的内存大小
*   NameNode元数据信息：文件名，文件目录结构，文件属性(生成时间，副本数，权限)，每个文件的块列表。以及列表中的块与块所在的DataNode之间的地址映射关系。在内存中加载文件系统中每个文件和每个数据块的引用关系(文件、block，datanode之间的映射信息)，数据会定期保存到本地磁盘(fslmage文件和edits文件)
*   NameNode文件操作：NameNode负责文件元数据的操作DataNode负责处理文件内容的读写请求，数据流不经过NameNode，会询问它跟那个DataNode联系
*   NameNode副本：文件数据块到底存放到哪些DataNode上，是由NameNode决定的，NameNode根据全局情况做出放置副本的决定
*   NameNode心跳机制：全权管理数据块的复制，周期性的接受心跳和块的状态报告信息(包含该DataNode上所有数据块的列表)若接受到心跳信息，NameNode认为DataNode工作正常，如果在10分钟后还接受到不到DN的心跳，那么NameNode认为DataNode已经宕机，这时候NN准备要把DN上的数据块进行重新复制。块的状态报告包含了一个DN上所有数据块的列表，blocks report每个1小时发送一次

#### DataNode作用

*   Data Node以数据块的形式奇储HDFS文件
*   Data Node响应HDFS客户端读写请求
*   Data Node周期性的向NameNode汇报心跳信息
*   Data Node周期性的向NameNode汇报数据块信息
*   Data Node周期性的向NameNode汇报缓存数据块信息（针对访问频率较高的数据块将它放在内存中，叫做块缓存）

### HDFS基础命令

```bash
 start-dfs.sh  # 启动HDFS集群
 stop-dfs.sh  # 关闭HDFS集群

 hdfs dfsadmin -report  # 报告HDFS使用情况
 hdfs dfs -count -q -h -v /  # 统计目录文件夹数量、文件数量、空间使用量

 hdfs dfs -df -h /  # 统计文件系统的可用空间信息
 hdfs dfs -ls /  # 查看/路径下的文件或者文件夹
 hdfs dfs -lsr /  # 递归查看/路径下的文件或者文件夹
 hdfs dfs -stat /a.txt  # 显示文件所占块数，文件名，块大小，复制数，修改时间等信息
 hdfs dfs -mkdir -p /a/b/c  # 递归创建文件夹
 hdfs dfs -moveFronLocal localpath hdfspath  # 从本地上传文件到hdfs中（本地文件会被删除）
 hdfs dfs -mv oldpath newpath  # 移动文件
 hdfs dfs -put localpath hdfspath  # 从本地上传文件到hdfs中（文件还在本地）
 hdfs dfs -appendToFile a.txt b.txt /c.txt  # 追加本地文件a、b到hdfs文件c中
 hdfs dfs -touchz /empty.txt  # 创建一个空文件
 hdfs dfs -cat /c.txt  # 打印文件到shell
 hdfs dfs -cp oldpath newpath  # 拷贝文件
 hdfs dfs -rm path  # 删除文件夹或者文件（如需递归加参数r）
 hdfs dfs -chmod -R 777 filepath  # 更改文件访问权限
 hdfs dfs -chown -R elk:elk filepath  # 更改文件用户组和用户
```

