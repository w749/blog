---
title: SQL OVER窗口函数
author: 汪寻
date: 2021-06-04 12:16:41
updated: 2021-06-04 12:58:37
tags:
 - SQL
 - Hive
categories:
 - Language
---

这里的窗口函数在 SQL 、Hive 和 Spark SQL 中的用法差不多都是一样的。

<!-- more -->

窗口函数在我的理解下首先是解决 OLAP 系统的复杂分类问题，它可以定制不同规模的窗口让聚合函数在窗口内执行并返回结果到当前行，理解窗口函数脑中需要有一张表，模拟函数在计算时数据的来源，也就是窗口的定义和界限，在最新的 SQL 中支持 over 窗口函数，我们一般所说的窗口函数也就是 over 函数。

over 开窗函数可以配合 sum，avg，count，max，min 等聚合函数，也可以配合 rank，dense_rank和row_number 等专用开窗函数。当 over 函数中未使用 partition 和 order 时，它的窗口就是所有数据，只使用 partition 则窗口为每个分组，聚合的是每个分组内的数据，只使用 order 则窗口为所有数据，计算的是从起始行到当前行的数据聚合结果。准备数据如下：

```sql
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for student
-- ----------------------------
DROP TABLE IF EXISTS `student`;
CREATE TABLE `student` (
  `name` varchar(255) NOT NULL,
  `class` varchar(255) DEFAULT NULL,
  `score` int(255) DEFAULT NULL,
  `subject` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of student
-- ----------------------------
BEGIN;
INSERT INTO `student` VALUES ('a', '2', 94, '英语');
INSERT INTO `student` VALUES ('b', '4', 99, '英语');
INSERT INTO `student` VALUES ('c', '4', 90, '政治');
INSERT INTO `student` VALUES ('d', '3', 99, '数学');
INSERT INTO `student` VALUES ('e', '1', 88, '语文');
INSERT INTO `student` VALUES ('f', '3', 78, '英语');
INSERT INTO `student` VALUES ('g', '1', 89, '政治');
INSERT INTO `student` VALUES ('n', '4', 99, '数学');
INSERT INTO `student` VALUES ('q', '1', 95, '数学');
INSERT INTO `student` VALUES ('r', '2', 98, '语文');
INSERT INTO `student` VALUES ('s', '3', 90, '语文');
INSERT INTO `student` VALUES ('t', '2', 79, '数学');
INSERT INTO `student` VALUES ('v', '4', 88, '语文');
INSERT INTO `student` VALUES ('w', '1', 80, '英语');
INSERT INTO `student` VALUES ('x', '3', 67, '政治');
INSERT INTO `student` VALUES ('z', '2', 89, '政治');
COMMIT;

SET FOREIGN_KEY_CHECKS = 1;
```

开窗函数主要是结合`over(partition by ... order by ...)`的句式，配合其他函数计算一个组内或者窗口内的数据，这其中可以不断组合以满足业务需求，而且还可以配合window子句已完成更复杂的滑动窗口。

