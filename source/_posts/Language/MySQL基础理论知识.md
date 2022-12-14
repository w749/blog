---
title: MySQL基础理论知识
author: 汪寻
date: 2019-10-28 10:13:17
updated: 2019-10-28 10:38:56
tags:
 - SQL
categories:
 - Language

---

MySQL数据库基础理论知识。

<!-- more -->

### 数据类型

#### **整型**

数据类型**INT(11)**，注意后面的数字11，它表示的是该数据类型指定的显示宽度，即能够显示的数值中数字的个数。显示宽度和数据类型的取值范围是无关的。显示宽度只是指明MySQL最大可能显示的数字个数，数值的位数小于指定的宽度时会由空格填充；如果插入了大于显示宽度的值，只要该值不超过该类型整数的取值范围，数值依然可以插入，而且能够显示出来。显示宽度只用于显示，并不能限制取值范围和占用空间。例如：INT(3)会占用4字节的存储空间，并且允许的最大值不会是999，而是INT整型所允许的最大值。TINYINT、SMALLINT、MEDIUMINT、INT（INTEGER）、BIGINT类型分别占用1、2、3、4、8个字节，对应存储最大值的范围也就不一样。

#### **浮点型**

MySQL中使用浮点数和定点数来表示小数。浮点数类型有两种：**单精度浮点类型（FLOAT）和双精度浮点类型（DOUBLE）**。定点数类型只有一种：**DECIMAL**。浮点数类型和定点数类型都可以用（M，N）来表示。其中，M称为精度，表示总共的位数；N称为标度，表示小数的位数。分别占用的字节为4、8、M+2个字节。如果用户指定的精度超出精度范围，则会四舍五入。

#### **日期**

MySQL中有多种表示日期的数据类型，主要有**YEAR、TIME、DATE、DATETIME和TIMESTAMP**。分别占用的字节为1、3、3、8、4个字节。
TIMESTAMP与DATETIME除了存储字节和支持的范围不同外，还有一个最大的区别就是：DATETIME在存储日期数据时，按实际输入的格式存储，即输入什么就存储什么，与时区无关；而TIMESTAMP值的存储是以UTC（世界标准时间）格式保存的，存储时对当前时区进行转换，检索时再转换回当前时区。

#### **字符串**

MySQL支持两类字符型数据：文本字符串和二进制字符串。在MySQL中，文本字符串类型是指**CHAR、VARCHAR、TEXT、ENUM和SET**。
**CHAR(M)**为固定长度字符串，在定义时指定字符串列长。VARCHAR(M)是长度可变的字符串，M表示最大列长度。M的范围是0~65535。CHAR是固定长度，所以它的处理速度比VARCHAR的速度要快，但是它的缺点是浪费存储空间，所以对存储不大但在速度上有要求的可以使用CHAR类型，反之可以使用VARCHAR类型来实现。对于MyISAM存储引擎：最好使用固定长度的数据列代替可变长度的数据列。这样可以使整个表静态化，从而使数据检索更快，用空间换时间。对于InnoDB存储引擎：使用可变长度的数据列，因为InnoDB数据表的存储格式不分固定长度和可变长度，因此使用CHAR不一定比使用VARCHAR更好，但由于VARCHAR是按照实际的长度存储的，比较节省空间，所以对磁盘I/O和数据存储总量比较好。
**VARCHAR**的最大实际长度由最长的行的大小和使用的字符集确定，而其实际占用的空间为字符串的实际长度加1。TEXT列保存非二进制字符串，如文章内容、评论等。当保存或查询TEXT列的值时，不删除尾部空格。Text类型分为4种：TINYTEXT、TEXT、MEDIUMTEXT和LONGTEXT。不同的TEXT类型的存储空间和数据长度不同。
**ENUM**是一个字符串对象，其值为表创建时在列规定中枚举的一列值。
**SET**是一个字符串对象，可以有零或多个值。与ENUM类型不同的是，ENUM类型的字段只能从定义的列值中选择一个值插入，而SET类型的列可从定义的列值中选择多个字符的联合。如果插入SET字段中列值有重复，则MySQL自动删除重复的值；如果插入了不正确的值，默认情况下，MySQL将忽视这些值，并给出警告。

