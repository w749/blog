---
title: Oracle常用操作命令
author: 汪寻
date: 2019-12-11 13:20:12
updated: 2019-12-11 13:52:30
tags:
 - SQL
categories:
 - Language

---

Oracle数据库常用操作命令。

<!-- more -->

### 创建测试表

```sql
CREATE TABLE employees (
    id NUMBER ( 4 ) primary key,
    name VARCHAR2 ( 100 ),
    email VARCHAR2 ( 100 ),
    mobile VARCHAR2 ( 100 ),
    sal NUMBER ( 10, 2 ),
drly_sal NUMBER ( 10, 2 ) generated always AS ( sal / 22 ),
year_sal NUMBER ( 20, 2 ) generated always AS ( sal * 12 )) tablespace users;
insert into employees(id, name, email, mobile, sal) values(1, 'wxk', 'w749@qq.com', '19991259321', 12000);
insert into employees(id, name, email, mobile, sal) values(2, 'wx', 'wangxu@qq.com', '19991259321', 12000);
insert into employees(id, name, email, mobile, sal) values(3, 'zs', 'wangxu@qq.com', '110', 1000);
insert into employees(id, name, email, mobile, sal) values(5, 'rfv', 'qwe', '19991259321', 10000);
insert into employees(id, name, email, mobile, sal) values(6, 'asd', 'wangxu@qq.com', '19991259321', 12000);
insert into employees(id, name, email, mobile, sal) values(7, 'axc', 'wangxu@qq.com', '110', 1000);
insert into employees(id, name, email, mobile, sal) values(8, 'eee', 'eee', '110', 1000);
insert into employees(id, name, email, mobile, sal) values(9, 'yyy', 'yyy', '110', 1000);
```

### 常用操作