```sql
-- over窗口函数就是给数据一个计算窗口，当不指定partition和order的时候，默认窗口就是所有记录
select
    name,class,subject,score,
    avg(score) over() scoreSum,
    max(score) over() scoreMax
from student;

/* 数据太多没复制完
a    2    英语    94    1422    99
b    4    英语    99    1422    99
c    4    政治    90    1422    99
d    3    数学    99    1422    99
e    1    语文    88    1422    99
f    3    英语    78    1422    99
g    1    政治    89    1422    99
*/

-- 输出按科目分组，score降序排序，每个学生的名次（输出结果第四列即为名次）
-- 如需名次之间连续，例如1223这样则将rank替换为dense_rank
select
    name,class,subject,score,
    rank() over(partition by subject order by score desc) scoreRank
from student;

/* 
c    4    政治    90    1
g    1    政治    89    2
z    2    政治    89    2
x    3    政治    67    4
d    3    数学    99    1
n    4    数学    99    1
q    1    数学    95    3
t    2    数学    79    4 
*/

-- 输出按科目分组，score降序排序，每个学生的连续名次、累加score以及每个科目的最大score（多个组合窗口函数）
select
    name,class,subject,score,
    dense_rank() over(partition by subject order by score desc) scoreRank, 
    sum(score) over(partition by subject order by score desc) scoreSum,
    max(score) over(partition by subject order by score desc) scoreMax
from student;

/*
c    4    政治    90    1    90    90
g    1    政治    89    2    268    90
z    2    政治    89    2    268    90
x    3    政治    67    3    335    90
d    3    数学    99    1    198    99
n    4    数学    99    1    198    99
q    1    数学    95    2    293    99
t    2    数学    79    3    372    99
*/

-- 不分组仅按score降序排序输出累加score（不使用partition，注意score相等的score和并不是你想的那样）
select
    name,class,subject,score,
    sum(score) over(order by score desc) scoreSum,
    max(score) over(order by score desc) scoreMax
from student;

/*
b    4    英语    99    297    99
d    3    数学    99    297    99
n    4    数学    99    297    99
r    2    语文    98    395    99
q    1    数学    95    490    99
a    2    英语    94    584    99
c    4    政治    90    764    99
s    3    语文    90    764    99
*/

/*
下面引入window子句，preceding（往前）、following（往后）、current row（当前行）、unbounded preceding（从起点开始）、unbounded following（截止到最后一行）
*/
-- 计算按班级排序当前score以及前面两个score的平均值和最大值（这里会用到滑动窗口）
-- 引入新的关键字rows和preceding，表示截止到当前两行，就是选择最近三行的
select
    name,class,subject,score,
    avg(score) over(order by class rows 2 preceding) scoreSum,
    max(score) over(order by class rows 2 preceding) scoreMax
from student;

/*
e    1    语文    88    88.0000    88
g    1    政治    89    88.5000    89
q    1    数学    95    90.6667    95
w    1    英语    80    88.0000    95
a    2    英语    94    89.6667    95
r    2    语文    98    90.6667    98
t    2    数学    79    90.3333    98
z    2    政治    89    88.6667    98
*/

-- 下面把经常遇到的场景列举一遍，因为数据太少只用了order，一般实际场景使用partition结合order情况比较多
select
    name,class,subject,score, 
    sum(score) over() sumAll,  -- 所有数score的和
    sum(score) over(partition by class) sumAsClass,  -- 按class分组组内score的和
    sum(score) over(order by score desc) sumAsScore,  -- 按score降序排序累加的和
    sum(score) over(partition by class order by score desc) sumAsClassScore,  -- 按class分组，score降序排序累加的和
    sum(score) over(order by score desc rows 2 preceding) sumAsPreceding,  -- 按score排序往前两条记录到当前共三条记录的和
    sum(score) over(order by score desc rows between 2 preceding and current row) sumPrecedingCurrent,  -- 和上一条表达意思相同
    sum(score) over(order by score desc rows between 1 preceding and 1 following) sumPrecedingFollowing,  -- 按score排序往前一条往后一条加上当前共三条记录的和
    sum(score) over(order by score desc rows between current row and unbounded following) sumUnboundPreFoll  -- 按score排序当前记录到结尾记录的和
from student
order by score desc;

/*
name    class    subject    score    sumAll    sumAsClass    sumAsScore    sumAsClassScore    sumAsPreceding    sumPrecedingCurrent    sumPrecedingFollowing    sumUnboundPreFoll
d    3    数学    99    1422    334    297    99    99    99    198    1422
b    4    英语    99    1422    376    297    198    198    198    297    1323
n    4    数学    99    1422    376    297    198    297    297    296    1224
r    2    语文    98    1422    360    395    98    296    296    292    1125
q    1    数学    95    1422    352    490    95    292    292    287    1027
a    2    英语    94    1422    360    584    192    287    287    279    932
s    3    语文    90    1422    334    764    189    279    279    274    838
c    4    政治    90    1422    376    764    288    274    274    269    748
z    2    政治    89    1422    360    942    281    268    268    266    569
g    1    政治    89    1422    352    942    184    269    269    268    658
v    4    语文    88    1422    376    1118    376    265    265    256    392
e    1    语文    88    1422    352    1118    272    266    266    265    480
w    1    英语    80    1422    352    1198    352    256    256    247    304
t    2    数学    79    1422    360    1277    360    247    247    237    224
f    3    英语    78    1422    334    1355    267    237    237    224    145
x    3    政治    67    1422    334    1422    334    224    224    145    67
*/
```

需要注意的是因为排名、求和等函数是在窗口内逐行计算的，所以在 over 函数内降序排序和升序排序会返回不同的结果，务必根据场景选择排序方式；而且使用窗口函数计算出来的数值也可以放进 where 子句或者使用 order 再次排序。

除了常见的开窗场景还有常见的聚合场景也说一下

```sql
-- row_number在排名问题上比较常用，它返回当前记录的行号，不受记录重复造成的影响，eg：1234
-- rank跟row_number的不同之处是对于重复记录时使用相同排名，然后会跳过当前排名返回行号，eg：1224
-- dense_rank和rank不同的地方是遇到重复记录时使用相同排名，然后会接着上面的排名数字返回，eg：1223
select
    name,class,subject,score, 
    row_number() over(partition by subject order by score desc) rowNumber,
    rank() over(partition by subject order by score desc) `Rank`,
    dense_rank() over(partition by subject order by score desc) denseRank
from student;

/*
name    class    subject    score    rowNumber    Rank    denseRank
c    4    政治    90    1    1    1
g    1    政治    89    2    2    2
z    2    政治    89    3    2    2
x    3    政治    67    4    4    3
d    3    数学    99    1    1    1
n    4    数学    99    2    1    1
q    1    数学    95    3    3    2
t    2    数学    79    4    4    3
*/

-- lag和lead函数，在返回用户上一次购买时间的情况下特别好用，若没有写默认值则返回NULL
select
    name,class,subject,score, 
    lag(score,1) over(partition by class order by score desc) lagOne,
    lag(score,2, 0) over(partition by class order by score desc) lagTwo
from student;

/*
name    class    subject    score    lagOne    lagTwo
q    1    数学    95    NULL    0
g    1    政治    89    95    0
e    1    语文    88    89    95
w    1    英语    80    88    89
r    2    语文    98    NULL    0
a    2    英语    94    98    0
z    2    政治    89    94    98
t    2    数学    79    89    94
*/

-- first_value和last_value分别是返回截止到当前行的第一条记录和最后一条记录（最后一条记录即当前记录）
select
    name,class,subject,score, 
    first_value(score) over(partition by class order by score desc) firstValue,
    last_value(score) over(partition by class order by score desc) lastValue
from student;

/*
name    class    subject    score    firstValue    lastValue
q    1    数学    95    95    95
g    1    政治    89    95    89
e    1    语文    88    95    88
w    1    英语    80    95    80
r    2    语文    98    98    98
a    2    英语    94    98    94
z    2    政治    89    98    89
t    2    数学    79    98    79
*/
```

窗口函数在结果分类分组计算以及滚动聚合的情况下特别合适，赋予 SQL 极大地灵活性，适用于 OLAP 分析性数据库，而且在 Hive 中也支持窗口函数，所以掌握窗口函数是十分有必要的。