#### **二进制数据类型**

MySQL中的二进制数据类型有**BIT、BINARY、VARBINARY、TINYBLOB、BLOB、MEDIUMBLOB和LONGBLOB**。
**BIT**类型是位字段类型。M表示每个值的位数，范围为1~64。
**BINARY和VARBINARY**类型类似于CHAR和VARCHAR，不同的是它们包含二进制字节字符串。
**BLOB**是一个二进制大对象，用来存储可变数量的数据。BLOB列存储的是二进制字符串（字节字符串），TEXT列存储的是非二进制字符串（字符字符串）。BLOB主要存储图片、音频信息等，而TEXT只能存储纯文本文件。

**CAST(x, AS type)和CONVERT(x, type)**函数将一个类型的值转换为另一个类型的值，可转换的type有BINARY、CHAR(n)、DATE、TIME、DATETIME、DECIMAL、SIGNED、UNSIGNED。

### 函数

#### **数学函数**

**ROUND(x,y)**返回最接近于参数x的数，其值保留到小数点后面y位，若y为负值，则将保留x值到小数点左边y位。y值为负数时，保留的小数点左边的相应位数直接保存为0，不进行四舍五入。
**TRUNCATE(x,y)**返回被舍去至小数点后y位的数字x。若y的值为0，则结果不带有小数点或不带有小数部分。若y设为负数，则截去（归零）x小数点左起第y位开始后面所有低位的值。ROUND(x,y)函数在截取值的时候会四舍五入，而TRUNCATE (x,y)直接截取值，并不进行四舍五入。
**SIGN(x)**返回参数的符号，x的值为负、零或正时返回结果依次为-1、0或1。

#### **字符串函数**

**CONCAT(s1,s2,…)**返回结果为连接参数产生的字符串，或许有一个或多个参数。
在**CONCAT_WS(x,s1,s2,…)**中，CONCAT_WS代表CONCAT With Separator，是CONCAT()的特殊形式。第一个参数x是其他参数的分隔符，分隔符的位置放在要连接的两个字符串之间。
**INSERT(s1,x,len,s2)**返回字符串s1，其子字符串起始于x位置和被字符串s2取代的len字符。如果x超过字符串长度，则返回值为原始字符串。假如len的长度大于其他字符串的长度，则从位置x开始替换。若任何一个参数为NULL，则返回值为NULL。
**LEFT(s,n)**返回字符串s开始的最左边n个字符。
**RIGHT(s,n)**返回字符串str最右边的n个字符。
**LPAD(s1,len,s2)**返回字符串s1，其左边由字符串s2填补到len字符长度。假如s1的长度大于len，则返回值被缩短至len字符。
**RPAD(s1,len,s2)**返回字符串sl，其右边被字符串s2填补至len字符长度。假如字符串s1的长度大于len，则返回值被缩短到len字符长度。
**LTRIM(s)**返回字符串s，字符串左侧空格字符被删除。
**RTRIM(s)**返回字符串s，字符串右侧空格字符被删除。
**TRIM(s1 FROM s)**删除字符串s中两端所有的子字符串s1。s1为可选项，在未指定情况下，删除空格。
**REPEAT(s,n)**返回一个由重复的字符串s组成的字符串，字符串s的数目等于n。若n<=0，则返回一个空字符串。若s或n为NULL，则返回NULL。
**REPLACE(s,s1,s2)**使用字符串s2替代字符串s中所有的字符串s1。
**STRCMP(s1,s2)**：若所有的字符串均相同，则返回0；若根据当前分类次序，第一个参数小于第二个，则返回-1；其他情况返回1。
**SUBSTRING(s,n,len)**带有len参数的格式，从字符串s返回一个长度与len字符相同的子字符串，起始于位置n。也可能对n使用一个负值。假若这样，则子字符串的位置起始于字符串结尾的n字符，即倒数第n个字符，而不是字符串的开头位置。
**MID(s,n,len)**与SUBSTRING(s,n,len)的作用相同。
**LOCATE(str1,str)、POSITION(str1 IN str)和INSTR(str, str1)**3个函数的作用相同，返回子字符串str1在字符串str中的开始位置。
**REVERSE(s)**将字符串s反转，返回的字符串的顺序和s字符串顺序相反。
**ELT(N，字符串1，字符串2，字符串3，...，字符串N)**：若N = 1，则返回值为字符串1；若N=2，则返回值为字符串2；以此类推；若N小于1或大于参数的数目，则返回值为NULL。
**FIELD(s,s1,s2,…,sn)**返回字符串s在列表s1,s2,…,sn中第一次出现的位置，在找不到s的情况下，返回值为0。如果s为NULL，则返回值为0，原因是NULL不能同任何值进行同等比较。
**FIND_IN_SET(s1,s2)**返回字符串s1在字符串列表s2中出现的位置，字符串列表是一个由多个逗号‘,’分开的字符串组成的列表。如果s1不在s2或s2为空字符串，则返回值为0。如果任意一个参数为NULL，则返回值为NULL。这个函数在第一个参数包含一个逗号‘,’时将无法正常运行。

