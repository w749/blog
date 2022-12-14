---
title: Algorithm-算法入门
author: 汪寻
date: 2021-07-30 17:26:43
updated: 2021-07-30 17:54:10
tags:
 - 算法
categories:
 - Algorithm
---

基础数据结构以及常用算法介绍。

<!-- more -->

## 数据结构

数据结构定义了数据在计算机内部的顺序和位置关系，每种数据结构的存储和取出方式各不相同。

### 链表

首先链表在内存中的地址并不是连续的，它是通过数据与数据之间的指针单向指向来确定彼此的位置关系，由此也就确定了它们的相对位置和顺序，其中的数据呈线性排列。

对数据的访问是对链表进行线性查找，从左到右依次遍历，直到找到目标数据为止；数据的删除则比较简单，直接将指向要删除数据的指针更改到要删除数据指向的数据，这要就没法通过线性查找在链表中找到这条数据，也就达到了删除的目的；数据的新增则是将目标位置之前的数据指针指向新增数据，新增数据指向目标位置之后的数据。

对链表的查询要从头开始查找，所以查询时间复杂度为O(n)；删除和增加则只需要更改两个指针的指向，和链表长度n无关，所以时间复杂度为O(1)。总结下来链表呈线性排列，新增和删除数据较为方便，查找需要进行线性查找，比较耗时。

上面说的是单向链表，还有环形链表和双向链表，环形链表是将单向链表的头和尾连接起来，没有首尾的概念；双向链表则是数据从后往前也有指针指向前一个数据，查找可以从前往后也可以从后往前，但删除和增加就会比较耗时。

<div align=center><img src="数据结构-链表.png"></div>

### 数组

数组是在内存中占用连续内存地址按顺序排列的数据结构，每个数据都有一个下标，用来定位位置返回数据，数据也是呈线性排列。

数据的访问比较简单，直接通过数组的下标定位到指定的位置返回数据；新增和删除则比较麻烦，若是最后一个元素则直接删除或新增，若是新增到数组中间，则需要先在数组最后新增一个空的元素，然后依次将需要插入的位置及以后的元素从后往前依次往后移动一位，直到要插入的位置空出来再把数据放进去；反之删除一个指定数据，则先将目标位置置空，再从这个位置往后将数据依次往前移动一位，最后将最后一个置空位置删除。

数组的查询直接根据角标，和数组长度n无关，所以查询时间复杂度为O(1)，删除和增加数据需要移动数据，所以时间复杂度为O(n)。总结下来数组和链表一样都是线性排列，链表是分散的，而数组是存储在连续内存空间内，每个空间都有角标用来定位数据，查询数据较为方便，增加和删除数据比较耗时。

<div align=center><img src="数据结构-数组.png"></div>

### 栈

栈也是一种呈线性排列的数据结构，可以把它想象成一个箱子，然后往里面放数据，先放进去的得最后才能取出来，后放进去的最先取出来，要想取最先放进去的就得把之后放进去的全部取出来，这种存取数据的方式成为后进先出（LIFO），存数据称作入栈，取数据称作出栈。经典的应用是深度优先搜索算法。

<div align=center><img src="数据结构-栈.png"></div>

### 队列

队列也是一种呈线性排列的数据结构，与栈不同的地方是先存进去的数据先取出来，就像排队一样，先来的先出，这种存取方式称为先进先出（FIFO），存数据称为入队，取数据称为出队。经典的应用是广度优先搜索算法。

<div align=center><img src="数据结构-队列.png"></div>

### 哈希表

哈希表存储的是由键值对（key value）组成的数据，通过查询key值访问value，那么最重要的就是key值的确定，因为数据不只是数字，还有字符和字符串、汉字等，要通过哈希函数算出数据对应的哈希值，数字的话一般采用mod取模的方法，除数选择key数量，假设哈希表长度为3，那么余数就是0、1、2，那么每个数字对应的模就放到对应0、1、2的后面。

