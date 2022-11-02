---
title: R语言基于S3的面向对象编程
author: 汪寻
date: 2021-05-07
tags:
 - R
categories:
 - Language

---

对于R语言的面向对象编程，不同于其他编程语言，R语言提供了3种底层对象类型，一种是S3类型，一种是S4类型，还有一种是RC类型。 
S3对象简单，具有动态性，结构化特征不明显，S4对象结构化，功能强大。RC对象是R2.12版本后使用的新类型，从底层上改变了原有S3和S4对象系统的设计，去掉了泛型函数，真正地以类为基础实现面向对象的特征。

<!-- more -->

### **S3对象的介绍**

在R语言中，基于S3对象的面向对象编程，是一种基于泛型函数的实现方式。泛型函数是一种特殊的函数，根据传入对象的类型决定调用那个具体的方法。基于S3对象实现面向对象编程，不同其他语言的面型对象编程，是一种动态函数调用的模拟实现。S3对象被广泛应用于R的早期的开发包中。

### 创建S3对象

```R
# 通过变量创建S3对象
x <- 1
attr(x, 'class') <- 'foo'
attr(x, 'class')  
`## [1] "foo"`

# 通过structure函数创建
x <- structure(1, class='foo')
class(x)
`## [1] "foo"`

# 创建一个多类型的S3对象，S3对象的class属性可以是一个向量，包括多种类型
x <- structure(1, class=c('foo','bar'))
class(x)
`## [1] "foo" "bar"`
```

### 泛型函数和方法调用

对于S3对象的使用，通常用UseMethod()函数来定义一个泛型函数的名称，通过传入参数的class属性，来确定方法调用。

定义一个teacher泛型函数

* 用UseMethod()定义teacher泛型函数
* 用teacher.xxx的语法格式定义teacher对象的行为
* 其中teacher.default是默认行为

```R
# 用UseMethod()定义teacher泛型函数
teacher <- function(…) UseMethod("teacher")

# 定义teacher内部函数
teacher.lecture <- function(…) print("讲课")
teacher.assignment <- function(…) print("布置作业")
teacher.correcting <- function(…) print("批改作业")
teacher.default <- function(…) print("你不是teacher")
```

方法调用通过传入参数的class属性，来确定不同方法调用

* 定义一个变量a，并设置a的class属性为lecture
* 把变量a传入到teacher泛型函数中
* 函数teacher.lecture()函数的行为被调用

```r
# 定义变量并设置属性
a <- structure('qwe', class='lecture')
b <- structure('qwe', class='qwe')

# 调用teacher泛型函数并返回对应类型的函数
teacher(a)
`## [1] "讲课"`
teacher(b)
`## [1] "你不是teacher"`

# 使用methods查看S3对象的函数
methods(teacher)
`## [1] teacher.assignment teacher.correcting teacher.default teacher.lecture`
```

### S3对象的继承关系

S3独享有一种非常简单的继承方式，用NextMethod()函数来实现。

```r
# 定义一个xx泛型函数
xx <- function(x) UseMethod('xx')

# 定义xx内部函数
xx.default <- function(x) return('default')
xx.son <- function(x) return(c('son', NextMethod()))
xx.father <- function(x) return('father')

# 定义变量并设置son和father属性
y <- structure(1, class=c('son','father'))
xx(y)
`## [1] "son" "father"`
```

通过对xx()函数传入y的参数，xx.son()先被执行，然后通过NextMethod()函数继续执行了xx.father()函数。这样其实就模拟了子函数调用父函数的过程，实现了面向对象编程中的继承。

### S3对象的缺点

从上面S3对象的介绍上来看，S3对象并不是完全的面向对象实现，而是一种通过泛型函数模拟的面向对象的实现。

* S3用起来简单，但在实际的面向对象编程的过程中，当对象关系有一定的复杂度，S3对象所表达的意义就变得不太清楚
* S3封装的内部函数，可以绕过泛型函数的检查，以直接被调用（直接调用xx.father）
* S3参数的class属性，可以被任意设置，没有预处理的检查（若没有对应属性的函数返回default函数）
* S3参数，只能通过调用class属性进行函数调用，其他属性则不会被class()函数执行
* S3参数的class属性有多个值时，调用时会被按照程序赋值顺序来调用第一个合法的函数

所以，S3只是R语言面向对象的一种简单的实现。

写于2021年5月7日。