---
title: Shell-If条件判断
author: 汪寻
date: 2022-09-16 12:12:27
updated: 2022-09-16 12:55:19
tags:
  - Linux
categories:
  - Language
---

Shell 脚本文件中 if 中的常用判断

<!-- more -->

## If 基本语法

```bash
if [ command ];then
  # 符合该条件执行的语句
elif [ command ];then
  # 符合该条件执行的语句
else
  # 符合该条件执行的语句
fi
```

## 文件/目录判断

|        操作         |                                                  说明                                                  |
| :-----------------: | :----------------------------------------------------------------------------------------------------: |
|     [ -b FILE ]     |                                如果 FILE 存在且是一个块特殊文件则为真。                                |
|     [ -c FILE ]     |                                如果 FILE 存在且是一个字特殊文件则为真。                                |
|     [ -d DIR ]      |                                   如果 FILE 存在且是一个目录则为真。                                   |
|     [ -e FILE ]     |                                         如果 FILE 存在则为真。                                         |
|     [ -f FILE ]     |                                 如果 FILE 存在且是一个普通文件则为真。                                 |
|     [ -g FILE ]     |                                如果 FILE 存在且已经设置了 SGID 则为真。                                |
|     [ -k FILE ]     |                                如果 FILE 存在且已经设置了粘制位则为真。                                |
|     [ -p FILE ]     |                            如果 FILE 存在且是一个名字管道(F 如果 O)则为真。                            |
|     [ -r FILE ]     |                                    如果 FILE 存在且是可读的则为真。                                    |
|     [ -s FILE ]     |                                  如果 FILE 存在且大小不为 0 则为真。                                   |
|      [ -t FD ]      |                              如果文件描述符 FD 打开且指向一个终端则为真。                              |
|     [ -u FILE ]     |                           如果 FILE 存在且设置了 SUID (set user ID)则为真。                            |
|     [ -w FILE ]     |                                    如果 FILE 存在且是可写的则为真。                                    |
|     [ -x FILE ]     |                                   如果 FILE 存在且是可执行的则为真。                                   |
|     [ -O FILE ]     |                                 如果 FILE 存在且属有效用户 ID 则为真。                                 |
|     [ -G FILE ]     |                                  如果 FILE 存在且属有效用户组则为真。                                  |
|     [ -L FILE ]     |                                 如果 FILE 存在且是一个符号连接则为真。                                 |
|     [ -N FILE ]     |                如果 FILE 存在 and has been mod 如果 ied since it was last read 则为真。                |
|     [ -S FILE ]     |                                  如果 FILE 存在且是一个套接字则为真。                                  |
| [ FILE1 -nt FILE2 ] | 如果 FILE1 has been changed more recently than FILE2, or 如果 FILE1 exists and FILE2 does not 则为真。 |
| [ FILE1 -ot FILE2 ] |                    如果 FILE1 比 FILE2 要老, 或者 FILE2 存在且 FILE1 不存在则为真。                    |
| [ FILE1 -ef FILE2 ] |                           如果 FILE1 和 FILE2 指向相同的设备和节点号则为真。                           |

## 字符串判断

|          操作          |                                                说明                                                 |
| :--------------------: | :-------------------------------------------------------------------------------------------------: |
|     [ -z STRING ]      |                      如果 STRING 的长度为零则为真 ，即判断是否为空，空即是真。                      |
|     [ -n STRING ]      |                    如果 STRING 的长度非零则为真 ，即判断是否为非空，非空即是真。                    |
| [ STRING1 = STRING2 ]  |                                     如果两个字符串相同则为真 。                                     |
| [ STRING1 != STRING2 ] |                                      如果字符串不相同则为真 。                                      |
|      [ STRING1 ]       |                                 如果字符串不为空则为真,与-n 类似。                                  |
|           =            |                                     等于,如: if [ "$a" = "$b" ]                                     |
|           ==           |                       等于,如: if [ "$a" == "$b" ],与 if [ "$a" = "$b" ]等价                        |
|           !=           |              不等于,如: if [ "$a" != "$b" ] . 这个操作符将在 [[]] 结构中使用模式匹配.               |
|           <            | 小于,在 ASCII 字母顺序下.如: if [["$a" < "$b"]] if [ "$a" \< "$b" ] 注意:在 [] 结构中 < 需要被转义. |
|           >            | 大于,在 ASCII 字母顺序下.如:if [["$a" > "$b"]] if [ "$a" \> "$b" ] 注意:在 [] 结构中 > 需要被转义.  |

**注意:** == 的功能在 [[]] 和 [] 中的行为是不同的,如下: [[ $a == z*]] 如果 $a 以 z 开头(模式匹配)那么将为 true; [[$a == "z*"]] 如果 $a 等于 z* (字符匹配), 那么结果为 true; [ $a == z* ] File globbing 和 word splitting 将会发生; 关于 File globbing 是一种关于文件的速记法,比如 \*.c 就是,再如 ~ 也是; 但是 file globbing 并不是严格的正则表达式,虽然绝大多数情况下结构比较像.

## 数值判断

|     操作      |                   说明                    |
| :-----------: | :---------------------------------------: |
| INT1 -eq INT2 |       INT1 和 INT2 两数相等为真 ,=        |
| INT1 -ne INT2 |       INT1 和 INT2 两数不等为真 ,<>       |
| INT1 -gt INT2 |          INT1 大于 INT1 为真 ,>           |
| INT1 -ge INT2 |        INT1 大于等于 INT2 为真,>=         |
| INT1 -lt INT2 |          INT1 小于 INT2 为真 ,<           |
| INT1 -le INT2 |        INT1 小于等于 INT2 为真,<=         |
|       <       |   小于(需要双括号),如: (("$a" < "$b"))    |
|      <=       | 小于等于(需要双括号),如: (("$a" <= "$b")) |
|       >       |   大于(需要双括号),如: (("$a" > "$b"))    |
|      >=       | 大于等于(需要双括号),如: (("$a" >= "$b")) |

## 逻辑判断

| 操作 | 说明 |
| :--: | :--: |
|  -a  |  与  |
|  -o  |  或  |
|  !   |  非  |

## 条件变量替换

Bash Shell 可以进行变量的条件替换,既只有某种条件发生时才进行替换,替换条件放在 {} 中

1. `${value:-word}`

   当变量未定义或者值为空时,返回值为 word 的内容,否则返回变量的值

2. `${value:=word}`

   与前者类似,只是若变量未定义或者值为空时,在返回 word 的值的同时将 word 赋值给 value

3. `${value:?message}`

   若变量以赋值的话,正常替换.否则将消息 message 送到标准错误输出(若此替换出现在 Shell 程序中,那么该程序将终止运行)

4. `${value:+word}`

   若变量已赋值的话,其值才用 word 替换,否则不进行任何替换

5. `${value:offset}, ${value:offset:length}`

   从变量中提取子串,这里 offset 和 length 可以是算术表达式

6. `${ #value}`

   返回变量的字符个数

7. `${value#pattern}, ${value##pattern}`

   去掉 value 中与 pattern 相匹配的部分,条件是 value 的开头与 pattern 相匹配 , # 与 ## 的区别在于一个是最短匹配模式,一个是最长匹配模式

8. `${value%pattern} , ${value%%pattern}`

   与 7 类似,只是是从 value 的尾部于 pattern 相匹配, % 与 %% 的区别与 # 与 ## 一样

9. `${value/pattern/string}, ${value//pattern/string}`

   进行变量内容的替换,把与 pattern 匹配的部分替换为 string 的内容, / 与 // 的区别与上同