#### **日期函数**

**CURDATE()和CURRENT_DATE()**函数的作用相同，将当前日期按照‘YYYY-MM-DD’或YYYYMMDD格式的值返回。
**CURTIME()和CURRENT_TIME()**函数的作用相同，将当前时间以‘HH:MM:SS’或HHMMSS的格式返回。
**CURRENT_TIMESTAMP()、LOCALTIME()、NOW()和SYSDATE() **4个函数的作用相同，均返回当前日期和时间值，格式为‘YYYY-MM-DD HH:MM:SS’或YYYYMMDDHHMMSS，具体格式根据函数在字符串或数字语境中而定。
**UNIX_TIMESTAMP(date)**若无参数调用，则返回一个UNIX时间戳（‘1970-01-01 00:00:00’GMT之后的秒数）作为无符号整数。其中，GMT（Green wich mean time）为格林尼治标准时间。若用date来调用UNIX_TIMESTAMP()，它会将参数值以‘1970-01-01 00:00:00’GMT后的秒数的形式返回。date可以是一个DATE字符串、DATETIME字符串、TIMESTAMP或一个当地时间的YYMMDD或YYYYMMDD格式的数字。
**FROM_UNIXTIME(date)**函数把UNIX时间戳转换为普通格式的时间，与UNIX_TIMESTAMP (date)函数互为反函数。
**UTC_DATE()**函数返回当前UTC（世界标准时间）日期值，其格式为‘YYYY-MM-DD’或YYYYMMDD，具体格式取决于函数是否用在字符串或数字语境中。
**UTC_TIME()**返回当前UTC时间，格式为‘HH:MM:SS’或HHMMSS，具体格式取决于函数是否用在字符串或数字语境中。
**MONTHNAME(date)**函数返回日期date对应月份的英文全名。
**DAYNAME(d)**函数返回d对应的工作日的英文名称，例如Sunday、Monday等。
**DAYOFWEEK(d)**函数返回d对应的一周中的索引（位置，1表示周日，2表示周一，...，7表示周六）。
**WEEKDAY(d)**返回d对应的工作日索引：0表示周一，1表示周二，...，6表示周日。
**WEEKOFYEAR(d)**计算某天位于一年中的第几周，范围是1~53，相当于WEEK(d,3)。
**DAYOFYEAR(d)**函数返回d是一年中的第几天，范围是1~366。
**DAYOFMONTH(d)**函数返回d是一个月中的第几天，范围是1~31。
**QUARTER(date)**返回date对应的一年中的季度值，范围是1~4。

#### 系统函数

