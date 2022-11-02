---
title: MySQL常用操作命令
author: 汪寻
date: 2019-11-05
tags:
 - SQL
categories:
 - Language

---

MySQL数据库常用操作命令。

<!-- more -->

### 数据库和表操作

```sql
show databases;  -- 查看所有数据库
create database test;  -- 新建数据库
drop database test;  -- 删除数据库
use test;  -- 使用数据库

show tables  -- 查看所有表
create table tb(a int(10) primary key, b varchar(20), c varchar(25) default "33");  -- 新建表
alter table tb modify a int(15);  -- 修改字段数据类型
alter table tb change a aa int(20);  -- 修改字段名和数据类型
alter table tb add d varchar(50) first;  -- 默认在最后一列
alter table tb add d varchar(50) after a;  -- 在a字段后添加新字段
alter table tb drop d;  -- 删除字段
alter table tb engien=MyISAM;  -- 修改存储引擎
alter table tb drop foreign key key_name;  -- 删除外键
alter table tb add index idx(aa(10))  -- 添加索引
drop index idx on tb;  -- 删除索引
drop table if exists tb;  -- 删除表，若表不存在不会报错，若表中和其他表有关联则删除失败（表中的主键是其他表的外键）
```

### 存储过程

```sql
-- 新建存储过程
create procedure pr()
begin
drop procedure if exists pr;
drop table if exists tb;
create table tb(id int(10) primary key auto_increment, fn varchar(20), ln varchar(20));
insert into tb(fn, ln) values("wang","xk"),("wang","xu");
end;
call pr();  -- 运行存储过程

-- 创建变量及变量赋值
drop procedure if exists pr;
create procedure pr()
begin
declare var1, var2 varchar(20);
select fn, ln into var1, var2 from tb where id=1;
select var1, var2;
end;

call pr();

-- 定义条件
drop procedure if exists pr;
create procedure pr()
begin
declare continue handler for sqlstate '23000' set @x1=1;

create table tb_tmp(id int(10) primary key);
set @x=1;
insert into tb_tmp(id) values(1);
set @x=2;
insert into tb_tmp(id) values(1);
set @x=3;

select @x1,@x;
drop table if exists tb_tmp;
end;

call pr();

-- 光标
drop procedure if exists pr;
create procedure pr()
begin
declare var1, var2 varchar(20);
declare cur cursor for select fn, ln from tb;

open cur;
fetch cur into var1, var2;
close cur;

select var1,var2;
end;

call pr();


-- if语句
drop procedure if exists pr;
create procedure pr()
begin

declare var varchar(20);
set @x=3;
if @x=1
    then select 'x=1';
    elseif @x=2
    then select 'x=2';
    else
    select 'x=3';
end if;

end;

call pr();


-- case语句
drop procedure if exists pr;
create procedure pr()
begin
set @x=1;

case @x
    when 1 then select 'x=1';
    when 2 then select 'x=2';
    else select 'x!=1&x!=2';
end case;

case
    when @x>0 then select 'x>0';
    when @x<0 then select 'x<0';
    else select 'x=0';
end case;

end;

call pr();


-- loop循环
-- LEAVE语句用来退出任何被标注的流程控制构造
drop procedure if exists pr;
create procedure pr()
begin

declare x int(10) default 0;
add_loop:loop
set x=x+1;
if x>=5 then leave add_loop;
end if;
select x;
end loop add_loop;

end;

call pr();


-- iterate循环迭代
-- ITERATE语句将执行顺序转到语句段开头处,只可以出现在LOOP、REPEAT和WHILE语句内。
drop procedure if exists pr;
create procedure pr()
begin

declare x int(10) default 0;
loop1:loop
set x=x+1;
if x<10 then iterate loop1;
elseif x>15 then leave loop1;
end if;
end loop loop1;
select x;

end;

call pr();


-- repeat语句
-- REPEAT语句创建一个带条件判断的循环过程，每次语句执行完毕之后会对条件表达式进行判断，
-- 如果表达式为真，则循环结束；否则重复执行循环中的语句。
drop procedure if exists pr;
create procedure pr()
begin

declare x int(10) default 0;
repeat
set x=x+1;
select x;
until x>3 
end repeat;

end;

call pr();

-- while语句
drop procedure if exists pr;
create procedure pr()
begin

declare x int(10) default 0;
while x<3 do
set x=x+1;
end while;
select x;

end;

call pr();
```

### 用户及权限