一般称存放哈希数据的数组称为哈希表，首先新建一个固定长度的数组，经过哈希函数计算的哈希值确定为数据存放的位置，对应数组的角标，如果哈希值相同，则使用链表的方式将数据插入到已有数据之后。需要查找数据则先计算数据对应的哈希值，若哈希值对应的数据为空则数据不在哈希表中，若不为空则从哈希值对应的链表中线性查找数据。

哈希表的查询因为要对哈希值的链表进行线性查询，所以时间复杂度为O(n)，新增的时间复杂度为O(1)，删除也是查询到位置再进行链表的删除，所以时间复杂度为O(1)。

在存储数据的过程中，哈希值相同就会发生冲突，上述利用链表在已有数据后再增加数据解决冲突的方法称为“链地址法”，还有一个比较常用的方法称作“开放地址法”，如果发生冲突则立即计算一个候补地址（从数据地址中），如果还有冲突则继续计算候补地址，直到不冲突为止。

<div align=center><img src="数据结构-哈希表.png"></div>

### 堆

堆是一种图的树形结构，被用于实现优先队列，优先队列是一种数据结构，可以自由添加数据，但取出数据要从最小值开始取出，在堆的数据结构中，各个顶点被称为节点，数据就存在各个节点中。其中每个节点最多拥有两个子节点，节点的排列顺序从上至下，从左往右排列。

在堆中添加数据需遵循一条规则：子节点必定大于父节点，因此最小值被存在最上方的节点中。往堆中添加数据时优先放在左边，若这一行没有位置则另起一行，然后判断子节点是否大于父节点，若不是则将父子节点数据调换，再次判断若不符合继续调换，直至符合规则为止。

从堆中取出数据时，取出的是最上面最小的数据，然后重新调整堆的顺序，随后将最后一个位置的数据移到最顶端（最下最右边的数据）。根据遵循的规则，若不符合子节点大于父节点则将父节点与两个子节点中较小的一个调换位置，再次判断若不符合继续调换，直至符合规则为止。

从堆中取出数据因为取出的是最上方的最小值，所以时间复杂度为O(1)，但是因为取出数据后要将数据移到最上方，需要调换数据顺序，所以调换的次数和数的高度成正比，假设数据量为n，那么树的高度为log2n，那么取出数据的总时间复杂度为O(logn)。添加数据也是一样，根据子节点必定大于父节点的规则若是最小值就要从最下方移到最上方，时间复杂度为O(logn)。若要频繁的从数据中取出最小值堆数据结构就是最适合的。

<div align=center><img src="数据结构-堆.png"></div>

### 二叉查找树

也称为二叉搜索树或者二叉排序树，和堆一样也是一种图的树形结构，每个父节点只有两个子节点，数据存储于各个节点之中。二叉查找树遵循两个规则，一是父节点必定大于其左节点，二是父节点必定大于右子节点，例如父节点A拥有左右子节点B和C，那么就有B<A<C。若不符合则通过调换位置直至满足条件。每个父节点大于其左子节点以及左子节点所有的子节点，小于右子节点以及其所有的子节点。

在二叉查找树中查找数据时则从顶层节点开始比较和目标数据的大小关系，若大于目标数据则从右子节点查找，若小于目标数据则从左子节点查找，如此循环下去即可；往二叉查找树中插入数据时，从顶层节点开始判断两者大小关系，若大于顶层节点则往右节点移动，反之往左节点移动，若不符合规则则继续上述操作（注意所有添加的数据都会根据这两个规则移至最后一层，不会对原有数据位置产生影响）；删除数据时若没有子节点则直接删除，若含有子节点则挑选出删除节点左子节点下的最大值移动到删除的位置，这样就可以同时符合二叉查找树的两个规则（挑选出右子节点的最小值也符合规则）。

比较数据的次数取决于树的高度，假设有n条数据，那么树的高度就是log2n，时间复杂度就是O(logn)，但是若树的形状靠单侧纵向延伸，那么时间复杂度就成了O(n)。

<div align=center><img src="数据结构-二叉查找树.png"></div>

## 排序

### 冒泡排序

冒泡排序是最容易理解也是最耗时的一种排序方法。假设有n个数字，它首先依次对相邻的两个数字进行比较大小，将较小的数字往后移动，遍历完之后最小的数字已经移动到最后一位了，随后再遍历n-1次，将次小的数字移动到倒数第二位，直到遍历完最后两个数字，这组数字已经按降序排序好了。

