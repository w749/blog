---
title: R语言环境空间理解
author: 汪寻
date: 2021-05-13 19:21:47
updated: 2021-05-13 19:37:14
tags:
 - R
categories:
 - Language
---

环境空间 ( environment ) 对于刚接触 R 语言的我来说，是比较陌生的。虽然不了解它的运行原理，但也不影响我使用 R 语言。环境空间是 R 语言中关于计算机方面的底层设计，主要用于R语言是环境加载器。通过环境空间，封装了加载器的运行过程，让使用者在不知道底层细节的情况下，可以任意加载使用到的第三方的 R 语言程序包。

<!-- more -->

### 介绍

在R语言中，不管是变量，对象，或者函数，都存在于 R 的环境空间中，R程序在运行时都自己的运行时空间。R 语言的环境 (environment) 是由内核定义的一个数据结构，由一系列的、有层次关系的框架 (frame) 组成，每个环境对应一个框架，用来区别不同的运行时空间 (scope) 。

环境空间有一些特征，比如 每个环境空间要有唯一的名字；环境空间是引入类型的，非赋值类型；环境空间都有父环境空间，空环境是最顶层的环境空间，没有父空间；子环境空间会继承父环境空间的变量等。

### 环境的理解

关于环境的理解，先从新建一个环境开始：`new.env(hash = TRUE, parent = parent.frame(), size = 29L)`

- hash 默认TRUE ，指使用 Hash Table 的结构
- parent 默认当前环境，指定要创建环境的父环境
- size 初始化环境大小

```r
# 擦混关键环境env
env <- new.env()
env
## [1] <environment: 0x3d7eef0>
class(env)
## [1] "environment"

# 定义变量
env$a <- 123
env$b <- 'qwe'
ls(env)
## [1] "a" "b"
```

以上就是新建了一个父环境为当前环境的环境空间，在这个环境空间中可以定义自己的变量，并且可以使用`环境$变量`的方式访问环境内的变量。

#### 环境空间的层次结构

那么所谓创建环境时的父环境又是什么呢，要理解这个就得来理解环境空间的层次结构了。R 语言中有五种环境的定义：当前环境、内部环境、父环境、空环境和包环境。

- 当前环境，即用户环境，用户运行程序时的环境（<environment: R_GlobalEnv>）
- 内部环境，构造出来的环境，使用`new.env()`构造出来的环境
- 父环境，即环境空间的上一层环境，R语言中除了空环境之外所有环境都有父环境
- 空环境，即顶层环境，没有父环境空间
- 包环境，包封装的环境空间

```r
# 当前环境，或者使用globalenv
environment()
## [1] <environment: R_GlobalEnv>
# 内部环境
new.env()
## [1] <environment: R_GlobalEnv>
# 父环境
parent.env(env)
## [1] <environment: R_GlobalEnv>
# 空环境
emptyenv()
## [1] <environment: R_EmptyEnv>
# 包环境
baseenv()
## [1] <environment: base>
```

既然环境空间是有层次的，那可以将从 env 到空环境的层次结构全部打印出来

```r
# 递归打印环境空间，identical比较两者是否相同
parent.call <- function(env) {
  print(env)
  if(is.environment(env) & !identical(env, emptyenv())) { 
    parent.call(parent.env(env))
  }
}

parent.call(env)
## <environment: 0x366bf18>
## <environment: R_GlobalEnv>
## <environment: package:purrr>
## attr(,"name")
## [1] "package:purrr"
## attr(,"path")
## [1] "/home/dingtao/R/x86_64-pc-linux-gnu-library/3.3/purrr"
## <environment: package:stats>
## attr(,"name")
## [1] "package:stats"
## attr(,"path")
## [1] "/usr/lib/R/library/stats"
## <environment: package:graphics>
## attr(,"name")
## [1] "package:graphics"
## attr(,"path")
## [1] "/usr/lib/R/library/graphics"
## <environment: package:grDevices>
## attr(,"name")
## [1] "package:grDevices"
## attr(,"path")
## [1] "/usr/lib/R/library/grDevices"
## <environment: package:utils>
## attr(,"name")
## [1] "package:utils"
## attr(,"path")
## [1] "/usr/lib/R/library/utils"
## <environment: package:datasets>
## attr(,"name")
## [1] "package:datasets"
## attr(,"path")
## [1] "/usr/lib/R/library/datasets"
## <environment: package:methods>
## attr(,"name")
## [1] "package:methods"
## attr(,"path")
## [1] "/usr/lib/R/library/methods"
## <environment: 0x20cb5d0>
## attr(,"name")
## [1] "Autoloads"
## <environment: base>
## <environment: R_EmptyEnv>
```