**VERSION()**返回指示MySQL服务器版本的字符串。这个字符串使用utf8字符集。
**CONNECTION_ID()**返回MySQL服务器当前连接的次数，每个连接都有各自唯一的ID。
**SHOW PROCESSLIST**命令输出当前用户的连接信息。processlist命令的输出结果显示了有哪些线程在运行，不仅可以查看当前所有的连接数，还可以查看当前的连接状态、帮助识别出有问题的查询语句等。如果是root账号，能看到所有用户的当前连接。如果是其他普通账号，则只能看到自己占用的连接。show processlist只列出前100条，如果想全部列出可使用show full processlist命令。
**USER()、CURRENT_USER、CURRENT_USER()、SYSTEM_USER()和SESSION_USER()**这几个函数返回当前被MySQL服务器验证的用户名和主机名组合。这个值符合确定当前登录用户存取权限的MySQL账户。一般情况下，这几个函数的返回值是相同的。
**CHARSET(str)**返回字符串str自变量的字符集。
**COLLATION(str)**返回字符串str的字符排列方式。

#### 加密函数

**MD5(str)**为字符串算出一个MD5 128比特校验和。该值以32位十六进制数字的二进制字符串形式返回，若参数为NULL，则会返回NULL。
**SHA(str)**从原明文密码str计算并返回加密后的密码字符串，当参数为NULL时，返回NULL。SHA加密算法比MD5更加安全。
**SHA2(str, hash_length)**使用hash_length作为长度，加密str。hash_length支持的值为224、256、384、512和0。其中，0等同于256。

### 日志

MySQL日志主要分为4类，使用这些日志文件，可以查看MySQL内部发生的事情。这4类日志分别是：

**错误日志**：记录MySQL服务的启动、运行或停止MySQL服务时出现的问题。
**查询日志**：记录建立的客户端连接和执行的语句。
**二进制日志**：记录所有更改数据的语句，可以用于数据复制。
**慢查询日志**：记录所有执行时间超过long_query_time的所有查询或不使用索引的查询。

默认情况下，所有日志创建于MySQL数据目录中。通过刷新日志，可以强制MySQL关闭和重新打开日志文件（或者在某些情况下切换到一个新的日志）。当执行一个FLUSH LOGS语句或执行MySQLadmin flush-logs或MySQLadmin refresh时，将刷新日志。如果正使用MySQL复制功能，在复制服务器上可以维护更多日志文件，这种日志称为接替日志。启动日志功能会降低MySQL数据库的性能。例如，在查询非常频繁的MySQL数据库系统中，如果开启了通用查询日志和慢查询日志，MySQL数据库会花费很多时间记录日志。同时，日志会占用大量的磁盘空间。

#### 二进制日志

二进制日志主要记录MySQL数据库的变化。二进制日志以一种有效的格式并且是事务安全的方式包含更新日志中可用的所有信息。二进制日志包含了所有更新了数据或者已经潜在更新了数据（例如，没有匹配任何行的一个DELETE）的语句。语句以“事件”的形式保存，描述数据更改。

二进制日志还包含关于每个更新数据库的语句的执行时间信息。它不包含没有修改任何数据的语句。如果想要记录所有语句（例如，为了识别有问题的查询），需要使用一般查询日志。使用二进制日志的主要目的是最大可能地恢复数据库，因为二进制日志包含备份后进行的所有更新。

可通过show binary logs;  # 查看现有二进制日志文件，一般保存在安装目录下/data目录下，binlog.0000编号（路径名称可以在my.ini/cnf配置）

#### 错误日志

错误日志文件包含了当MySQLd启动和停止时，以及服务器在运行过程中发生任何严重错误时的相关信息。在MySQL中，错误日志也是非常有用的，MySQL会将启动和停止数据库信息以及一些错误信息记录到错误日志文件中。

可通过show variables like '%log_error%';  # 查看错误日志状态和位置，一般保存在安装目录下/data目录下，服务器主机名.err（路径名称可以在my.ini/cnf配置）

#### 通用日志

通用查询日志记录MySQL的所有用户操作，包括启动和关闭服务、执行查询和更新语句等。本节将为读者介绍通用查询日志的启动、查看、删除等内容。通用查询日志中记录了用户的所有操作。通过查看通用查询日志，可以了解用户对MySQL进行的操作。通用查询日志记录用户的所有操作，因此在用户查询、更新频繁的情况下，通用查询日志会增长得很快。数据库管理员可以定期删除比较早的通用日志，以节省磁盘空间。

