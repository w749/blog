---
title: Hive应用-面试题
author: 汪寻
date: 2021-10-23 12:17:36
updated: 2021-10-23 12:58:11
tags:
 - Hive
 - 面试题
categories:
 - Software
---

常见的 Hive 面试题，记录不只为面试，加深对底层环境的理解

<!-- more -->

### 基础

1. Hive SQL执行流程（详细）

   - Parser：Hive 使用 Antlr 进行语法和词法解析，解析的结果就是 AST 抽象语法树，会进行语法校验，使用`explain extented select * from test`查看详细的语法树

   - Analyzer：语法分析，这里会去元数据库关联查找相关的表和字段是否存在，然后生成 QB（query block），QB 就是一条 SQL 最基本的组成单元，包括输入源、计算过程、输出三个部分

   - Logical Plan：逻辑执行计划解析，由 QB 生成一堆 Operator Tree，基本的操作符包括TableScanOperator、SelectOperator、FilterOperator、JoinOperator、GroupByOperator、ReduceSinkOperator

   - Logical Optimizer：逻辑执行计划优化，对上一步的执行计划进行优化，还是返回 Operator Tree

   - Physical Paln：物理执行计划，生成 Task Tree

   - Physical Optimizer：物理执行计划优化，同样返回 Task Tree

   - 将优化后的 Task Tree 提交给 Map Reduce 或者其他引擎去执行

2. 简单介绍 SQL 执行映射 MR 流程

   - 首先是过滤类的语句，不带任何聚合和 join 操作，整个过程是没有 reduce 的，类似 ETL 操作，其中 map 的数量是由文件分片数量决定的，分区条件直接在数据读取的时候过滤

   - 分组聚合类查询，本质和 Word Count 执行差不多，combiner 是每个 Map 局部的 reduce，好处是减少 shuffle 数据量，但并不是所有的场景都会发生 combiner，例如求均值

3. 简单介绍一下 Hive 架构和原理以及特点

   - Hive 是基于 Hadoop 的一个数据仓库工具，可以将结构化的数据文件映射为一张表，并提供类 SQL 查询功能
   - Hive 的数据存储在 HDFS 上，或者说 Hive 的数据就是在 HDFS 上的映射，表就是文件，数据库就是文件夹，只不过底层是分布式存储的；计算引擎默认是 Map Reduce，Hive3.0 开始已经不推荐使用了；资源调度和程序的执行是放在 Yarn 上的
   - Hive 是优点是可存储数据量大，可扩展性强，数据安全性较高，结合元数据可对底层数据进行较好的存储和管理。缺点是只可增删查不可改，如需改只能查询修改后全部覆盖或者使用拉链表等其他手段；还有就是计算效率较慢，因为 Map Reduce 计算引擎会产生 Shuffle，多次落盘读盘会导致效率低下；还有一个缺点是不支持索引，如果不建分区表它会暴力扫描整个表；所以 Hive 的使用一定是建立在良好的优化方法之上的

4. 查看 hive 自带的函数以及详细使用方法

   ```sql
   -- 查看支持的函数
   show functions;
   show functions like 'unix*';
   -- 查看一个函数的详细使用方法
   desc function extended unix_timestamp;
   ```

5. 内部表和外部表的区别

   - 创建内部表时会把数据移动到指定的目录或者默认的目录下，删除的时候会把元数据以及数据全部删除且无法恢复；创建外部表时不会将数据移动到默认的目录下，只是记录数据所在位置，删除的时候只会删除元数据，数据不动
   - 创建内部表（默认就是内部表）：`create table test...`，可以不指定 location 数据存储位置；创建外部表：`create external table test...` location '...'，必须指定数据所在位置

6. 介绍一下分区表和分桶表的作用、原理以及构建语句

   - 分区表是通过将数据按指定字段分区存储的方法减少查询时数据的扫描量，减少不必要的数据扫描，底层是在表所在的 HDFS 目录下再建文件夹存入每个分区的数据
   - 分桶表则是为了提高大表 join 时的效率，通过对需要 join 的两张表中相同的字段进行分桶，将它们按数量指定分在不同的桶内，按照分桶字段的 hash 值取模除以分桶的个数确定数据存在哪个桶中，最好是排序分桶，这样可以保证两表相同的数据被分在同一个桶内，底层还是存储在不同的文件内。分桶表还有一个作用就是使取样更高效，开发时可以先取某一个桶的数据测试查询
   - 分区表字段在表中不存在，而分桶表在表中存在；分桶表只能通过查询的方式插入，不可以使用 load 直接导入，建表语句使用`...clustered by (state) sorted by (cases desc) into 5 buckets...`