```sql
create table test1 tablespace users nologging as select * from employees where name = 'wxk';  -- 子查询
drop table test1;  -- 删除表

alter table employees add(dt date default sysdate not null);  -- 添加字段
alter table employees drop unused columns;  -- 删除字段
alter table employees rename column dt to ddt;  -- 修改字段名
comment on table employees is '工资薪酬表';  -- 给表加注释
comment on column employees.name is '员工姓名';  -- 给字段加注释

select table_name, tablespace_name, logging, cache, status, blocks from user_tables where tablespace_name = 'USERS';  -- 查看users表空间下的表信息
alter table employees add constraint em_name unique(name);  -- 给表增加唯一约束
alter table employees enable constraint em_name;  -- 打开约束
delete from employees where id = 4; -- 删除表内容

select constraint_name, column_name from user_cons_columns where table_name='EMPLOYEES';  -- 查看employees表下的约束信息
create index name_index on employees(ddt);  -- 新建约束

CREATE TABLE employeess tablespace USERS as select * from employees;  -- 使用as select新建表
drop table employeess;

create MATERIALIZED view demand_view as select * from employees;  -- 新建实体化视图
create MATERIALIZED view commit_view  refresh force on commit as select * from employees;  -- 创建实体化视图并在提交时刷新
exec DBMS_MVIEW.REFRESH('DEMAND_VIEW');  -- 刷新实体化视图
select * from commit_view;
drop MATERIALIZED view demand_view;  -- 删除实体化视图

create MATERIALIZED view log on employees with primary key,rowid,sequence;
create MATERIALIZED view fast_commit_view  refresh fast on commit as select * from employees;
desc MLOG$_EMPLOYEES;

select * from all_clusters;
select DIRECTORY;

create sequence test_seq start with 10 increment by 5 maxvalue 30 nocache;  -- 创建序列
select test_seq.currval from dual;
drop sequence test_seq;

create public synonym tmp_emp for system.employees;  -- 创建公共同义词，给表名绑定个名字
select * from all_synonyms where synonym_name='TMP_EMP';  -- 查看同义词信息
update tmp_emp set email='qwe@gmail.com' where id=9;  -- 利用同义词对表进行操作
select * from tmp_emp;
drop public synonym tmp_emp;  -- 删除同义词

select concat(name, concat('-', email)) www from employees;  -- concat字符串拼接

-- groupby
select email,mobile,sum(sal) sum_sal from employees group by rollup(email,mobile) order by email,mobile;  -- rollup
select email,mobile,sum(sal) sum_sal from employees group by cube(email,mobile) order by email,mobile;  -- cube
select email,mobile,sum(sal) sum_sal from employees group by grouping sets(email,mobile);   -- grouping sets

-- 累加统计over
select id,name,sal,sum(sal) over(order by id) sum_sal,count(*) over(order by id) cot from employees;   -- 利用按列排序实现指定字段累加

-- 子查询
select id,name,sal from employees where (name,sal) in (select name,sal from employees where sal > 10000);  -- 多行多列无关子查询
select * from employees e where exists(select * from employees m where e.id=m.id and length(m.email) = length(e.mobile));   -- 和外部查询相关的子查询
select e.id,e.name,m.email,m.sal from employees e,(select id,email,sal from employees where sal >= 10000) m where e.id = m.id;   -- 在from中使用子查询

-- 集合操作
select * from employees where id < 7 union select * from employees where id >5;   -- union返回两个集合的并集，重复的记录只保留一条，默认按第一列进行排序
select * from employees where id < 7 union all select * from employees where id >5;   -- union all 返回两个集合的并集，保留重复的记录，不排序
select * from employees where id < 7 intersect select * from employees where id >5;   -- intersect 返回两个集合的交集，默认按第一列排序
select * from employees where id < 7 minus select * from employees where id >5;  -- minus 返回第一个集合存在第二个集合不存在的集合，默认按第一列排序

-- insert
create table em as select * from employees;
delete from em;
insert /*+APPEND*/ into em select * from employees where id < 5;  -- 使用子查询可插入多行记录，/*+APPEND*/利用子查询装载的方式插入，操作日志不写入日志文件，效率提升
select * from em;
drop table em;

-- merge
create table em as select id,name from employees;
delete from em;
insert /*+APPEND*/ into em select id,name from employees where id < 5;
update em set name='wwxxkk' where name='wxk';
update em set name='wwxx' where name='wx';
select * from em;
-- 按id匹配的更新(id=1)不匹配的插入(id>6)
merge into em e using employees m on (e.id=m.id) when matched then update set e.name=m.name where e.id=1 when not matched then insert values(m.id,m.name) where m.id>6;
select * from em;
drop table em;

-- width_bucket
select sal,width_bucket(sal,1000,12000,3) wb from employees;
-- rpad
select name,mobile,rpad(name,10,mobile) lp from employees;
-- 日期函数
select sysdate，current_date,systimestamp,localtimestamp,add_months(sysdate,2),next_day(sysdate,2),last_day(sysdate),round(sysdate),extract(year from sysdate) year,extract(day from sysdate) day from dual;

-- PL/SQL语句
-- 匿名块
declare
    out_name varchar2(20);
begin
    select name into out_name from employees where id=123;
    dbms_output.put_line(out_name);
    exception
        when no_data_found then 
            dbms_output.put_line('no found');
end;
```

### 事务

```sql
-- transaction
DECLARE
  l_id NUMBER;
  l_name  VARCHAR2(100);
  l_mobile  VARCHAR2(50);
BEGIN
  -- 为保证set transaction是事务的第一条语句，先使用commit或rollback来结束掉前面可能存在的事务
  COMMIT;
  -- 使用name给事务命名，定义为只读事务防止DML
  SET TRANSACTION READ ONLY NAME '查询报表';
  SELECT id
    INTO l_id
    FROM employees
   WHERE id = 1;
  SELECT name
    INTO l_name
    FROM employees
   WHERE id = 1;
  SELECT mobile
    INTO l_mobile
    FROM employees
   WHERE id = 1;
  -- 终止只读事务
  COMMIT;
  dbms_output.put_line('输出：' || l_id || ',' || l_name || ',' || l_mobile);
END;

begin
    update employees set name='rfv' where id=5;
    savepoint A;  -- 设置保存点
    update employees set name='plm' where id=5;
    rollback to A;  -- 回滚到指定保存点
    commit;
end;
select name from employees where id=5;
```

### 变量与常量