可以看到先是打印出来`<environment: 0x366bf18>`这是 env 的环境空间；接下来是作为 env 父空间的当前空间；再接下来是我导入的 purrr 包，其实这里还有很多，我给省略了，然后是六个基础包、Autoloads、base 包，最后是空环境。那么从R的导入顺序来看就是反过来的，先加载空环境，然后再一步步导入所需要的包，最后到达当前环境。

那么我们就可以访问到父环境以及爷爷环境等等中的变量，前提是未在当前环境中找到，它就会去父环境中寻找，一直找到空环境，若是还没有找到就会报错；但若是当前环境空间中已有相同名称的变量，那么你要么使用 rm 删除当前环境空间中的变量，要么指定环境变量访问变量，否则是访问不到指定环境空间中的变量的。

### 环境的操作

主要是一些命令的使用

```r
# 基础命令
env1 <- new.env()  # 创建一个新环境
is.environment(env1)  # 判断是否是一个环境空间
environment()  # 查看当前环境空间
environment(ls)  # 查看函数中的环境空间
environmentName(baseenv())  # 查看环境空间的名字
environmentName(environment())
attr(env1, 'name') <- 'env1'  # 设置环境空间的名字，默认创建出来是没有名字的
env.profile(env1)  # 查看环境空间的属性值
rm(list=ls())  # 清空当前环境空间定义的所有对象
rm(x, envir=env1)  # 删除env1中的变量
ls(env1)  # 查看env1环境空间中的变量
x <- 1.5; y <- 2:10  # 定义环境空间中的变量
env1 <- new.env()
env1$x <- -10

# 环境空间变量取值
get('x', envir=env1)  # 取env1环境空间中的x值
get('y', envir=env1)  # 从env1环境空间中取从当前环境中继承的y值
# get('y', envir=env1, inherits=FALSE)  # 禁止环境空间的继承，会报错

# 重新赋值
assign('x', 77); x  # 重新赋值当前环境空间中的x值
assign('x', 99, envir=env1); env1$x  # 重新赋值环境空间中的x值
assign('y', 333, envir=env1, inherits=FALSE)  # 在没有继承的情况下给环境空间中的y赋值

# 变量在环境空间中是否存在
exists('x')
exists('x', envir=env1)
# exists('y', envir=env1, isherits=FALSE)  # 在没有继承的情况下y是否存在，会报错

# 查看函数的环境空间，来自pryr包
where('mean')
where('where')
```

### 函数的环境空间

在 R 语言中，变量、对象、函数都存在于环境空间中，而函数又可以有自己的环境空间，我们可以在函数内再定义变量、对象和函数，循环往复就形成了我们现在用的R语言环境系统。

一般情况，我们可以通过`new.env()`去创建一个环境空间，但更多的时候，我们使用的是函数环境空间。函数环境空间包括4方面的内容：

- 封闭环境，每个函数都有一个且只有一个封闭环境空间，指向函数定义的环境空间
- 绑定环境，给函数指定一个名字，绑定到函数变量，`如 fun1<-function(){1}`
- 运行环境，当函数运行时，在内存中动态产生的环境空间，运行结束后，会自动销毁
- 调用环境，是指在哪个环境中进行的方法调用，如`fun1<-function(){fun2()}`，函数fun2在函数fun1被调用

#### 参数寻址补充

函数中的参数是惰性求值，不执行则不运算，只有在执行或者被调用的时候才会进行运算；函数体执行运算用到变量时若函数体中未定义，参数环境中也未定义，则会向全局环境中寻址；函数在被调用时若有缺省值，则局部参数被调用时会优先使用传入的参数，若未传入参数才会使用缺省值。
