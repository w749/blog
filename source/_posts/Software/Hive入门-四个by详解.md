---
title: Hive入门-四个by详解
author: 汪寻
date: 2021-10-25 18:17:14
update: 2021-10-25 18:39:17
tags:
 - Hive
categories:
 - Software

---

分别是 order by、distribute by、sort by 和 cluster by，它们都是排序相关的函数，输入和输出数据量是一样的，不要和 group by 搞混了。

<!-- more -->

### order by

order by 就是我们熟知的全局排序，在 hive 中使用它的后果就是会导致只有一个 reduce，数据量较大时会造成运算的压力

```sql
select * from test order by name desc;
```

### distribute by

distribute by 是先计算这个字段内数据的 hash 值，hash 值相同的分到一个 reduce 内，若是数据量较小或者指定一个 reduce 的时候就不用考虑这些了，都会分到一个 reduce 中，一般配合 sort by 使用

```sql
set mapreduce.job.reduces=5;
select * from test distribute by name;
```

### sort by

sort by 是局部排序，一般配合 distribute by 使用，将 hash 值相同的数据分到一个 reduce 内方便排序。它和 order by 不同的地方在于 order by 是全局排序，sort by 是局部排序，若只有一个 reduce 时它俩的结果相同，若有多个 reduce 时并且字段内所分区的数量原大于 reduce 个数就会导致多个分区的数据分到一个 reduce 内最终排序结果会出现问题，所以需要 sort by 分区的字段加排序的字段

```sql
set mapreduce.job.reduces=5;
select * from test distribute by name sort by age desc;
```

### cluster by

cluster by 是在 distribute by 和 sort by 的字段相同时使用，缺点是只能升序排序

```sql
set mapreduce.job.reduces=5;
select * from test cluster by name;
```

### 应用

若是数据量少，只有一个 reduce 的时候，那么 distribute by 后再 sort by 就相当于 group by 后再 order by，所有的数都被分到同一个 reduce 当中

```sql
select grade, points from class distribute by grade sort by points;
```

但若是数据量较大或者自定义 reduce 较多时，字段下不同的分区可能被分到同一个 reduce 当中，例如 grade 为高级和低级的被分到一个 reduce 当中，直接 sort by 时可能就会打乱 grade 的顺序，所以需要 sort by grade, points 才能得到想要的结果

```sql
set mapreduce.job.reduces=5;
select grade, points from class distribute by grade sort by grade, points;
```

随机抽样，使用 distribute by rand() 保证数据分配到 reduce 是随机的，并且使用 sort by rand() 保证 reduce 内的排序也是随机的，那么再加上 limit 就可以从数据源中随机的抽取指定数量的数据

```sql
select * from test distribute by rand() sort by rand() limit 100;
```