7. 查看表结构、创建语句

   ```sql
   -- 查看表详细信息
   desc formatted test;
   -- 表的创建语句
   show create table test;
   ```

8. 表有哪些分区、对应的 hdfs 路径、分区数据量大小、分区文件总数

   ```sql
   -- 查看表的所有分区
   show partitions hero_all;
   -- 查看某一个分区的详细信息（在Detailed Partition Information中）
   desc extended hero_all partition(role='warrior');
   -- 去MySQL元数据库查看分区数量
   select count(1) `分区数量`
   from PARTITIONS
   where TBL_ID in (
       select TBL_ID from TBLS where TBL_NAME = 'students');
   -- 查看表或者某一个分区数据量大小
   hadoop fs -du -s -h /warehouse/test/uscovid/us_covid
   ```

9. hive 支持的基本数据类型

   | 数据类型   | 长度    | 说明                          | 示例                                |
   | ---------- | ------- | ----------------------------- | ----------------------------------- |
   | TINYINT    | 1byte   | -128 ~ 127                    | 100Y                                |
   | SMALLINT   | 2byte   | -32768 ~ 32767                | 100S                                |
   | INT        | 4byte   | -2^32~ 2^32-1                 | 100                                 |
   | BIGINT     | 8byte   | -2^64~ 2^64-1                 | 100L                                |
   | FLOAT      | 4byte   | 单精度浮点数                  | 5.21                                |
   | DOUBLE     | 8byte   | 双精度浮点数                  | 5.21                                |
   | DECIMAL    | -       | 高精度浮点数                  | DECIMAL(9,8)                        |
   | BOOLEAN    | -       | 布尔型                        | true/false                          |
   | BINARY     | -       | 字节数组                      | -                                   |
   | STRING     | -       | 常用字符串类型                | 'abc'                               |
   | VARCHAR    | 1-65535 | 可变字符串，需要指定长度      | 'abc'                               |
   | CHAR       | 1-255   | 不够长度的使用空格填充        | 'abc'                               |
   | DATE       | -       | yyyy-MM-dd                    | 2020-07-04                          |
   | TIMESTAMPS | -       | yyyy-MM-dd HH:mm:ss.fffffffff | 2020-07-04 12:36:25.111             |
   | STRUCT     | -       | 结构体                        | `struct<name:string,weight:double>` |
   | ARRAY      | -       | 相同数据类型的集合            | array<Int>                          |
   | MAP        | -       | 键值对的组合                  | map<string,string>                  |

10. 确定一个 hive sql 的 map 数量和 reduce 数量

    - map 数量通过 split 数量确定，split 数量等于文件大小 / split size，split size 默认是128M；reduce 数量不指定的情况下是 -1，是一个动态计算的值，也可以通过`set mapred.reduce.tasks=10;`手动设定

    - map 数量并不是越大越好，如果有很多小文件，每个小文件都被当作一个块，那么就会造成资源浪费，解决这个问题可以对小文件进行合并

      ```sql
      -- 每个map最大输入大小
      set mapred.max.split.size=100000000;
      -- 节点中可以处理的最小文件大小,100M
      set mapred.min.split.size.per.node=100000000;
      -- 机架中可以处理的最小的文件大小
      set mapred.min.split.size.per.rack=100000000;
      -- 表示执行map前对小文件进行合并
      set hive.input.format=org.apache.hadoop.hive.ql.io.CombineHiveInputFormat;
      ```

    - reduce 数量的确定，同 map 一样也不是越多越好，有多少 reduce 就会产生多少小文件，这些小文件作为下一个任务的输入就会造成资源的浪费，小文件合并后面再说

      ```sql
      -- 下面两个参数确定reduce的数量
      set hive.exec.reducers.bytes.per.reducer;  -- 每个reduce任务处理的数据量，默认256M
      set hive.exec.reducers.max;  -- 每个任务最大的reduce数量，默认1009
      -- 根据上面两个参数，reduce数量=min(1009, 总输入数据大小/256M)
      -- 如果需要减少reduce个数，可以调大每个reduce任务处理的数据量或者自行设定
      set mapred.reduce.tasks = 5;
      ```

