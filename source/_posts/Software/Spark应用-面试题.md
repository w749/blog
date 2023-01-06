---
title: Spark应用-面试题
author: 汪寻
date: 2021-10-23 19:14:21
update: 2021-10-23 19:31:49
tags:
 - Spark
 - 面试题
categories:
 - Software
---

常见的 Spark 面试题，记录不只为面试，加深对底层环境的理解

<!-- more -->

### 基础

1. Spark 任务提交流程
2. Spark 的 Shuffle 及优化
3. Spark 的宽窄依赖以及 Stage 的划分
4. 如何将宽依赖转化为窄依赖
5. reduceByKey、groupByKey 有什么区别
6. DataFrame、RDD、DataSet 有什么区别
7. Spark 调优都会做什么
8. Spark 内存管理
9. spark-submit 常用提交参数
10. Spark 缓存时数据存在哪里
11. Spark 的几种部署模式和区别
12. Spark 运行的是 cluster 还是 client，有什么区别

### 优化

1. 数据倾斜怎么处理
2. mr 和 spark 的 shuffle 区别

### 实操

1. 使用累加器对 LIst(1, 2, 3, 4) 每个元素实现类加操作并输出结果
2. 写一个自定义函数，实现给所有字符串加一个前缀，分别实现增加相同前缀和自增前缀
3. 写一个 UDAF 函数，实现拼接 group by 后字段内的所有字符串（["a","b","c"] -> "a-b-c"）
4. 自定义 UDTF 函数