```sql
/*
number
binary_integer
变量与常量
*/
declare
    num number;
    bin_int BINARY_INTEGER;
begin
    num := 100;
    bin_int := 200;
    dbms_output.put_line('NUMBER ' || num || ', BINART_INTEGER ' || bin_int);
end;

declare
    v1 number(2);
    v2 number(4) := 100;
    v3 constant number(4) default 111;
begin
    if v1 is null then
        dbms_output.put_line('v1 is null');
    end if;
    dbms_output.put_line('v2: ' || v2 || '  v3: ' ||v3);
end;

-- 自定义类型/使用原有数据表类型接收查询结果并输出
declare
    iid system.employees.id%type;
    nname system.employees.name%type;
    mmobile system.employees.mobile%type;
begin 
    select id,name,mobile into iid,nname,mmobile from employees where id=1;
    dbms_output.put_line(iid || ',' || nname || ',' || mmobile);
end;

declare
    type t_tmp is record(id number(2),name varchar2(20),mobile varchar2(20));
    v_tmp t_tmp;
begin 
    select id,name,mobile into v_tmp from employees where id=1;
    dbms_output.put_line(v_tmp.id || ',' || v_tmp.name || ',' || v_tmp.mobile);
end;

declare 
 v_tmp system.employees%rowtype;
begin 
    select * into v_tmp from employees where id=1;
    dbms_output.put_line(v_tmp.id || ',' || v_tmp.name || ',' || v_tmp.mobile || ',' || v_tmp.sal || ',' ||v_tmp.drly_sal || ',' ||v_tmp.year_sal || ',' ||v_tmp.ddt);
end;
```

### 条件控制语句及循环

```sql
-- 条件控制语句
declare
    digits number(5);
    arg varchar2(20);
begin
    digits := 10;
    if digits = 1 then arg := '1';
    elsif digits = 2 then arg := '2';
    else arg := '3';
    end if;
    dbms_output.put_line(arg);
end;

declare
    digits number(5);
    arg varchar2(20);
begin
    digits := 10;
    case digits
        when 10 then arg := '1';
        when 20 then arg := '2';
        else arg := '3';
    end case;
    dbms_output.put_line(arg);
end;

declare
    digits number(5);
    arg varchar2(20);
begin
    digits := 20;
    case 
        when digits<20 then arg := '2';
        when digits<30 then arg := '3';
        else arg := '4';
    end case;
    dbms_output.put_line(arg);
end;

-- 循环loop、while、for
declare
    arg number(2) := 1;
begin
    loop 
        dbms_output.put_line(arg);
        arg := arg+1;
        exit when arg > 5;
    end loop;
end;

declare
    arg number := 1;
begin
    while arg < 5 loop 
        dbms_output.put_line(arg);
        arg := arg+1;
    end loop;
end;

begin
    for arg in 1..5 loop
        dbms_output.put_line(arg);
    end loop;
end;
```

### 游标

```sql
declare
    cursor v_cur is select id,name,mobile from employees;
    t_cur v_cur%ROWTYPE;
begin
    open v_cur; 
    loop
        fetch v_cur into t_cur;
        exit when v_cur%NOTFOUND;
        dbms_output.put_line('id:' || t_cur.id || ',name:' || t_cur.name || ',mobile:' || t_cur.mobile);
    end loop;
    close v_cur;
end;
-- 使用for循环则不用考虑打开和关闭游标，以及判断数据是否取完
declare
    cursor v_cur is select id,name,mobile from employees;
begin
    for t_cur in v_cur loop
        dbms_output.put_line('id:' || t_cur.id || ',name:' || t_cur.name || ',mobile:' || t_cur.mobile);
    end loop;
end;
```

### 存储过程

```sql
create or replace PROCEDURE pro ( tmp system.employees.id % TYPE ) as
BEGIN
update employees set name='wangxukun' where id=tmp;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
        dbms_output.put_line ( 123 );END pro;
call pro (1);
DROP PROCEDURE pro;
```

### 函数

```sql
-- 创建函数
create or replace FUNCTION func ( num system.employees.id % TYPE ) 
return system.employees.name % TYPE 
AS 
strr system.employees.name % TYPE;
BEGIN
    SELECT
        name INTO strr 
    FROM
        employees 
    WHERE
        id = num;
    return strr;END func;
SELECT
    func ( id ) nn
FROM
    employees;
DROP FUNCTION func;
```

### 包操作