可通过show variables like '%general%';  # 查看通用查询日志状态和位置，一般保存在安装目录下/data目录下，服务器主机名.log

#### 慢查询日志

慢查询日志是记录查询时长超过指定时间的日志。慢查询日志主要用来记录执行时间较长的查询语句。通过慢查询日志，可以找出执行时间较长、执行效率较低的语句，然后进行优化。

### 优化

通过对查询语句的分析，可以了解查询语句执行情况，找出查询语句执行的瓶颈，从而优化查询语句。
语法是explain 查询语句。主要去看type和rows（扫描的记录行数），possible_keys：指出MySQL能使用哪个索引在该表中找到行。如果该列是NULL，则没有相关的索引；key：表示查询实际使用到的索引，如果没有选择索引，该列的值是NULL；rows：显示MySQL在表中进行查询时必须检查的行数。用来对比各种查询语句是否最优。

#### 使用索引查询

在使用LIKE关键字进行查询的查询语句中，如果匹配字符串的第一个字符为“%”，索引不会起作用。只有“%”不在第一个位置，索引才会起作用。

对于多列索引，只有查询条件中使用了这些字段中的第1个字段时索引才会被使用。（最左匹配原则）

查询语句的查询条件中只有OR关键字，且OR前后的两个条件中的列都是索引时，查询中才使用索引；否则，查询将不使用索引。

#### 优化子查询

执行子查询时，MySQL需要为内层查询语句的查询结果建立一个临时表。然后外层查询语句从临时表中查询记录。查询完毕后，再撤销这些临时表。

在MySQL中，可以使用连接（JOIN）查询来替代子查询。连接查询不需要建立临时表，其速度比子查询要快，如果查询中使用索引，性能会更好。连接之所以更有效率，是因为MySQL不需要在内存中创建临时表来完成查询工作。

#### 优化数据库结构

**将字段很多的表分解成多个表**：对于字段较多的表，如果有些字段的使用频率很低，可以将这些字段分离出来，形成新表。通过这种分解，可以提高表的查询效率。对于字段很多且有些字段使用不频繁的表，可以通过这种分解的方式来优化数据库的性能。

**增加中间表**：对于需要经常联合查询的表，可以建立中间表，以提高查询效率。通过建立中间表，把需要经常联合查询的数据插入到中间表中，然后将原来的联合查询改为对中间表的查询，以此来提高查询效率。

**增加冗余字段**：合理地加入冗余字段可以提高查询速度。冗余字段会导致一些问题。比如，冗余字段的值在一个表中被修改了，就要想办法在其他表中更新该字段，否则就会使原本一致的数据变得不一致。从数据库性能来看，为了提高查询速度而增加少量的冗余大部分时候是可以接受的。是否通过增加冗余来提高数据库性能，这要根据实际需求综合分析。

**优化插入记录的速度**：插入记录时，影响插入速度的主要是索引、唯一性校验、一次插入记录条数等。根据这些情况，可以分别进行优化。

1. **禁用索引**
   对于非空表，插入记录时，MySQL会根据表的索引对插入的记录建立索引。如果插入大量数据，建立索引会降低插入记录的速度。为了解决这种情况，可以在插入记录之前禁用索引，数据插入完毕后再开启索引。对于空表批量导入数据，则不需要进行此操作。
2. **禁用唯一性检查**
   插入数据时，MySQL会对插入的记录进行唯一性校验。这种唯一性校验也会降低插入记录的速度。为了降低这种情况对查询速度的影响，可以在插入记录之前禁用唯一性检查，等到记录插入完毕后再开启。
3. **使用批量插入**
   使用批量插入速度比一条一条插入速度快。
4. **使用LOAD DATA INFILE批量导入**
   当需要批量导入数据时，如果能用LOAD DATA INFILE语句，就尽量使用。因为LOAD DATA INFILE语句导入数据的速度比INSERT语句快。
5. **禁用外键检查**
   插入数据之前执行禁止对外键的检查，数据插入完成之后再恢复对外键的检查。
6. **禁止自动提交**
   插入数据之前禁止事务的自动提交，数据导入完成之后，执行恢复自动提交操作。