11. Hive 命令常用参数

    - `hive`：进入 hive 交互式 shell
    - `hive --help`：查看 hive 命令都支持哪些参数
    - `hive --hiveconf a=b,c=d`...：传入变量，新版可以使用 --define 
    - `hive -i test.init...`：从文件初始化 hive，文件中存放 hive sql 初始化语句
    - `hive -e "use test;select * from test;"`：不进入交互式 shell 运行 sql 并返回结果
    - `hive -f ./test.sql`：不进入交互式 shell 运行一个 sql 文件

12. 解释 sql 运行步骤，以及如何优化

    ```sql
    select a.id, b.name from a left outer join b on a.id = b.id where a.dt = '2021-10-10' and b.dt = '2021-10-10'
    ```

    首先是看 on 和 where，它俩的区别是 on 是生成 left join 完成后的临时表用来过滤的条件，就算条件不满足也会返回左表的所有结果，而 where 则是在生成临时表后再对这个结果进行过滤，最终返回过滤后的结果

    根据这个特性可以将 where 条件前置，直接 join 两个筛选后的表，可以减少 join 的数据量

    ```sql
    select aa.id, bb.name 
    from (
        select id, name from a where dt = '2021-10-10') aa 
    left join (
        select id, name from b where dt = '2021-10-10') bb 
    on aa.id = bb.id
    ```

13. 下面的 sql 语句的区别

    ```sql
    select a.* from a left join b on a.key = b.key and a.ds = xxx and b.ds = xxx
    select a.* from a left join b on a.key = b.key and b.ds = xxx
    select a.* from a left join b on a.key = b.key and a.ds = xxx where b.ds = xxx
    select a.* from a left join b on a.key = b.key where a.ds = xxx and b.ds = xxx
    ```

    这个问题其实和上面那个问题差不多，主要是考察 on 和 where 的理解和使用，on 和 where 同时存在时 on 的优先级是高于 where 的，这样就表示如果要对连接后的结果再做聚合可以使用 on 连接两张表再 where 过滤掉不需要的记录，可以减少不必要的计算量。如果要在结果记录中保留某一张表的所有记录，则把连接条件和过滤条件全部放在 on 中，这样就保证了聚合时数据的完整性。

### 优化

1. a 表 left join b 表，b 表为小表，可以怎样优化

   - 这里考察的是 map join 的知识，我们一般理解的默认 join 操作是先进行 map 分组，再通过 shuffle 将相同 key 的值划分到同一个 reduce 中去 join。如果其中有一张表比较小的情况下不用采取这种操作，map join 的原理是将两张表中数据量较少的一张表复制到内存中，大表的每一个 map（split）都去和这个小表去 join，最后把结果拼接一下就可以了，这样减少了 shuffle 和 reduce 的操作
   - hive 0.7 版本以前还需手动使用`/*+ mapjoin(table) */`提示才会执行 map join，之后的版本由参数`hive.auto.convert.join`控制，默认为 true，无需手动开启，自动转为 map join 的条件是其中一张表的数据量大小，由`hive.mapjoin.smalltable.filesize`来决定，默认是25M，意思若其中有一张表小于25M则自动开启 map join
   - 其实 hive 现在也支持本地模式，若是两张表数据量都比较小，就会在本地执行任务，区分方式通过任务号中是否含有 local，通过`set mapreduce.framework.name=local;set hive.exec.mode.local.auto=true;`开启，`mapreduce.framework.name=local`会让所有任务都走本地

2. 两个大表连接，发生数据倾斜，有几个 reduce 无法完成，怎样定位发生数据倾斜的原因，怎样优化