```sql
-- 创建包规范（必须先定义后使用）
create or replace package pck
as
    str system.employees.name % TYPE;
    num number;
  procedure proce ( tmp1 system.employees.id % TYPE,tmp2 system.employees.name % TYPE );
    procedure proce ( tmp2 system.employees.name % TYPE,tmp3 system.employees.email % TYPE );  -- 包的重载
end pck;

-- 创建包体（包体中的必须是规范中定义的，否则就是局部的，外部不可调用）
create or replace package body pck
as 
    PROCEDURE proce ( tmp1 system.employees.id % TYPE,tmp2 system.employees.name % TYPE )  -- 根据id修改name
    as
    BEGIN
    update employees set name=tmp2 where id=tmp1;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
        dbms_output.put_line ( 123 );END proce;

    PROCEDURE proce ( tmp2 system.employees.name % TYPE,tmp3 system.employees.email % TYPE )  -- 根据name修改email
    as
    BEGIN
    update employees set email=tmp3 where name=tmp2;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
        dbms_output.put_line ( 123 );END proce;
end pck;

-- 包的调用
declare
    tmp1 system.employees.id % type :=1;
    tmp2 system.employees.name % type :='wxk';
    tmp3 system.employees.email % type :='w749@qq.com';

    id1 system.employees.id % type;
    name1 system.employees.name % type;
    email1 system.employees.email % type;
begin
    pck.proce(tmp1,tmp2);
    pck.proce(tmp2,tmp3);
    select id,name,email into id1,name1,email1 from employees where id=tmp1;
    dbms_output.put_line(id1 || ' , ' || name1 || ' , ' || email1);
end;
```

### 触发器

```sql
create or replace trigger trig  -- 限定只能在工作日内进行DML操作
    before update or insert or delete 
    on system.employees 
begin
    if to_char(sysdate,'HH24:MI') not between '12:00' and '18:00'
    or to_char(sysdate,'DY','NLS_DATE_LANGUAGE=AMERICAN')
    in ('SAT','SUN') then
    raise_application_error(-20005,'只能在工作日内的指定时间进行DML操作。');
    end if;
end trig;
create or replace trigger trigg  -- 限定修改后的薪资必须高于修改前的薪资
    before update of sal 
    on system.employees
    for each row
when(old.sal >= new.sal)
begin
    raise_application_error(-20001,'修改后的薪资必须高于修改前的薪资。');
end trigg;
update system.employees set name='wwxxkk' where id=1;
update system.employees set sal=12000 where id=1;
alter trigger trig enable;  -- 启用/禁用触发器
drop trigger trig;  -- 触发器必须是启用状态才可以删除
```

### 表空间

```sql
SELECT * FROM Dba_Data_Files ddf WHERE ddf.tablespace_name = 'TBS1';  -- 查看表空间信息
create tablespace tbs1 datafile '/home/oracle/app/oracle/oradata/helowin/tbs1.dbf' size 50m;  -- 创建表空间
create tablespace tbs2 datafile '/home/oracle/app/oracle/oradata/helowin/tbs2.dbf' size 50m;  -- 创建表空间
alter tablespace tbs1 add datafile '/home/oracle/app/oracle/oradata/helowin/tbs3.dbf' size 5m;  -- 改变表空间大小，为表空间增加数据文件
SELECT * FROM Dba_Data_Files ddf WHERE ddf.tablespace_name like 'TBS%';  -- 添加的数据文件和原始表空间数据文件是分开的，但属于同一个表空间
alter tablespace tbs1 read only;  -- 将表空间权限修改为只读，这样表空间中的表都是只读改为read write恢复读写
alter database default tablespace tbs1;  -- 设置数据库默认表空间
drop tablespace tbs1 including contents and datafiles;  -- 删除表空间以及其中所有内容以及数据文件
```

### 分区表

```sql
create table part(
    id number primary key,
    type varchar2(10),
    extra varchar2(10)
    )
tablespace users 
partition by list(type) 
(
    partition aaa values('A','a') tablespace tbs1,
    partition bbb values('B','b') tablespace tbs2,
    partition ddd values(NULL),
    partition eee values(DEFAULT)
);
select * from dba_tab_partitions where table_name='PART';  -- 查看分区表情况
insert into part values(1,'A','aa');
insert into part values(2,'B','aa');
insert into part values(3,'B','aa');
insert into part values(4,'C','aa');
select * from part;
```
