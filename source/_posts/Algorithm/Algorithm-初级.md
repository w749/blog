---
title: Algorithm-初级
author: 汪寻
date: 2021-09-30 11:10:22
updated: 2021-09-30 11:57:18
tags:
 - 算法
categories:
 - Algorithm
---

LeetCode 算法-初级

<!-- more -->

## 1. 删除排序数组中的重复项

给你一个有序数组 nums ，请你 原地 删除重复出现的元素，使每个元素 只出现一次 ，返回删除后数组的新长度。不要使用额外的数组空间，你必须在 原地 修改输入数组 并在使用 O(1) 额外空间的条件下完成。

 **说明:**

为什么返回数值是整数，但输出的答案是数组呢?请注意，输入数组是以「引用」方式传递的，这意味着在函数里修改输入数组对于调用者是可见的。你可以想象内部操作如下:

> // nums 是以“引用”方式传递的。也就是说，不对实参做任何拷贝
> int len = removeDuplicates(nums);
>
> // 在函数里修改输入数组对于调用者是可见的。
> // 根据你的函数返回的长度, 它会打印出数组中 该长度范围内 的所有元素。
> for (int i = 0; i < len; i++) {
>     print(nums[i]);
> }

**示例 1：**

> 输入：nums = [1,1,2]
> 输出：2, nums = [1,2]
> 解释：函数应该返回新的长度 2 ，并且原数组 nums 的前两个元素被修改为 1, 2 。不需要考虑数组中超出新长度后面的元素。

**示例 2：**

> 输入：nums = [0,0,1,1,1,2,2,3,3,4]
> 输出：5, nums = [0,1,2,3,4]
> 解释：函数应该返回新的长度 5 ， 并且原数组 nums 的前五个元素被修改为 0, 1, 2, 3, 4 。不需要考虑数组中超出新长度后面的元素。


提示：

> 0 <= nums.length <= 3 * 104
> -104 <= nums[i] <= 104
> nums 已按升序排列

### 题解（2021-09-25）

> 变量：`low: Int`、`fast: Int`
> 时间复杂度：`O(1)`
> 空间复杂度：`log(1)`
> 思路：使用快慢指针，快指针用来遍历数组，慢指针用来定位与快指针所指向的元素比较，若不同则将快指针指向的元素与慢指针之后的元素调换位置，若相等则快指针继续遍历。

**Java**

```java
class Solution {
    public int removeDuplicates(int[] nums) {
        int low = 1;
        int fast = 1;
        for(int i = 1; i < nums.length; i++) {
            if(nums[fast] != nums[low-1]) {
                nums[low] = nums[fast];
                low++;
            }
            fast++;
        }
        return low;
    }
}
```
**Python**

```python
class Solution:
    def removeDuplicates(self, nums: List[int]) -> int:
        low: int = 1
        fast: int = 1
        for i in range(len(nums) - 1):
            if nums[fast] != nums[low - 1]:
                nums[low] = nums[fast]
                low += 1
            fast += 1
        return low
```
**Scala**

Scala需要注意的是for循环的遍历次数，使用until后还需要再减1，否则就会报数组越界异常；还有一点是空数组的情况，它也会报数组越界异常，所以要在程序开始前加判断语句，数组若为空则直接return0。
```scala
object Solution {
    def removeDuplicates(nums: Array[Int]): Int = {
        if (nums.length == 0) {
            return 0
        }
        var low: Int = 1
        var fast: Int = 1
        var i: Int = 0
        for (i <- 0 until nums.length-1) {
            if (nums(fast) != nums(low-1)) {
                nums(low) = nums(fast)
                low += 1
            }
            fast += 1
        }
        low
    }
}
```

## 2. 买卖股票的最佳时机 II

给定一个数组 prices ，其中 prices[i] 是一支给定股票第 i 天的价格。设计一个算法来计算你所能获取的最大利润。你可以尽可能地完成更多的交易（多次买卖一支股票）。注意：你不能同时参与多笔交易（你必须在再次购买前出售掉之前的股票）。

**示例 1:**

> 输入: prices = [7,1,5,3,6,4]
> 输出: 7
> 解释: 在第 2 天（股票价格 = 1）的时候买入，在第 3 天（股票价格 = 5）的时候卖出, 这笔交易所能获得利润 = 5-1 = 4 。随后，在第 4 天（股票价格 = 3）的时候买入，在第 5 天（股票价格 = 6）的时候卖出, 这笔交易所能获得利润 = 6-3 = 3 。

**示例 2:**

> 输入: prices = [1,2,3,4,5]
> 输出: 4
> 解释: 在第 1 天（股票价格 = 1）的时候买入，在第 5 天 （股票价格 = 5）的时候卖出, 这笔交易所能获得利润 = 5-1 = 4 。注意你不能在第 1 天和第 2 天接连购买股票，之后再将它们卖出。因为这样属于同时参与了多笔交易，你必须在再次购买前出售掉之前的股票。

**示例 3:**

> 输入: prices = [7,6,4,3,1]
> 输出: 0
> 解释: 在这种情况下, 没有交易完成, 所以最大利润为 0。

### 题解（2021-09-30）

> 变量：`Int: total = 0`
> 时间复杂度：`O(n)`
> 空间复杂度：`log(n)`
> 思路：不用考虑太多，记着一个原则，如果当天大于前一天的则买入，同时卖掉手里前一天的，否则不买不卖；当天买入同时卖掉前一天实则赚的是当天和前一天的差价，所以可以将循环内的代码简化为求当天减去前一天价格的值和0的最大值，若为负数则是当天小于前一天价格，total加0，否则total加差值

**Java**

```java
class Solution {
    public int maxProfit(int[] prices) {
        int total = 0;
        for (int i = 1; i < prices.length; i++) {
            if (prices[i] > prices[i-1]) {
                total -= prices[i-1];
                total += prices[i];
            }
        }
        return total;
    }
}
```

**Python**

```python
class Solution:
    def maxProfit(self, prices: List[int]) -> int:
        total = 0
        for i in range(1, len(prices)):
            if prices[i] > prices[i-1]:
                total -= prices[i-1]
                total += prices[i]
        return total
```

**Scala**

```scala
object Solution {
    def maxProfit(prices: Array[Int]): Int = {
        var total: Int = 0
        for (i <- 1 until prices.length) {
            if (prices(i) > prices(i-1)) {
                total -= prices(i-1)
                total += prices(i)
            }
        }
        return total
    }
}
```

**Java改良版**

```java
class Solution {
    public int maxProfit(int[] prices) {
        int total = 0;
        for (int i = 1; i < prices.length; i++) {
            total += Math.max(prices[i] - prices[i-1], 0);
        }
        return total;
    }
}
```