冒泡排序容易理解，但是要遍历多次来移动较小或较大的数字，需要比较的次数为`(n-1)+(n-2)+(n-3)+...+1=(n²-n)/2`约为n²/2，则冒泡排序的时间复杂度为O(n²)。

### 选择排序

选择排序和冒泡排序略有不同，但同样比较耗时。假设有n个数字，首先从n个数字中使用线性查找寻找最小值，将它调换到第一位（直接和原第一位数字调换），随后从第二位开始在n-1个数字中寻找次小的数字，将它调换到第二位，依次下去直至全部调换完，结果已经按升序排列好了。

需要比较的最大次数为`(n-1)+(n-2)+(n-3)+...+1=(n²-n)/2`约为n²/2，所以选择的时间复杂度也是O(n²)。

### 插入排序

插入排序理解起来也比较容易，它是通过从一列数字中未排序的数字中取出一个数字与已排好序的数字比较并插入到合适的位置，已排好序的数字不再变动，仅将未排序的数字插入合适的位置即可。假设有n个数字，那么第一轮是第一个数字和自身比较直接完成，第二轮是第二个数字和第一个比较，若小于则不动，若大于则相互交换位置，第二轮完成，第三轮第三个数字先和第二个数字比较，若大于第二个数字则交换位置，随后第二个数字再和第一个比较，若大于第一个数字继续调换位置，否则第三轮结束，依次比较下去即可完成排序。

插入排序的次数为`1+2+3+...(n-2)+(n-1)=(n²-n)/2`约为n²/2，所以插入排序的时间复杂度也是O(n²)。

### 堆排序

堆排序利用堆数据结构的特性，因为堆数据结构的顶层节点是所有数据的最大值（或最小值），将数据存入堆数据结构中再依次取出来即可达到排序的效果。

插入或者弹出一个数据都与堆的高度有关，n条数据的堆高度为log2n，插入一条数据的时间复杂度为O(logn)，那么插入n条数据的时间复杂度就是O(nlogn)，由此可以得出堆排序的时间复杂度为O(nlogn)。

虽说相比于冒泡排序、选择排序和插入排序，堆排序的时间复杂度最小，但是实现起来较为复杂。可以通过在数组中使用一定的规则达到堆排序的效果。

### 归并排序

归并排序是一种先切分再合并的排序方法，在合并的过程中对数据进行比较调换位置，最后达到为序列排序的效果。具体操作方法是先将序列对半分割，然后再分别对两个序列进行对半分割，直至不可分割为止，接下来对分割完的数据进行合并。合并的时候比较两个子序列的首位数字，将较小的放在前面，较小的放在第二位，接下来再比较子序列的首位数字，重复上面的操作，确保两个子序列合并后序列的顺序是按从小到大排序的，依次向上合并排序后，序列的排序也就完成了。

归并排序中，无论分割到哪一步都是操作n个数据，所以每行的运行时间都是O(n)，而序列长度为n的数字全部切分为单个数字，都需要分割log2n次（参考堆数据结构的高度），那么所需的时间就是O(logn)，加上每行的时间所需要的总时间就是O(nlogn)，和堆排序的时间复杂度是相同的。

### 快速排序

快速排序是编程中应用最广的，因为简单且快速。快排是在一组序列中选出一个基准值，然后大于基准值的放在右边，小于基准值的放在左边，接下来再分别对左右两侧的子序列进行上述操作，递归执行，直至子序列中只剩一个数字，同时序列也按从小到大的顺序排好了。

对于时间复杂度的计算可以参考归并排序，假设每次选择的基准值都将序列对半分，那么共需分log2n次，每次需要比较n次，那么所需总时间为O(nlogn)。但若是运气不好的话每次都是选择序列中的最小值，那么每个数字都要与基准值进行比较，达不到分而治之的效果，就需要分n次，所需的总时间就是O(n²)。如果每个数字被选为基准值的概率都相等，那么它的时间复杂度就是O(nlogn)。