3. 两个大表连接，发生数据倾斜，一个reduce无法完成，发现有一张表中 id = '' 的记录有很多，其他都是非重复，应该怎样优化

   - 首先如果其中一张表中 id 包含许多记录为空的情况下，若是后续计算不需要这部分数据，则可以在 join 之前就把这部分数据过滤掉，减少 shuffle 的时候产生的笛卡尔积数量，而且空记录在分配到一个 reduce 的时候也会对效率产生影响
   - 第二种情况就是在需要保留这些记录的时候，就可以对这些数据打散处理，避免被分到一个 reduce 当中。方法是在 join 之前使用 case 判断若为空的时候分配给一个随机值，这样就会被分到不同的 reduce 当中，提高处理效率

4. sort by、distribute by、cluster by 和 order by 的区别

   - 首先它们都是排序相关的函数，输入和输出数据量是一样的，不要和 group by 搞混了。order by 就是我们熟知的全局排序，在 hive 中使用它的后果就是会导致只有一个 reduce，数据量较大时会造成运算的压力
   - distribute by 是先计算这个字段内数据的 hash 值，hash 值相同的分到一个 reduce 内，若是数据量较小或者指定一个 reduce 的时候就不用考虑这些了，都会分到一个 reduce 中，一般配合 sort by 使用
   - sort by 是局部排序，一般配合 distribute by 使用，将 hash 值相同的数据分到一个 reduce 内方便排序。它和 order by 不同的地方在于 order by 是全局排序，sort by 是局部排序，若只有一个 reduce 时它俩的结果相同，若有多个 reduce 时并且字段内所分区的数量原大于 reduce 个数就会导致多个分区的数据分到一个 reduce 内最终排序结果会出现问题，所以需要 sort by 分区的字段加排序的字段
   - cluster by 是在 distribute by 和 sort by 的字段相同时使用，缺点是只能升序排序

5. 文件存储格式和数据压缩的优化

   ```sql
   -- 开启hive中间传输数据压缩功能
   set hive.exec.compress.intermediate=true;
   -- 开启mapreduce中map输出压缩功能
   set mapreduce.map.output.compress=true;
   -- 设置mapreduce中map输出数据的压缩方式
   set mapreduce.map.output.compress.codec= org.apache.hadoop.io.compress.SnappyCodec;
   
   -- 开启hive最终输出数据压缩功能
   set hive.exec.compress.output=true;
   -- 开启mapreduce最终输出数据压缩
   set mapreduce.output.fileoutputformat.compress=true;
   -- 设置mapreduce最终数据输出压缩方式
   set mapreduce.output.fileoutputformat.compress.codec = org.apache.hadoop.io.compress.SnappyCodec;
   -- 设置mapreduce最终数据输出压缩为块压缩
   set mapreduce.output.fileoutputformat.compress.type=BLOCK;
   ```

6. 其他解决数据倾斜的方法 - 包括 join、group by 等一般场景

### 实操

1. 使用 select 查询时，使用哪个函数给值为 null 的数据设置默认值

   ```sql
   -- 使用nvl或者coalesce对值为null的直接填充，或者使用if函数判断为null再填充
   select nvl(id, '123') from test;
   select coalesce(id, '123') from test;
   select if(isnull(id), '123', id) from test;
   ```

2. a、b、c 三个表内连接，连接字段都是 key，写出连接语句

   ```sql
   select * from a inner join b inner join c on a.key = b.key and a.key = c.key;
   ```

3. 已知 a 是一张内部表，如何将它转为外部表，写出 hive sql 语句

   ```sql
   -- 直接修改表属性中的EXTERNAL即可
   show formatted test;
   alter table test set tblproperties('EXTERNAL'='TRUE');  -- 内部转外部
   alter table test set tblproperties('EXTERNAL'='FALSE');  -- 外部转内部
   ```

4. 行转列以及列转行函数以及使用方法

   ```sql
   -- 行转列使用侧视图lateral view和explode炸裂（假设需要把列C按逗号拆分再打散）
   -- explode函数需要传入array，如果字段本就是array就不用split了
   select explode(array('a','b','c')) as col;  -- col：a,b,c
   select A, B, C_new from test a lateral view explode(split(C, ',')) b as C_new;
   
   -- 列转行使用concat_ws，同样输入array
   select concat_ws('|',array('a','b','c')) as col;  -- col:a|b|c
   select A, concat_ws(',', collect_set(c_new)) as C from test group by A; 
   ```