#### **优化MySQL服务器**

优化MySQL服务器主要从两方面来优化：一方面是对硬件进行优化；另一方面是对MySQL服务的参数进行优化。这部分的内容需要较全面的知识，一般只有专业的数据库管理员才能进行这一类的优化。对于可以定制参数的操作系统，也可以针对MySQL进行操作系统优化。

#### **服务器语句超时处理**

可以设置服务器语句超时的限制，单位可以达到毫秒级别。当中断的执行语句超过设置的毫秒数后，服务器将终止查询影响不大的事务或连接，然后将错误报给客户端。

#### **创建全局通用表空间**

创建全局通用表空间，全局表空间可以被所有数据库的表共享，而且相比于独享表空间，手动创建共享表空间可以节约元数据方面的内存。可以在创建表的时候指定属于哪个表空间，也可以对已有表进行表空间修改。

#### **支持不可见索引**

不可见索引的特性对于性能调试非常有用。在MySQL 8.0中，索引可以被“隐藏”和“显示”。当一个索引被隐藏时，它不会被查询优化器所使用。也就是说，管理员可以隐藏一个索引，然后观察对数据库的影响。如果数据库性能有所下降，就说明这个索引是有用的，于是将其“恢复显示”即可；如果数据库性能看不出变化，说明这个索引是多余的，可以删掉了。当索引被隐藏时，它的内容仍然是和正常索引一样实时更新的。

#### **使用查询缓冲区**

查询缓冲区可以提高查询的速度，但是这种方式只适合查询语句比较多、更新语句比较少的情况。默认情况下查询缓冲区的大小为0，也就是不可用。可以修改query_cache_size以调整查询缓冲区大小，修改query_cache_type以调整查询缓冲区的类型。在my.ini中修改query_cache_size和query_cache_type的值。

query_cache_type=1表示开启查询缓冲区。只有在查询语句中包含SQL_NO_CACHE关键字时，才不会使用查询缓冲区。可以使用FLUSH QUERY CACHE语句来刷新缓冲区，清理查询缓冲区中的碎片。

### 主从复制

在MySQL中，复制操作是异步进行的，slaves服务器不需要持续地保持连接接收master服务器的数据。

MySQL支持一台主服务器同时向多台从服务器进行复制操作，从服务器同时可以作为其他从服务器的主服务器，如果MySQL主服务器访问量比较大，可以通过复制数据，然后在从服务器上进行查询操作，从而降低主服务器的访问压力，同时从服务器作为主服务器的备份，可以避免主服务器因为故障数据丢失的问题。

MySQL数据库复制操作大致可以分成3个步骤：
步骤01　主服务器将数据的改变记录到二进制日志（binary log）中。
步骤02　从服务器将主服务器的binary log events复制到它的中继日志（relay log）中。
步骤03　从服务器重做中继日志中的事件，将数据的改变与从服务器保持同步。

首先，主服务器会记录二进制日志，每个事务更新数据完成之前，主服务器将这些操作的信息记录在二进制日志里面，在事件写入二进制日志完成后，主服务器通知存储引擎提交事务。

Slave上面的I/O进程连接上Master，并发出日志请求，Master接收到来自Slave的IO进程的请求后，根据请求信息添加位置信息后，返回给Slave的IO进程。返回信息中除了日志所包含的信息之外，还包括本次返回的信息已经到Master端的bin-log文件的名称以及bin-log的位置。

Slave的I/O进程接收到信息后，将接收到的日志内容依次添加到Slave端的relay-log文件的最末端，并将读取到Master端的bin-log文件名和位置记录到master-info文件中。

Slave的Sql进程检测到relay-log中新增加了内容后，会马上解析relay-log的内容成为在Master端真实执行时的那些可执行内容，并在自身执行。

### 读写分离

阿里云可设置[读写分离](https://help.aliyun.com/document_detail/96073.html?spm=a2c4g.11174283.2.54.19ff5b8393N8Jz)，使用数据库独享代理，达到写操作自动发送到主实例，读操作则发送到只读实例，若有多个只读实例可分配权重，按时间收费。
