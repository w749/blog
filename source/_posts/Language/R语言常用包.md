---
title: R语言常用包
author: 汪寻
date: 2020-08-22 10:28:29
updated: 2020-08-22 10:53:42
tags:
 - R
categories:
 - Language

---

R语言基础知识以及常用包操作。

<!-- more -->

## 底层基础

### 函数的几个环境以及参数寻址

```r
f <- function(x, label=deparse(x)){
              label
              x <- x+1
              print('这是f函数：', quote = F)
              print(label)
              print(x)
}
f1 <- function(x, label=deparse(x)){
              x <- x+1
              print('这是f1函数：', quote = F)
              print(label)
              print(x)
}
f(1); f1(1)
```

#### 函数的四个环境

* 第一个环境是**全局环境**~当前环境；
* 第二个环境是函数**被定义的环境**，在这里就是当前环境；
* 第三个环境是function的**参数环境**，是一个局部环境参数等号左边是局部变量，等号右边是全局变量、缺省值或者传入的参数；
* 第四个环境是函数在被调用的时候函数体内部运行时内存给分配的**临时环境（堆栈）**，函数运行完成后会被销毁。

#### 参数寻址问题

关于上方两个函数f和f1，结果不同是因为函数体在运行时参数的寻址环境顺序不同导致的，f函数先运行label，函数体未定义label，它就会去参数环境中寻找，发现它等于deparse(x），然后这个x就是参数环境中的另外一个参数，这个参数在调用f的时候被赋值为1（f(1)），所以label就等于“1”，接下来运行第二步x自增1后等于2，第三步第四步print变量时会优先寻址当前运行的环境，label对应“1”，x对应2；关于f1函数，不同的地方是label变量是在x自增之后才被执行的，deparse(x）会优先寻址当前运行环境，结果就是“2”。

#### 参数寻址补充

函数中的参数是**惰性求值**，不执行则不运算，只有在执行或者被调用的时候才会进行运算；函数体执行运算用到变量时若函数体中未定义，参数环境中也未定义，则会向全局环境中寻址；函数在被调用时若有缺省值，则局部参数被调用时会优先使用传入的参数，若未传入参数才会使用缺省值。

### R语言中的复制

分两个部分来讲，**变量的复制和环境的复制**。

首先是**变量的复制**，定义一个变量a指向数据c(1,2,3)，再定义一个变量b指向变量a（实际上是指向变量a指向的数据），这个时候两个变量指向内存中的数据地址是一样的（可以用浅复制来理解，但不建议），接着修改变量a指向的数据，此时再看b并没有发生变化，此时再比较两者会发现指向的数据地址已经不一样了，使用base包中的tracemem函数可以追踪两个变量的地址变化，其实是因为修改a变量时会在内存中把a指向的数据复制一份，随后再对复制的这份数据进行修改（可以理解为先浅复制指向同一内存，赋值时会发生深复制指向不同的内存地址，但不建议）。

其次是**环境的复制**，新建变量a指向一个新环境，随后新建变量b指向a，此时a和b就是环境的内存地址，这里和变量不一样，接着在a环境中定义变量aa，查看b环境时会发现也有aa变量（可以理解为浅复制，不建议）。

这就是R语言中的复制，**不存在深复制和浅复制**这一说，可以用深复制和浅复制的概念来辅助理解，但不要死搬硬套，不然在变量复制的理解上就会产生矛盾。

### RFC4180 csv文件存储协议

**CSV用逗号分隔字段**的基本思想是清楚的，但是当字段数据也可能**包含逗号或者甚至嵌入换行符**时，该想法变得复杂。 CSV实现可能无法处理这些字段数据，或者可能会使用引号来包围字段。**引用并不能解决所有问题**：有些字段可能需要嵌入引号，因此CSV实现可能**包含转义字符或转义序列**。

[**RFC 4180**](https://www.rfc-editor.org/rfc/inline-errata/rfc4180.html)提出了MIME类型（”text/csv”）对于CSV格式的标准，可以作为一般使用的常用定义，满足大多数实现似乎遵循的格式。

1. 每一行记录位于一个单独的行上，用回车换行符CRLF(也就是\r\n)分割。

Each record is located on a separate line, delimited by a line break (CRLF). For example:
aaa,bbb,ccc CRLF
zzz,yyy,xxx CRLF

2. 文件中的最后一行记录可以有结尾回车换行符，也可以没有。

The last record in the file may or may not have an ending line break. For example:
aaa,bbb,ccc CRLF
zzz,yyy,xxx

3. 第一行可以存在一个可选的标题头，格式和普通记录行的格式一样。标题头要包含文件记录字段对应的名称，应该有和记录字段一样的数量。（在MIME类型中，标题头行的存在与否可以通过MIME type中的可选”header”参数指明）

There maybe an optional header line appearing as the first line of the file with the same format as normal record lines. This header will contain names corresponding to the fields in the file and should contain the same number of fields as the records in the rest of the file (the presence or absence of the header line should be indicated via the optional “header” parameter of this MIME type). For example:
field_name,field_name,field_name CRLF
aaa,bbb,ccc CRLF
zzz,yyy,xxx CRLF

4. 在标题头行和普通行每行记录中，会存在一个或多个由半角逗号(,)分隔的字段。整个文件中每行应包含相同数量的字段，空格也是字段的一部分，不应被忽略。每一行记录最后一个字段后不能跟逗号。（通常用逗号分隔，也有其他字符分隔的CSV，需事先约定）

Within the header and each record, there may be one or more fields, separated by commas. Each line should contain the same number of fields throughout the file. Spaces are considered part of a field and should not be ignored. The last field in the record must not be followed by a comma. For example:
aaa,bbb,ccc

5. 每个字段可用也可不用半角双引号(“)括起来（不过有些程序，如Microsoft的Excel就根本不用双引号）。如果字段没有用引号括起来，那么该字段内部不能出现双引号字符。

Each field may or may not be enclosed in double quotes (however some programs, such as Microsoft Excel, do not use double quotes at all). If fields are not enclosed with double quotes, then double quotes may not appear inside the fields. For example:
"aaa","bbb","ccc" CRLF
zzz,yyy,xxx

6. 字段中若包含回车换行符、双引号或者逗号，该字段需要用双引号括起来。

Fields containing line breaks (CRLF), double quotes, and commas should be enclosed in double-quotes. For example:
"aaa","b CRLF
bb","ccc" CRLF
zzz,yyy,xxx

7. 如果用双引号括字段，那么出现在字段内的双引号前必须加一个双引号进行转义。

If double-quotes are used to enclose fields, then a double-quote appearing inside a field must be escaped by preceding it with another double quote. For example:
"aaa","b""bb","ccc"

**补充：R语言**在这里设置的比较好，默认write.csv的时候会有quote参数设置是否需要将元素用双引号括起来，元素中出现的双引号会默认添加"转义，对于换行符这些则需要添加反斜杠进行转义，read.csv读取的时候也会按这个协议进行读取。

## 技术问题

### 导入包

```r
knitr::opts_chunk$set(echo = TRUE)
library(dplyr, warn.conflicts = F)
library(tidyr, warn.conflicts = F)
library(pryr, warn.conflicts = F)
library(purrr, warn.conflicts = F)
library(elastic, warn.conflicts = F)
library(esHelp)
exprs <- rlang::exprs
```

### grep和grepl的区别

grep查询结果为**整个向量**、列表等数据中是否含有并返回一个逻辑值，grepl查询返回结果为**每个元素对应的**T或者F:

```r
grep('youzan', c('youzanw', 'fsew'))  # 查询youzan在向量中的结果返回单个T
grepl('youzan', c('youzanw', 'fsew'))  # 查询结果则返回每个元素对应的T或者F
```

### gsub、replace替换操作

替换每个元素中的字符或数字，替换结果为字符串**使用gsub**，当然，也可以使用正则表达式

```r
# 替换字符串中的字符
a <- c('i am hungry', 'you are xxx')
gsub(' ', '-', a)

# 替换数字，返回结果为字符串
b <- c(1, 3, 2, 7, 2)
gsub(2, 222, b)
```

替换指定位置的元素或者指定条件的元素**使用replace**

```r
# 替换指定位置元素
a <- c('i am hungry', 'you are xxx', 'abcde')
replace(a, c(1,2), 222)

# 替换指定条件元素
b <- c(1, 3, -5, 7, -9)
replace(b, b<0, 222)

# 也可以使用ifelse实现
ifelse(b<0, 222, b)
```

### 行转列spread和列转行gather

* 行转列将某一字段中的值提到col中，并将对应的value值reshape，列转行将col转到单个字段中并将原col对应的值一一映射。

```r
stocks <- tibble(time = as.Date('2009-01-01') + 0:9,
                X = rnorm(10, 0, 1),
                Y = rnorm(10, 0, 2),
                Z = rnorm(10, 0, 4)
)
stocks  # 原始数据

# gather列转行，指定需转为行的列名，再指定key对应colname，value对应value的colname
a <- stocks %>% gather('X', 'Y', 'Z', key='stock', value='price'); a

# spread行转列，指定需要转的key对应col，把它转为原始状态
a %>% spread(key='stock', value='price')
```

### 环境空间操作

环境空间的**基本操作**以及空间内变量的基本操作

```r
# 创建一个新环境
env1 <- new.env()

# 判断是否是一个环境变量
is.environment(env1)

# 查看当前环境变量
environment()

# 查看函数中的环境空间
environment(ls)

# 查看环境空间的名字
environmentName(baseenv())
environmentName(environment())

# 设置环境变量的名字，默认创建出来是没有名字的
attr(env1, 'name') <- 'env1'

# 查看环境变量的属性值
env.profile(env1)
```

#### 环境空间中的变量

```r
# 清空当前环境空间定义的所有对象
rm(list=ls())

# 定义环境空间中的变量
x <- 1.5; y <- 2:10
env1 <- new.env()
env1$x <- -10

# 查看env1环境变量中的变量
ls(env1)

# 环境空间变量取值
get('x', envir=env1)  # 取env1环境变量中的x值
get('y', envir=env1)  # 从env1环境空间中取从当前环境中继承的y值
# get('y', envir=env1, inherits=FALSE)  # 禁止环境空间的继承，会报错

# 重新赋值
assign('x', 77); x  # 重新赋值当前环境变量中的x值
assign('x', 99, envir=env1); env1$x  # 重新赋值环境空间中的x值
assign('y', 333, envir=env1, inherits=FALSE)  # 在没有继承的情况下给环境空间中的y赋值

# 删除env1中的变量
rm(x, envir=env1)

# 变量在环境变量中是否存在
exists('x')
exists('x', envir=env1)
# exists('y', envir=env1, isherits=FALSE)  # 在没有继承的情况下y是否存在，会报错

# 查看函数的环境空间，来自pryr包
where('mean')
where('where')
```

#### 管理工作空间

```r
# setwd('/Users/mac/python/R')  # 修改工作目录为
getwd()  # 显示当前工作目录
ls()  # 列出当前工作空间中的对象
search()  # 查看已载入的包
q()  # 退出R
library()  # 查看已安装的包
options()  # 显示或设置当前选项
history()  # 显示最近使用过的指令数量，默认25个
savehistory('myfile')  # 保存命令历史到myfile文件中
loadhistory('myfile')  # 载入一个命令历史文件
save.image('myfile')  # 保存工作空间到myfile中
save(objectlist, file='myfile')  # 保存指定对象到myfile中
load('myfile')  # 从myfile中读取一个工作空间
```

### 将多个df写入excel的不同位置

```r
# path为不带文件名的文件路径
# file_name为带后缀的文件名
# souce_aw,all_aw,source_dell,all_dell均为df

# 判断是否存在文件，若存在则删除
if(file.exists(paste(path, file_name, sep=""))){
  file.remove(paste(path, file_name, sep=""))
}

# 建立空工作簿
dt_wb <- createWorkbook() 

# write_data(sheet_name, df, start_row, start_col)防止搞混这两个参数使用参数名赋值
write_data('aw', souce_aw, start_col=1, start_row=1)
write_data('aw', all_aw, start_col=2, start_row=(nrow(souce_aw)+3))
write_data('dell', souce_dell, start_col=1,start_row=1)
write_data('dell', all_dell, start_col=2, start_row=(nrow(souce_dell)+3))

# 保存数据到工作簿中
saveWorkbook(dt_wb, file=paste(path, file_name, sep="")) 
```

### apply家族

apply函数族是R语言中数据处理的一组核心函数，通过使用apply函数，我们可以实现对数据的**循环、分组、过滤、类型控制**等操作。

* **分组计算**：apply（按col/row计算）、tapply（按字段groupby计算）
* **循环迭代**：lapply、sapply（lapply简化版）、vapply（sapply可设置rownames）、rapply（lapply的递归版）、mapply（sapply的多参数版）
* **环境空间遍历**：eapply

#### apply函数

apply函数是最常用的代替for循环的函数。apply函数可以对矩阵、数据框、数组(二维、多维)，按行或列进行循环计算，**对子元素进行迭代，把子元素以参数传递的形式给自定义的FUN函数中，并返回计算结果**。

* apply(X, MARGIN, FUN, ...)
* X:数组、矩阵、数据框
* MARGIN: 按行计算或按按列计算，1表示按行，2表示按列
* FUN: 自定义的调用函数
* …: 更多参数，可选

```r
# 最简单的实现，按行求和返回向量
x <- matrix(1:12, ncol=3)
apply(x, 1, sum)

# 自定义函数实现新增计算字段
myfun <- function(x, c1, c2){
  c(sum(x[c1],1), mean(x[c2]))
}
x <- cbind(x1 = 3, x2 = c(4:1, 2:5))
apply(x, 1, myfun, c1='x1', c2=c('x1','x2'))
```

#### lapply函数

lapply函数是一个最基础循环操作函数之一，用来**对list、data.frame数据集进行循环，并返回和X长度同样的list结构**作为结果集，通过lapply的开头的第一个字母’l’就可以判断返回结果集的类型为list。

* lapply(X, FUN, ...)
* X:list、data.frame数据
* FUN: 自定义的调用函数
* …: 更多参数，可选

```r
# 返回列表中每个key对应value的分位数
x <- list(a=c(1:10), b=c(1.2,2.3,3.4,4.5), c=c(5:-3))
lapply(x, fivenum)

# 当x为df时会自动分组计算并返回list
x <- data.frame(x1 = 3, x2 = c(4:1, 2:5))
lapply(x, sum)
```

#### sapply函数

sapply函数是一个**简化版的lapply**，sapply增加了2个参数simplify和USE.NAMES，主要就是让输出看起来更友好，**返回值为向量**，而不是list对象，它调用lapply函数，然后在它的基础上进行转换。

* sapply(X, FUN, ..., simplify=TRUE, USE.NAMES = TRUE)
* X:数组、矩阵、数据框
* FUN: 自定义的调用函数
* …: 更多参数，可选
* simplify: 是否数组化，当值array时，输出结果按数组进行分组
* USE.NAMES: 如果X为字符串，TRUE设置字符串为数据名，FALSE不设置

```r
# 对矩阵进行计算，过程和lapply相同
x <- cbind(x1=3, x2=c(2:1,4:5))
sapply(x, sum)

# 对df进行计算
sapply(data.frame(x), sum)

# 检查结果类型，sapply返回类型为向量，而lapply的返回类型为list
class(lapply(x, sum))
class(sapply(x, sum))

# 当返回结果为多个元素时会转为array
sapply(x, fivenum)

# 对字符型向量可自动生成数据名，设置USE.NAMES为FALSE即可
sapply(sample(letters,5), paste, USE.NAMES=TRUE)
```

#### vapply函数

vapply**类似于sapply**，提供了FUN.VALUE参数，用来**控制返回值的行名**，这样可以让程序更健壮。

* vapply(X, FUN, FUN.VALUE, ..., USE.NAMES = TRUE)
* X:数组、矩阵、数据框
* FUN: 自定义的调用函数
* FUN.VALUE: 定义返回值的行名row.names
* …: 更多参数，可选
* USE.NAMES: 如果X为字符串，TRUE设置字符串为数据名，FALSE不设置

```r
# 对数据框的数据进行累计求和，并对每一行设置行名row.names
x <- data.frame(cbind(x1=3, x2=c(2:1,4:5)))
vapply(x,cumsum,FUN.VALUE=c('a'=0,'b'=0,'c'=0,'d'=0))
```

#### mapply函数

mapply也是sapply的变形函数，类似**多变量的sapply**，但是参数定义有些变化。第一参数为自定义的FUN函数，第二个参数’…’可以接收多个数据，作为FUN函数的参数调用。

* mapply(FUN, ..., MoreArgs = NULL, SIMPLIFY = TRUE,USE.NAMES = TRUE)
* FUN: 自定义的调用函数
* …: 接收多个数据
* MoreArgs: 参数列表
* SIMPLIFY: 是否数组化，当值array时，输出结果按数组进行分组
* USE.NAMES: 如果X为字符串，TRUE设置字符串为数据名，FALSE不设置

```r
# 按列对多个参数进行求和
x <- data.frame(x1=c(1,2), x2=c(3,4))
y <- data.frame(y1=c(5,6), y2=c(7,8))
mapply(sum, x, y)
```

#### tapply函数

tapply用于分组的循环计算，**通过INDEX参数可以把数据集X进行分组，相当于group by的操作**。

* tapply(X, INDEX, FUN = NULL, ..., simplify = TRUE)
* X: 向量
* INDEX: 用于分组的索引
* FUN: 自定义的调用函数
* …: 接收多个数据
* simplify : 是否数组化，当值array时，输出结果按数组进行分组

```r
# 对df进行groupby计算，按x1对x2进行求和
x <- data.frame(x1=c('A','B','A','B'), x2=1:4)
with(x, {
  tapply(x2, x1, sum)
})

# 特殊需求，对数字范围进行分组
tapply(1:10, ceiling(1:10/3), function(x) x)
```

#### rapply函数

rapply是一个**递归版本的lapply，它只处理list类型数据**，对list的每个元素进行递归遍历，如果list包括子元素则继续遍历。

* rapply(object, f, classes = "ANY", deflt = NULL, how = c("unlist", "replace", "list"), ...)
* object:list数据
* f: 自定义的调用函数
* classes : 匹配类型, ANY为所有类型
* deflt: 非匹配类型的默认值
* how: 3种操作方式，当为replace时，则用调用f后的结果替换原list中原来的元素；当为list时，新建一个list，类型匹配调用f函数，不匹配赋值为deflt；当为unlist时，会执行一次unlist(recursive = TRUE)的操作
* …: 更多参数，可选

```r
# 对一个list进行guolv，返回每一个元素的最小值，注意how参数的选取对应不同的返回结果
x <- list(x1=c(1,2,3), x2=c(5,-5,10))
y <- pi
z <- data.frame(z1=100, z2=c(11,22,33))
lst <- list(x=x, y=y, z=z)

rapply(lst, min, how='list')

# classes参数用来匹配类型，与类型相匹配的元素执行函数，其余返回deflt参数值
z <- sample(letters, 5)
lst <- list(x, y, z)
rapply(lst, function(x) paste(x, '---'), classes='character')
```

#### eapply函数

对一个**环境空间中的所有变量**进行遍历。

* eapply(env, FUN, ..., all.names = FALSE, USE.NAMES = TRUE)
* env: 环境空间
* FUN: 自定义的调用函数
* …: 更多参数，可选
* all.names: 匹配类型, ANY为所有类型
* USE.NAMES: 如果X为字符串，TRUE设置字符串为数据名，FALSE不设置

```r
# 新建环境并定义三个变量
env1 <- new.env()
env1$x <- c(1:10)
env1$y <- pi
env1$z <- data.frame(z1=100, z2=c(11,22,33))  # 当然它直接求不了均值

# 计算环境下所有变量的均值
eapply(env1, mean)

# 计算环境下所有变量的占用内存大小
eapply(env1, object.size)
```

### split和unsplit

split**将向量x中的数据按照f定义的分组**进行划分，替换该划分所对应的值。unsplit反转split的效果。

* split(x, f, drop = FALSE, ...)
* x:vector or data frame containing values to be divided into groups.
* f:a ‘factor’ in the sense that as.factor(f) defines the grouping, or a list of such factors in which case their interaction is used for the grouping.
* drop:logical indicating if levels that do not occur should be dropped (if f is a factor or a list).

```r
# 按a1对df进行分组，将结果对应返回在一个列表中
x <- data.frame(x1=c('A','A','B'), x2=1:3)
split(x, x$x1)

# unsplit是将split输出的结果按x1进行反向操作将它们合起来
unsplit(split(x, x$x1), x$x1)
```

### R中的表达式

虽然我们在R终端键入的任何有效语句都是表达式，但这些表达式在输入后即被求值（evaluate）了，获得未经求值的纯粹“表达式”就要使用函数。下面我们从函数参数和返回值两方面了解expression、quote、bquote和substitute这几个常用函数。

#### expression和quote函数

expression函数可以有一个或多个参数，它把全部参数当成一个列表，每个参数都被转成一个表达式向量，所以它的返回值是表达式列表，每个元素都是表达式类型对象，返回值的长度等于参数的个数：

```r
# expression形成两个表达式并通过eval索引不同表达式赋值返回结果
a <- expression(x * y, x + y)
b <- list(x=10, y=10)
eval(a[1], b); eval(a[2], b)
```

quote函数只能有一个参数。quote函数的返回值一般情况下是call类型，表达式参数是单个变量的话返回值就是name类型，如果是常量那么返回值的存储模式就和相应常量的模式相同：

```r
# quote构建表达式并使用eval传参计算
a <- quote(x * y)
b <- list(x=2, y=10)
eval(a, b)
```

#### bquote和substitute函数

如果不使用环境变量或环境变量参数，bquote 和 substitute 函数得到的结果与quote函数相同。

```r
# 比较三个表达式函数
bquote(1 + sqrt(a)) == quote(1 + sqrt(a)); substitute(1 + sqrt(a)) == quote(1 + sqrt(a))

# 两者的不同之处在于赋值方式的不同，一般使用substitute
a <- 3 ; b <- 2 
bquote(y == sqrt(.(a), .(b))); substitute(y == sqrt(a, b), list(a = 3, b = 2))
```

### df删除重复行

第一种方法利用**group_by结合row_number**函数对行进行排序，然后选取row_number为1的行则可达到删除其他重复值的效果。

```r
x <- data.frame(a=c('A','B','A','A','C'), b=c(1,2,3,4,5)); x
x %>% group_by(a) %>% filter(row_number(a)==1) %>% ungroup
```

第二种方法是利用自带的**duplicated和distinct**函数

```r
x <- data.frame(a=c('A','B','A','A','C'), b=c(1,2,3,4,5))
# duplicated返回逻辑值，需用到索引中
x[duplicated(a), ]
# distinct函数需指定.keep_all参数为TRUE才会返回其他字段
x %>% distinct(a, .keep_all=T)
# 还有一个unique函数返回某一列的唯一值，这和python中一样
unique(x$a)
```

### partial传参和compose组合函数

partial用来**对已有函数传入一定数量的参数**形成一个类似function的partialised对象，你可以调用这个对象再次传参，就像使用函数一样使用它，这对于一些需要指定不同参数的场景特别适用。

```r
# 定义一个函数然后然后给它先传入两个参数，再次调用的时候再传入一个参数就可以了
a <- function(x, y, z) {
  return(x+y+z)
}
b <- partial(a, x=1, y=2); b
b(z=3)
```

compose的作用是组合多个函数，默认从后往前的顺序执行函数。注意需传入函数function，而不是公式formula（~）

```r
a <- compose(function(x) paste(x,'foo'), function(x) paste(x,'bar'))
a(x='input')
```

### !!、!!!和~公式

!!作用是**使用外部环境的参数或者变量**，在%>%的过程中使用外部变量前指定!!，还有就是在函数中使用rename的时候在参数前加!!，这和R语言在特定情况下字符串不用加双引号有关。

```r
# 使用函数更名，在x重复的时候加!!指定左边的x使用参数，而不是字符串x
re_func <- function(data,x,y) rename(data, !!x:=x, !!y:=y)
a <- data.frame(x=rep(1:2, each=3), y=1:6, z=6:1)
re_func(data=a, x='xx', y='yy')
```

**!!!作用是解包**，一般针对于list类型的数据或准则exprs函数形成的list数据类型，在变量名称前加!!!，在有些情况下这是必须的。

```r
a <- list(
  exprs(x=1, y=2, z=3), 
  exprs(x=9, y=8, z=7)
)
b <- function(x,y,z) x
map(a, ~ paste(.x))
```

~在R语言中是**formula公式类型**，在map等其他函数中中可以当做匿名函数来使用，调用的参数位置使用.x和.y来指定。但当函数内部指定f必须为function时，则不能使用~公式替代function。

```r
a <- list(
  c(1,2,3), 
  c(4,5,6)
)
b <- list(
  c('a','b','c'), 
  c('d','e','f')
)
map(a, ~ sum(.x))
map2(a, b, ~ paste(.x,.y))
```

### expr系列、sym系列和quo系列

这三个系列都属于表达式的范畴，原理基本相同，只是在应用场景上有所不同。需要注意的是exprs、quo、get_env、get_expr和eval_tidy函数都属于rlang包，其余的则属于dplyr包。
先来看**expr系列**，这也是最常用的，适用于接受参数的场景，包括expr、exprs、enexpr、enexprs。expr和enexpr针对单个表达式或者参数，加s针对多个并返回列表；expr和exprs捕获你输入给它的表达式，enexpr和enexprs用于捕获外部输入的表达式。

```r
# 先来看expr和exprs，捕获输入的参数，输入什么返回什么
expr(hello); exprs(hello, 'world', say(hello))

# 接下来是enexpr和enexprs，捕获外部传入的参数，用expr和enexpr举个例子
a <- function(arg) {
  a <- expr(arg)
  b <- enexpr(arg)
  paste(a, b)
}
a(hello)

# 接下来是使用!!传入参数所对应的数据，当然如果传入hello是字符串就只会返回字符串了
hello <- 333
b <- function(arg) {
  b <- expr(!!arg)
  b
}
b(hello)
```

**sym系列**的作用和expr差不多，但是**只接受传入字符串类型**，传入符号会报错，syms的传参方式也略有不同

```r
# sym和base包中的quote差不多，syms需使用list传入字符串
sym('a'); syms(list('a', 'b'))

# ensyms也是接收传入的参数，只接受字符串类型
hello <- 'world'
a <- function(...) {
  a <- ensyms(...)
  a
}
a(he, 'llo', !!hello)
```

最后是**quo系列，它是一个包含环境的表达式**，而且要用到自带的eval_tidy函数进行求值。

```r
# quo定义了一个包含表达式和当前环境的对象，使用get_expr和get_env可以取出表达式和所在的环境
quo_eg <- rlang::quo(sample(letters, 5))
quo_eg; rlang::get_expr(quo_eg); rlang::get_env(quo_eg)

# 接下来使用enquo在函数环境中接受参数，和函数空间中的变量运算后返回值
a <- function(arg) {
  a <- enquo(arg)
  b <- 10
  rlang::quo(!!a * b)
}
# 计算它的时候它调用的是函数内部的a和b，env指的也是函数的内部环境
a(2+3); a(2+3) %>% rlang::eval_tidy()
```

### map、reduce和map_df

map函数是将x中的每一个元素进行函数计算，map(1:3,f)等价于list(f(1),f(2),f(3))，相当于任务的分解，分发，而reduce是重复进行函数操作，相当于组合。
将map、reduce和map_df放在一起说是因为在特定情况下两个函数可以实现的结果是相同的，其他的map函数需要的时候再去查。

```r
# 使用map函数实现分而治之
a <- c(1,2,3)
map(a, ~paste(.x, 'ww'))

# map结合reduce实现先分发再组合
map(a, ~paste(.x, 'ww')) %>% reduce(., paste)

# map_df会把计算后的结果拼接起来，省略了reeduce的操作，但只限于数据框
a <- tibble(x=c('d','a','a','b','b','c','c','c'), 
            y=c(1,1,1,2,2,1,3,3), 
            z=c(1,2,3,4,5,6,7,8))
# 将a按y分成多个list元素，然后再分别对每个元素进行group_by计算，最后map_df会自动给我们把计算结果合并起来
a %>% split(.$y) %>% map_df(., ~group_by(.,.$x) %>% summarise(sum=sum(z)))
# 再来看看map、reduce的计算结果，是一样的
a %>% split(.$y) %>% map(., ~group_by(.,.$x) %>% summarise(sum=sum(z))) %>% reduce(rbind)
```

map_df这种情况适用于分批次查询或者计算MySQL数据库的时候，会减少数据库的查询压力，当然得结果split(data, ceiling(1:len(data)/n))来使用，它会将数据将数据转换成list中的元素，每个元素长度为n，然后依次排列，这样就达到了分批次（每次执行数量为n）进行查询或者计算操作了。

### ES查询相关

ES的查询需要借助到elastic库和esHelp库，elastic库主要是建立连接并查询返回，esHelp库则着重于查询条件body的辅助编写，使用它可以快速形成json格式的查询条件。

#### 建立连接和数据转换

```r
# 使用elastic库带的connect方法建立连接
con_51 <- connect(host = "47.92.156.202", user = 'readonly', pwd = 'wczyyqc', port = '9201')

# 查询后的数据整理，基本可以用着一个函数转换
modifydata <- function(x) map(x, "_source") %>% transpose %>%  map(unlist) %>% as_tibble()
```

#### 查询语句body的编写

```r
# 查询语句有两种写法，层层嵌套和快速生成
stime <- '2020-11-01 00:00:00'
stime <- '2020-11-01 23:59:59'
es_a <- elastic_q(query(bool(filter(between(local_time, stime, etime),
                                            event %in% c('subscribe', "SCAN"),
                                            route=="pages/index/index",
                                            ?options.fromopenid)))%+%
                            elastic_s(list("openid","local_time"))) 
es_b <- bool_query(between(local_time, stime, etime),
                                            event %in% c('subscribe', "SCAN"),
                                            route=="pages/index/index",
                                            ?options.fromopenid) %+% 
        list(`_source`= c("openid","local_time"))

# 上方两种写法的结果是一样的(1.1版本)，看看转成json后的结果
es_a = es_b; es_b %>% jsonlite::toJSON(pretty = T)
```

因为esHelp版本问题，结果应该如下文所示，意思是筛选local_time从stime到etime，event字段包含"subscribe","SCAN"，是否存在"options.fromopenid"字段并最终取出"openid","local_time"字段

```json
{
    "query":{
        "bool":{
            "filter":[
                {
                    "range":{
                        "local_time":{
                            "gte":["2020-11-01 00:00:00"],
                            "lte":["2020-11-01 23:59:59"]
                        }
                    }
                },
                {
                    "terms":{
                        "event":["subscribe","SCAN"]
                    }
                },
                {
                    "term":{
                        "route":["pages/index/index"]
                    }
                },
                {
                    "exists":{
                        "field":["options.fromopenid"]
                    }
                }
            ]
        }
    },
    "_source":["openid","local_time"]
}
```

#### 查询语句的传入

使用elastic自带的函数传入相关参数后再转换即可

```r
# 传入上方的连接con，index（db）， type（table）和body参数，再把data传入modifydata中即可得到二维数据。
es_tmp_exp  <- function(con = NULL,  index= NULL, body= NULL, time_scroll= '10s',... )
{

  res <- Search(conn = con, index= index, body= body, size = 10000,  time_scroll= time_scroll,...)
  on.exit(expr = scroll_clear(conn = con, x = res$`_scroll_id`))

  data <- list()

  while (T) {

    data <-  c(data, res$hits$hits)  

    res <- scroll(conn = con, x= res$`_scroll_id` , time_scroll= time_scroll)

    if (length(res$hits$hits) ==0 ){
      break 
    }

  }

  return(data)

}
```

### 发送邮件

通过mailR库发送邮件，只需要一个主体即可把所有参数全部传完。

```r
library(mailR)
  mailR::send.mail(from = "eub_bi@eub-inc.com",  # 发件人
                   to = "di.cui@eub-inc.com",  # 收件人
                   cc =c("frank@eub-inc.com", "xukun.wang@eub-inc.com"),  # 抄送人
                   subject = "dell&aw仍在关粉丝人群渠道分布",  # 邮件主题
                   body = c("Dear all，
                     dell&aw仍在关粉丝人群渠道分布数据如下附件，请注意查收。"),  # 邮件内容
                   smtp = list(host.name = "smtp.exmail.qq.com", port =25,user.name="eub_bi@eub-inc.com",
                               passwd = "Eubbi0719", ssl =TRUE,tls=FALSE),  # 邮箱的host name 和passwd配置
                   authenticate = TRUE,
                   send = TRUE,  # 是否立即发送
                   attach.files = path,  # 附件地址
                   encoding = "utf-8")
```

### R脚本运行自检测

检测R脚本是否可以在初始环境中运行
首先在Rstudio中按Common/Ctrl+Shift+F10键重启环境，这时只有初始的环境，使用search命令查看基础包
然后在终端中键入Rscript 脚本名称来测试脚本是否可以运行，若不可以运行应该是缺少相关依赖包，导入即可

### 打包数据

使用base库自带的list.files和zip即可完成打包

```r
# path为需要打包的所有文件的上级目录
path <- '/home/dingtao/wangxukun/data/dell/dell_scan_subcribe_log/'
path_name <- list.files(path)
zip('filename.zip', path_name)
```

### 解析json字符串

要解决的是解析tibble中某一列存在json字符串的情况

```r
# 使用map的时候需要把空字符串筛掉 不然会报错 在map中加上mutate会找到解析后对应的字符串
address <- c(
'{"nationalCode":"440402","telNumber":"13539585518","errMsg":"chooseAddress:ok","userName":"侯艳玲","postalCode":"519000","provinceName":"广东省","cityName":"珠海市","countyName":"香洲区","detailInfo":"泰来花园商铺19号 黄拯邦中医诊所"}',
'{"errMsg":"chooseAddress:ok","userName":"韩嘉乐","telNumber":"19826080561","nationalCode":"320322","postalCode":"221600","provinceName":"江苏省","cityName":"徐州市","countyName":"沛县","detailInfo":"龙固镇"}',
'{"errMsg":"chooseAddress:ok","userName":"宋俊纬","telNumber":"13355332907","nationalCode":"370305","postalCode":"255400","provinceName":"山东省","cityName":"淄博市","countyName":"临淄区","detailInfo":"绿茵花园"}')

a <- tibble(address=address)
a$address %>% map_df(., ~jsonlite::fromJSON(..1) %>% as_tibble() %>% mutate(address=..1))
```

### S3类&泛型函数

- S3类内部是一个列表，附加一个列表类名称，可以成为该类。list里面的内容就是我们所说的属性；
- S3类可以继承，在原来类的基础上再append一个新的类名即为新的类；
- 类中除了含有属性外，肯定还得含有方法。使用某方法.某类来创建某类的方法。比如print.gg就是对gg类的print的方法。但是在创建这种方法之前我们首先得用这个方法的名字创建一个函数，这样运行函数时首先进入这个函数，然后在函数里面使用useMethod函数，在环境中寻找该类的该方法；
- default函数，表示默认的方法，如果该类找不到该类匹配的方法，就会使用默认方法；
- 调用方法的时候会按照从左到右的顺序，再这个例子中，默认先调用a的方法，如果想要调用f类的方法，首先写一个f的qwe方法，然后在a类中调用下一类的方法，使用NextMethod。

```r
# 构建S3类
dd <- function(sep='abc',arg=10) {  # 创建一个S3类
  ls <- list(
      sep = sep,
    arg = arg
  )
  class(ls) <- append(class(ls), 'dd')
  return(ls)
}
dd()
dd('qaz',100)  # 类的实例化

# 类继承
ddd <- dd()
class(ddd) <- append(class(ddd), 'cc')  # S3类可以继承，在原来类的基础上再append一个新的类名即为新的类

# 在父类中使用子类的方法
a <- list(d='求和')
b <- list(d='平均值')
d <- list(d='中位值')

aa <- function() structure(a, class='a')  # 给属性列表自定义class属性值a
bb <- function() structure(b, class='b')
dd <- function() structure(b, class='d')
ff <- aa()
class(ff) <- append(class(ff), 'f')

qwe <- function(x) UseMethod('qwe')
qwe.a <- function(x) {
  print('我是a类型')
  NextMethod('qwe')  # 使用NextMothod函数调用a类型的子类，
  x$d  # 只有上方代码是调用子类，这里仍然是调用a类型
}
qwe.f <- function(x) print('我是f类型')

qwe(ff)  # （我是a类型 我是f类型 求和）使用NextMethod方法后调用子类方法

# 构建S3类的泛型函数

ab <- function(x) UseMethod('ab')  # 创建泛型函数
ab.default <- function(x) 'default'  # 默认函数
ab.a <- function(x) x$d  # 根据不同的class属性值创建不同的泛型函数
ab.b <- function(x) x$d

ab(aa())  # （求和）这样在给泛型函数传入不同属性的列表参数就会运行对应属性的泛型函数
ab(bb())  # （平均值）
ab(dd())  # （default）没有对应d的方法，调用默认函数
```

### stringr包

```r
# boundary用修饰符函数控制匹配行为
boundary(type = c("character", "line_break", "sentence", "word"), skip_word_none = NA, ...)

# str_detect判断子字符串是否存在于目标字符串中，返回TURE或FALSE
str_detect('abcde', 'dcd')  # TRUE

# str_count判断字符/单词长度
str_count('abc _de')  # 7，默认计算字符长度
str_count('abc _de', boundary('character'))  # 7
str_count('abc _de', boundary('character'))  # 2，返回单词长度，数字、字符和下划线被认为是一个单词

# str_split拆分字符串
str_split('as b-+_1','-') %>% unlist()  # "as b" "+_1" ，按指定字符串拆分
str_split('as b-+_1','') %>% unlist()  # "a" "s" " " "b" "-" "+" "_" "1"，拆分为单个字符
str_split('qbc 1ff+2eqw_we', boundary('word')) %>% unlist()  # "qbc" "1ff" "2eqw_we"，按单词分隔

# str_extract_all按正则表达式提取所有符合条件的子字符串，str_extract只提取第一个
str_extract_all("The Cat in the Hat", "[a-z]+") %>% unlist()  # "he"  "at"  "in"  "the" "at" 
str_extract_all("The Cat in the Hat", "at") %>% unlist()  # "at" "at"
str_extract("The Cat in the Hat", "[a-z]+") %>% unlist()  # "he"
str_extract("The Cat in the Hat", "at") %>% unlist()  # "at"

# str_c将多个字符串连接成一个字符串
str_c('+',c('a','b','c'),':')  # "+a:" "+b:" "+c:"，将多个字符串连接成一个字符串
str_c(c('a','b','c'), 1,':',sep='-')  # "a-1-:" "b-1-:" "c-1-:"，使用sep连接
str_c(c('a','b','c'),':',sep='-',collapse = '')  # "a-:b-:c-:"，拼接完成后将所有字符串连接在一起

# str_glue格式化并使用glue插入一个字符串
name <- "Fred"
anniversary <- as.Date("1991-10-12")
str_glue(
  "My name is {name}, ",
  "and my anniversary is {format(anniversary, '%A, %B %d, %Y')}."
)  # My name is Fred, and my anniversary is Saturday, October 12, 1991.
mtcars %>% str_glue_data("{rownames(.)} has {hp} hp")  # 针对dataframe的字符串格式化，按行输出

# str_locate定位子串在字符串中的位置，返回一个列表
fruit <- c("apple", "banana", "pear", "pineapple")
str_locate(fruit, "$")
str_locate(fruit, "a")
str_locate(fruit, "e")
str_locate(fruit, c("a", "b", "p", "p"))
str_locate_all(fruit, "a")  # 返回子串所在的所有位置
str_locate_all(fruit, "e")
str_locate_all(fruit, c("a", "b", "p", "p"))

# str_remove删掉匹配到的子串，支持正则表达式
fruits <- c("one apple", "two pears", "three bananas")
str_remove(fruits, "[aeiou]")  # "ne apple"     "tw pears"     "thre bananas"
str_remove_all(fruits, "[aeiou]")  # "n ppl"    "tw prs"   "thr bnns"

# str_trunc截断一个字符串
x <- "This string is moderately long"
rbind(
  str_trunc(x, 20, "right"),  # "This string is mo..."
  str_trunc(x, 20, "left"),  # "...s moderately long"
  str_trunc(x, 20, "center")  # "This stri...ely long"
)

str_to_upper('asd asd qafdwe')  # "ASD ASD QAFDWE"，转换为大写
str_to_title('qweq wer wr')  # "Qweq Wer Wr"，首字母转换为大写
regex('[0-9]')  # 生成正则表达式，有些函数支持输入正则表达式，就不用这个了
str_dup(c('ab','bc','cd'),2)  # "abab" "bcbc" "cdcd"，重复每个元素指定次数
str_ends(c('abc','abe','cde'), 'e')  # FALSE  TRUE  TRUE，检查字符串结尾是否为某个子字符串
str_starts(c('abc','abe','cde'), 'a')  # TRUE  TRUE  FALSE，检查字符串开头是否为某个子字符串
str_flatten(c('a','b','c'))  # "abc"，将字符串从头到尾全部连接起来，可以指定collapse相当于sep
str_length(c("i", "like", NA))  # 1  4 NA，返回字符串的长度
str_order(c('b','c','a'))  # 3 1 2，按字符索引进行排序
str_sort(c('b','c','a'))  # "a" "b" "c"，对字符进行排序
str_replace(c('abc','bca','ccc','bbb'),'b','-')  # "a-c" "-ca" "ccc" "-bb"，替换第一个字符
str_replace_all(c('abc','bca','ccc','bbb'),'b','-')  # "a-c" "-ca" "ccc" "---"，替换所有字符
str_replace_na(c(NA, "abc", "def"),'ccc')  # "ccc" "abc" "def"，替换空值
str_trim(' qwe ')  # "qwe"，默认删掉字符串两边空格，可以指定side为left或者right
str_pad(string='abc', side='both', width='10', pad='-')  # "---abc----"，字符串填充
str_squish("\t \n\nString \n space\n\n ")  # "String space"，删掉字符串中的无用字符（空格、换行等）
str_sub('string', start=1L, end=3)  # "str"，根据位置截取字符串，end为-1截取所有字符串
```

### openxlsx包

```r
# writeData写入数据到工作不对象的sheet中，以及常用的参数，write.xlsx直接写入文件
writeData(wb,'ss',dd)  # 普通的写入
writeData(
  wb,  # 工作簿对象
  sheet,  # sheet名字
  x,  # 数据
  startCol = 1,  # 数据写入的开始列
  startRow = 1,  # 开始行
  colNames = TRUE,  # 是否包含列名
  rowNames = FALSE,  # 是否包含行名
  headerStyle = NULL,  # columns的自定义样式，插入一个addStyle样式
  borders = c("none", "surrounding", "rows", "columns", "all"),  # 四周边框
  borderColour = getOption("openxlsx.borderColour", "black"),  # 边框颜色
  borderStyle = getOption("openxlsx.borderStyle", "thin"),  # 边框样式
  na.string = NULL,  # 若有NA值，则全部填充为这个值
)

# createStyle新建样式，在插入数据的时候使用
createStyle(
  fontName = NULL,  # 字体名称
  fontSize = NULL,  # 字体大小
  fontColour = NULL,  # 字体颜色
  numFmt = "GENERAL",  # 格式化数据
  border = NULL,  # 四周边框
  borderColour = getOption("openxlsx.borderColour", "black"),  # 边框颜色
  borderStyle = getOption("openxlsx.borderStyle", "thin"),  # 边框样式
  bgFill = NULL,  # 单元格背景颜色
  halign = NULL,  # 单元格内容的水平对齐（left、right、center）
  valign = NULL,  # 单元格内容的垂直对齐（top、center、bottom）
  wrapText = FALSE,  # 若为TRUE则单元格内自动换行
  indent = NULL,  # 缩进
  locked = NULL,  # 锁定单元格
  hidden = NULL  # 隐藏单元格内容的公式
)
headerStyle <- createStyle(
  fontSize = 14, fontColour = "#FFFFFF", numFmt = "0.00%", halign = "center",
  fgFill = "#4F81BD", border = "TopBottom", borderColour = "#4F81BD"
)
addStyle(wb, sheet=1, headerStyle, rows=1, cols=1:6, gridExpand=TRUE)  # 使用样式
writeData(wb,'ss',dd,headerStyle=headerStyle)  # 使用样式

# read.xlsx从本地读取excel数据
read.xlsx(
  xlsxFile,  # 数据路径
  sheet = 1,  # sheet名称
  startRow = 1,  # 开始行
  colNames = TRUE,  # 是否包含列名
  rowNames = FALSE,  # 是否包含行名
  detectDates = FALSE,  # 若为真，则会将日期转换为日期格式
  skipEmptyRows = TRUE,  # 跳过空行
  skipEmptyCols = TRUE,  # 跳过空列
  rows = NULL,  # 默认读取所有的，可以指定读取指定的行
  cols = NULL,  # 默认读取所有的，可以指定读取指定的列
  na.strings = "NA",  # 空白单元格的返回值，默认返回NA
  fillMergedCells = FALSE  # 如果为真，拆分合并的单元格并分到各单元格
)

createWorkbook()  # 新建一个工作簿对象，可在对象内插入sheet，工具
loadWorkbook(filepath)  # 加载一个现有的.xlsx文件，生成工作簿对象
saveWorkbook(wb, file, overwrite = FALSE)  # 保存工作簿对象到文件，若存在不会覆盖会报错
addWorksheet(wb,'sheet')  # 向工作簿对象添加一个空白sheet，更多参数查看help
addStyle(wb, sheet=1, headerStyle, rows=1, cols=1:6, gridExpand=TRUE)  # 直接向工作簿对象添加样式
createComment(comment = "this is comment")  # 新建一个注释，也有其他参数可以设置
writeComment(wb, 1, col="B", row=10, comment=c1)  # 给指定单元格添加注释
deleteData(wb,sheet=1,cols=3:5,rows=5:7,gridExpand=TRUE) # 删除数据，gridExpand为真删除范围内所有数据
freezePane(wb, "Sheet 1", firstActiveRow = 5, firstActiveCol = 3)  # 冻结单元格
getSheetNames('/home/dingtao/wangxukun/data/tmp/alcon.xlsx')  # 返回本地excel文件的所有sheet名字
mergeCells(wb, "Sheet 1", cols = 2, rows = 3:6)  # 合并工作表中的单元格
removeCellMerge(wb, "Sheet 1", cols = 2, rows = 3:6)  # 拆分已合并的单元格
sheets(wb)  # 返回所有sheet名称
names(wb)  # 查看工作簿的所有sheet名字，可以修改sheet名字
renameWorksheet(wb, "Sheet 1", "ss")  # 修改sheet名称
removeWorksheet(wb, "Sheet 1")  # 删除指定的sheet
replaceStyle(wb, "Sheet 1", newStyle = newStyle)  # 替换已经存在的style
setColWidths(wb, 1, cols=c(1, 4, 6, 7,), widths=c(16, 15, 12, 18))  # 设置工作表列宽度
setRowHeights(wb, 1, rows=c(1, 4, 22, 2), heights=c(24, 28, 32, 42))  # 设置工作表行高
write.xlsx(dd, filepath)  # 向excel文件写入datatable数据，或者是list，每个元素一个sheet
```