5. 常用的开窗函数

   参照以前写的 MySQL 中的[开窗函数]([SQL OVER窗口函数 | 汪寻 (wangxukun.top)](https://wangxukun.top/blogs/language/sql-overchuang-kou-han-shu.html))

6. rank、dense_rank 和 row_number 函数的区别

   参照以前写的 MySQL 中的[开窗函数]([SQL OVER窗口函数 | 汪寻 (wangxukun.top)](https://wangxukun.top/blogs/language/sql-overchuang-kou-han-shu.html))

7. 将字符串 "k1=v1&k2=v2&...&kn=vn" 进行分割并存入一个字段，可以查出任意 kn 对应的 vn 值，并计算共有多少个 k

   ```sql
   -- 首先使用str_to_map函数将字符串转为map，随后就可以使用[key]的方式取出对应的value，如果没有会返回NULL
   select str_to_map('k1=v1&k2=v2&k3=v3', '&', '=')['k1'];
   -- 只返回map的key或者value使用map_keys和map_values
   select map_keys(str_to_map('k1=v1&k2=v2&k3=v3', '&', '=')) map_key_cnt;
   -- 返回map的长度使用size
   select size(str_to_map('k1=v1&k2=v2&k3=v3', '&', '=')) map_key_cnt;
   ```

8. 全量用户登录日志表 login_all，字段信息 login_time、openid；新增用户登录日志表 login_new，字段信息 login_time、openid，计算每天新增用户次日、七日、30日留存率

   ```sql
   with tmp as (  -- 字段分别是openid，登录间隔时间，昨日新增用户（用于计算留存率）
   	select new.openid, datediff(new.login_time, alll.login_time) diff_time, count(distinct new.openid) over() all_user
   	from
   	(    -- 减少数据量，一天只留一条登录记录
   		select openid, to_date(login_time) login_time
   		from user_stay_new
   		group by openid, to_date(login_time)  
   	) new
   	left join
   	(    -- 减少数据量，一天只留一条登录记录
   		select openid, to_date(login_time) login_time
   		from user_stay_all
   		where datediff(login_time, current_date()) <= 33
   		group by openid, to_date(login_time) 
   	) alll
   	on alll.openid = new.openid
   )
   select diff_time, round(count(distinct openid) / max(all_user), 2) stay_pct
   from tmp
   where diff_time in (1, 7, 30)
   group by diff_time;
   ```

   基本思路是先将 user_stay_new 表每个用户只留下一次登陆记录记为 new，再从 user_stay_all 表取出每人每日一次的登录记录记为 alll，将 new 和 alll 通过 openid 左连接得到所有用户最新的和之前三十三天的登录数据，随后计算两个登录时间的时间差以及 new 表中的总人数。将结果作为临时表，存的就是几日留存的人数以及昨日登录的总人数

9. 发送消息流水表 chat_all：ctime、send_id、receiver_id、content；用户登录流水表 login_tb：ctime、id、location，输出每天有发送消息用户最近的发送消息时间、id、登录位置和登录时间

   ```sql
   with tmp as (
   	select chat.receiver_id, chat.ctime chat_time, login.ctime login_time, login.location, 
       	row_number() over(partition by chat.receiver_id, to_date(chat.ctime) order by chat.ctime desc) rows
       from chat_all chat
       inner join login_tb login
       on chat.receiver_id = login.id
       and to_date(chat.ctime) = to_date(login.ctime)
   ) 
   select receiver_id, chat_time, login_time
   from tmp
   where rows = 1;
   ```

   思路是先将用户每日登录的位置和时间 inner join 到消息流水表，如果有多条登录记录先对 login_tb 表处理，这里假设每天只有一条，然后按用户 id 和日期开窗并按发送消息的时间降序排序，将最后一条发送的时间标记为1，最后再筛选出来标记为1的记录即可

10. 一个分区表 T，字段 id、qq、age，按天分区，写出建表语句

    ```sql
    create table if not exists `T`(
    	id int,
        qq string,
        age int
    ) row format delimited
    fields terminated by '\t'
    partition by(dt string)
    stored as orc
    location '/warehouse/test/T'
    tblproperties('orc.compress'='SNAPPY');
    ```

11. 上方的分区表，求 20211021 这个分区中，年龄第 10 大的 qq 号列表

    ```sql
    with tmp as(
    	select id, qq, age,
            dense_rank() over(order by age asc) ranks
        from T
        where dt = '20211021'
    )
    select * from tmp where ranks = 10;
    ```

12. 有一个网站的访问记录表 visit_tb，每条记录有 ctime 和 ip，计算过去五分钟内访问次数最多的 1000 个 ip

    ```sql
    with tmp as (  -- 再计算这段时间内每个ip的访问次数
        select ip, size(collect_list(ip)) cnt -- count(ip)
        from (  -- 先计算当前时间和访问时间的时间差，单位为秒
            select ip, to_unix_timestamp(current_timestamp()) - to_unix_timestamp(ctime) second_diff
            from visit_tb
        )
        where second_diff <= 300
        group by ip
    )
    select ip, cnt
    from tmp
    order by cnt desc
    limit 1000;
    ```

13. 解析 extra 中所有的字段：

    ```sql
    id,os,extra
    1,iphone,[{"id":1001,"type":"show","from":"home"},{"id":1002,"type":"click","from":"swan"}]
    2,android,[{"id":1003,"type":"slide","from":"tool"},{"id":1002,"type":"del","from":"wode"},{"id":1004,"type":"click","from":"home"}]
    ```

    存储数据就不多说了，直接存储为 string 字符串，查询的时候再解析。思路是先去掉左右的数组符号，然后将数组 json 之间的分隔符由逗号替换成分号，接下来使用分号切分再使用侧视图炸裂，得到的就是一个个 json 字符串，最后再使用 json_tuple 从 json 字符串中取出多个值与原字段拼接在一起，或者使用 get_json_object 函数以此取出所需字段

    ```sql
    with tmp as (
        select id, os, b.json
        from json_array
            lateral view explode(split(regexp_replace(regexp_replace(extra, '\\[|\\]', ''), '\\}\\,\\{', '\\}\\;\\{'), '\\;')) b as json
    )
    -- select id, os, get_json_object(json, '$.id') iid, get_json_object(json, '$.type') type, get_json_object(json, '$.from') `from`
    select id, os, tmp1.iid, tmp1.type, tmp1.`from`
    from tmp lateral view json_tuple(json, 'id', 'type', 'from') tmp1 as iid, type, `from`;
    ```

14. 有一个表 subscribe_tb，两个字段分别是 gz 和 bgz，对应的 a 关注 b，数据如下：

    ```sql
    gz,bgz
    12,34
    12,56
    12,78
    34,56
    34,12
    ```

    找出所有互相关注的记录

    思路是使用关注账号和被关注账号自连接，得到新的字段被关注人所关注的账号，然后再筛选关注账号和被关注人所关注账号相同的行就是两个账号互相关注的记录

    ```sql
    with tmp as (
    	select a.gz, a.bgz, b.gz bgzgz 
        from subscribe_tb a
        inner join subscribe_tb b
        on a.gz = b.bgz
    )
    select gz, bgz
    from tmp where gz = bgzgz
    ```

15. UDF、UDAF 和 UDTF 函数的区别以及怎么开发

    UDF 是一进一出，类似于 round、year、hour、floor、abs 等函数；UDAF 则是多进一出，类似 sum、count、max、avg 等函数；UDTF 则是一进多处，在 Hive 中多用于解析 Map 或者 Array 类型并返回多行记录，类似于 explode、json_tuple 等函数

    至于 UDF 开发写了一个 Scala 版本的 UDF，[详见这里](https://wangxukun.top/blogs/software/hiveru-men-zi-ding-yi-han-shu-scala-.html)，UDAF 看不懂，有时间了可以看看[官网](https://cwiki.apache.org/confluence/display/Hive/GenericUDAFCaseStudy)

### 建模

1. 数仓的流程，你做的是什么
2. 常见的建模方法有什么，你们用的是什么
3. 维度建模有什么好处？比如业务需要增加一个维度，需要怎么做
4. 怎样判断一个需求能不能实现，你的判断标准是什么，需求变更要做什么
5. ads 每天的数据量有多大，ads 层在 MySQL 中的表是怎样创建的，有什么注意事项，索引怎样创建
6. 拉链表的原理
7. 拉链表的整合方式
8. 时点数和时期数
9. 简述几种缓慢变化维度（SCD）的处理方法