```sql
-- 新增删除用户（CREATE USER语句会在MySQL.user表中添加一条新记录，但是新创建的账户没有任何权限）
create user 'user01'@'%' identified by '123456';
drop user 'user01'@'%';
delete from mysql.user where host='%' and user='user01';
-- 更新用户密码
update mysql.user set authentication_string=MD5('root_user') where host='%' and user='root_user';  -- 修改root用户密码
flush privileges;  -- 重新加载权限
set password for 'user01'@'%'='654321';  -- 修改普通用户的密码，也可以使用update
-- 新增用户并赋予权限（赋予新用户更新、查询权限，并授予grant权限）
grant select, update on  *.* to 'user01'@'localhost' identified by '123456' whth grant option;
-- 收回权限
revoke all privileges, grant option from 'user02'@'localhost';  -- 收回所有权限
revoke update on  *.* from 'user02'@'localhost';  -- 收回指定权限
show grants for 'user02'@'localhost';-- 查看权限
```

### 触发器

```sql
-- 调用存储过程
-- 传入参数x输出参数y，调用时需要指定接收参数然后使用select查看
drop procedure if exists pr;
create procedure pr(in x int, out y varchar(20))
begin
select ln into y from tb where id=x;
end;

call pr(1, @y);
select @y;
-- 查看procedure的状态
show procedure status;
-- 查看指定存储过程的详细信息
select * from information_schema.ROUTINES where ROUTINE_NAME='pr';


-- 创建触发器（不能在存储过程中创建触发器）
drop trigger if exists tri;
create trigger tri before insert on tb for each row 
    begin 
    set NEW.times=now();  -- 操作当前表使用NEW代替
    end;

insert into tb(fn,ln) values('zhang', 'san');
select * from tb;
-- 查看触发器
show triggers;
select * from information_schema.`TRIGGERS`;
```

### 备份恢复及日志

```sql
-- 数据库的备份与恢复
mysqldump -u root -p 数据库 > file.sql  -- 需要在终端运行
mysql -u root -p 数据库 < file.sql  -- 确保已有目标数据库，在终端运行
use 数据库; source /路径/file.sql  -- 在进入MySQL后运行
-- 数据库迁移（仅限相同版本数据库）
mysqldump -h rm-2zeae42nlw26e1b003o.mysql.rds.aliyuncs.com -u root_user -p test | mysql -h rm-2zem56ps0i81072ssgo.mysql.rds.aliyuncs.com -u root_user -p

-- 表的导入和导出
select * from tb into outfile '/Users/mac/Downloads/tb.txt';
mysqldump -T '/Users/mac/Downloads/tb.txt' test tb -h rm-2zeae42nlw26e1b003o.mysql.rds.aliyuncs.com -u root_user -p（在终端执行）
load data infile '/Users/mac/Downloads/tb.txt' info table test.tb;  -- 导入文件

-- 二进制日志
show variables like 'log_%';  -- 查询日志设置
show binary logs;  -- 查看现有二进制日志文件
reset master;  --C 删除所有二进制日志
purge master logs to 'mysql-bin.000035';  -- 删除创建时间比指定二进制日志文件早的文件
purge master logs before '20200101';  -- 删除早于20200101以前的二进制日志
-- 使用指定日志恢复到特定时间点之前的状态（终端执行）
mysqlbinlog --stop-datetime="2020-11-16 18:12:00" /usr/local/mysql-8.0.15-macos10.14-x86_64/data/binlog.000029 | mysql -uroot -p
set sql_log_bin=0;  -- 暂停记录二进制日志
set sql_log_bin=1;  -- 恢复记录二进制日志

-- 其他日志
show variables like 'log_error';  -- 查看错误日志
show variables like '%general%';  -- 查看通用查询日志状态
set @@global.general_log=1  -- 打开通用查询日志状态
show variables like '%slow_query%';  -- 慢查询的状态及地址
show variables like '%long_query%';  -- 慢查询的时间阈值
```

### 加密解密

```sql
-- 加密解密，使用密匙对数据库内容进行加密
create table tmp(a varbinary(16), b binary(16), c blob);
insert into tmp(a, b, c) values(aes_encrypt('张三','key001'), aes_encrypt('i am a teather!', 'key001'), aes_encrypt('李四', 'key001'));
select aes_decrypt(a, 'key001'), aes_decrypt(b, 'key001'), aes_decrypt(c, 'key001') from tmp;
drop table if exists tmp;
```

### 性能优化

```sql
show status;  -- 查看状态（连接次数，错误次数，查询，更新次数等）
explain select ln, fn from tb where fn='wang';  -- 分析查询语句
alter table tb disable keys;  -- 禁用索引
alter table tb enable keys;  -- 重新使用索引
set unique_checks=0;  -- 禁用唯一性检查
set unique_checks=1;  -- 启用唯一性检查
set foreign_key_checks=0;  -- 禁用外键检查
set foreign_key_checks=1;  -- 启用外键检查
set autocommit=0;  -- 禁用自动提交
set autocommit=1;  -- 恢复自动提交
analyze table tb;  -- 分析表
check table tb;  -- 检查表
optimize table tb;  -- 优化表
set global max_execution_time=2000;  -- 设置服务器语句超时时间，单位为毫秒
alter table tb alter index idx invisible;  -- 隐藏索引
alter table tb alter index idx visible;  -- 使索引可见
```
