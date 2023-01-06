---
title: Hadoop-Yarn资源调度器了解
author: 汪寻
date: 2021-12-06 14:18:16
updated: 2021-12-06 14:54:35
tags:
 - Hadoop
categories:
 - Software
---

简单了解了 YARN 资源调度器并针对容量调度器做了简单的介绍和配置。

<!-- more -->

### 任务执行过程

Application在Yarn中的执行过程，整个执行过程可以总结为三步：

1. 应用程序提交
2. 启动应用的 ApplicationMaster 实例
3. ApplicationMaster 实例管理应用程序的执行

<div align=center><img src="Yarn任务提交流程.png"></div>

具体提交过程为：

1. 客户端程序向 ResourceManager 提交应用并请求一个 ApplicationMaster 实例；
2. ResourceManager 找到一个可以运行一个 Container 的 NodeManager，并在这个 Container 中启动 ApplicationMaster 实例；
3. ApplicationMaster 向 ResourceManager 进行注册，注册之后客户端就可以查询 ResourceManager 获得自己 ApplicationMaster 的详细信息，以后就可以和自己的 ApplicationMaster 直接交互了（这个时候，客户端主动和 ApplicationMaster 交流，应用先向 ApplicationMaster 发送一个满足自己需求的资源请求）；
4. 在平常的操作过程中，ApplicationMaster 根据 `resource-request协议` 向 ResourceManager 发送 `resource-request请求`；
5. 当 Container 被成功分配后，ApplicationMaster 通过向 NodeManager 发送 `container-launch-specification信息` 来启动Container，`container-launch-specification信息`包含了能够让Container 和 ApplicationMaster 交流所需要的资料；
6. 应用程序的代码以 task 形式在启动的 Container 中运行，并把运行的进度、状态等信息通过 `application-specific协议` 发送给ApplicationMaster；
7. 在应用程序运行期间，提交应用的客户端主动和 ApplicationMaster 交流获得应用的运行状态、进度更新等信息，交流协议也是 `application-specific协议`；
8. 一旦应用程序执行完成并且所有相关工作也已经完成，ApplicationMaster 向 ResourceManager 取消注册然后关闭，用到所有的 Container 也归还给系统。

### 调度器

Hadoop 作业调度器主要有三种：FIFO 调度器、容量调度器和公平调度器，Apache Hadoop 3.1.3 默认的调度器是Capacity Scheduler（容量调度器），CDH 默认的调度器是 Fair Scheduler（公平调度器）。详见 yarn-default.xml文件：

```xml
<property>
  <name>yarn.resourcemanager.scheduler.class</name>
  <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler</value>
  <description>配置Yarn使用的调度器插件类名</description>
</property>
```

#### FIFO调度器

FIFO（First In First Out）：单队列，根据任务的先后顺序，先来的先处理，后来的后处理，后来的服务只能等待先来的服务运行完毕释放资源后才能按顺序执行，这种调度方式不推荐使用，会造成资源的浪费且效率低下。

#### 容量调度器

Capacity Scheduler 是多用户调度器，生产中常用这个调度器，它有以下几个特点：

- 多队列：可以有多个队列，每个队列可配置一定的资源，每个队列采用 FIFO 调度策略
- 容量保证：可以为每个队列设置资源最低保障和资源使用上限，哪怕资源紧张也会保证单个队列内的最低资源使用
- 灵活性：如果一个队列资源空闲，可暂时共享给其他队列使用，一旦该队列有新的应用程序提交，其他队列借用的资源会归还给该队列
- 多用户：支持多用户共享集群和多应用同时运行，同一队列内若是有资源空闲也会运行后续程序，只是保证运行顺序是 FIFO；而且为防止同一个用户独占集群资源，会对一个用户下的所有应用所占用的资源进行限定

容器调度器资源分配算法自上而下分为队列资源分配、作业资源分配和容器资源分配：

- 队列资源分配：从 root 开始，使用深度优先算法，优先选择资源占用率较低的队列分配资源
- 作业资源分配：默认按照作业提交的优先级和提交时间顺序进行资源分配
- 容器资源分配：按容器的优先级进行分配；如果优先级相同，则按照数据本地性原则进行分配资源：任务和数据在同一节点 > 任务和数据在同一机架 > 任务和数据不在同一节点也不在同一机架

#### 公平调度器

Fair Scheduler 公平调度器和容量调度器是 Facebook 开发的调度器

- 与容量调度器的相同点：多队列、容量保证、灵活性、多租户
- 不同点：核心调度策略不同：容量调度器优先选择利用率低的队列，公平调度器优先选择对资源的缺额比例大的；每个队列可以设置的资源分配方式不同：容量调度器可选 FIFO 和 DRF，公平调度器可选 FIFO、FAIR 和 DRF

### 常用命令

详情见官网 [Yarn 相关命令](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/YarnCommands.html)

```shell
yarn application -list  # 查看所有的application
yarn application -list -appStates <states>  # 选择指定状态的application：ALL, NEW, NEW_SAVING, SUBMITTED, ACCEPTED, RUNNING, FINISHED, FAILED, KILLED
yarn application -kill <app ID>  # 根据app ID杀死指定的application
yarn applicationattempt -list <ApplicationAttempt ID>  # 查看尝试运行的application

yarn logs -applicationId <app ID>  # 查看指定application的全部日志
yarn logs -applicationId <app ID> -containerId <container ID>  # 查看指定container的日志

yarn container -list <ApplicationAttempt ID>  # 查看正在运行的application下的所有container
yarn container -status <container ID>  # 查看容器状态

yarn node -list all  # 查看所有nodemannager
yarn rmadmin -refreshQueues  # 更新队列相关的配置
yarn queue -status <queue name>  # 查看队列状态
```

### 容量调度器配置案例

下方对`capacity-scheduler.xml`文件做了一些配置，除了 default 队列新建了一个 hive 队列，然后给 hive 队列分配所有资源的 80%，default 占 20%；
然后又在 hive 队列下新建了 operation 和 development 队列，分别占用 hive 资源的85%和15%；
随后又对 operation 资源进行用户分配，指定将 jason 用户映射到 operation 队列中，将 hadoop_admin 组中的用户映射到 development 队列，将 hive 用户映射到与 Linux 中主组名相同的队列。

配置完成后不用重启集群，使用`yarn rmadmin -refreshQueues`即可更新队列相关配置。

在使用的时候 mapreduce 任务直接在参数中指定队列名称即可：`hadoop jar hadoop-mapreduce-examples-3.1.3.jar wordcount -D mapreduce.job.queuename=operation /input /output`，Hive 操作中则使用`set mapreduce.job.queuename=operation `来指定要提交的队列。

```xml
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>

  <!-- root始终是创建所有队列的顶级队列，因此我们现在顶级队列中创建2个子顶级队列。 -->
  <property>
    <name>yarn.scheduler.capacity.root.queues</name>
    <value>default,hive</value>
    <description>这是为root顶级队列定义子队列，默认值为:"default"</description>
  </property>

  <!-- 注意哈，当我们定义好顶级队列的子队列后，我们接下来做为其设置队列容量，如果你没有做该步骤，那么启动RM将会失败。  -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.capacity</name>
    <value>80</value>
    <description>这里指定的是root顶队列下的hive这个子队列，该队列默认占用整个集群的80%的资源</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.default.capacity</name>
    <value>20</value>
    <description>这里指定的是root顶队列下的default这个子队列，该队列默认占用整个集群的20%的资源</description>
  </property>

  <!-- 
    我们可以为子顶队列继续分配子队列，比如我们将hive这个队列分为:"operation"和"development"这2个子队列。

    下面配置的队列存在以下关系:
        (1)我们可以说"hive"这个队列是"operation"和"development"的父队列;
        (2)"operation"和"development"这2个队列是"hive"的子队列;

    温馨提示:
        我们不能直接向父队列提交作业，只能向叶子队(就是没有子队列的队列)列提交作业。
    -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.queues</name>
    <value>operation,development,testing</value>
    <description>此处我在"hive"这个顶级队列中定义了三个子顶队列，分别为"operation","development"和"testing"</description>
  </property>

  <!--
       按百分比为"hive"的2个子队列(即"operation"和"development")分配容量，其容量之和为100%。  

       需要注意的是:
       各个子队列容量之和为父队列的总容量,但其父队列的总容量又受顶队列资源限制;
       换句话说，"operation","development"这2个队列能使用的总容量只有集群总量的80%，因为"hive"这个队列容量配置的就是80%.
   -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.capacity</name>
    <value>85</value>
    <description>这里指定的是一个"operation"队列占"hive"队列的百分比，即所有资源的85% * 80%的资源归该队列使用</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.development.capacity</name>
    <value>15</value>
    <description>这里指定的是一个"development"队列占"hive"队列的百分比，即所有资源的15% * 80%的资源归该队列使用</description>
  </property>

  <!-- 配置限制用户容量的相关参数 -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.user-limit-factor</name>
    <value>2</value>
    <description>
    为支持叶子队列中特定用户设置最大容量。defalut队列用户将百分比限制在0.0到1.0之间。此参数的默认值为1，这意味着用户可以使用所有叶子队列的配置容量。
    如果将此参数的值设置大于1，则用户可以使用超出叶子队列容量限制的资源。比如设置为2，则意味着用户最多可以使用2倍与配置容量的容量。
    如果将其设置为0.25，则该用户仅可以使用队列配置容量的四分之一。
    </description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.development.user-limit-factor</name>
    <value>0.5</value>
  </property>
  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.maximum-capacity</name>
    <value>50</value>
    <description>
    此参数用于设置容量的硬限制，此参数的默认值为100。如果要确保用户不能获取所有父队列的容量，则可以设置此参数。
    此处我将向"root.hive.operation"叶子队列提交作业的用户不能占用"root.hive"队列容量的50%以上。
    </description>
  </property>
  <property>
    <name>yarn.scheduler.capacity.root.hive.development.maximum-capacity</name>
    <value>50</value>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.minmum-user-limit-percent</name>
    <value>10</value>
    <description>
    假设配置了可以占用500GB RAM的叶子队列，如果20个用户象征队列提交作业怎么样？当然，你可以让所有20个用户的容器占用25GB的RAM，但那样太慢了。
    我们可以通过配置该参数来控制分配给叶子队列用户的最小资源百分比。如果将此参数的值设置为10，则意味着通过此队列运行的应用程序的用户至少会被分配到
    当前队列所有资源的10%。
    综上所述，此参数可以限制用户的最小值资源百分比，最大值取决于集群中运行应用程序的用户数，它的工作流程如下:
        (1)当第一个向这个叶子队列提交作业的用户可以使用100%的叶子队列的资源分配;
        (2)当第二个向这个叶子队列提交作业的用户使用该队列的50%的资源;
            (3)当第三个用户向队列提交应用程序时，所有用户被限制为该队列33%;
            (4)随着其他用户开始将作业提交到此队列，最终每个用户可以稳定地使用队列10%的资源，但不会低于该值，这就是我们设置最小资源百分比的作用;
        (5)需要注意的时，只有10个用户可以随时使用队列(因为10个用户已经占用完该队列资源)，而其他用户必须等待前10名用户任意一个用户释放资源。才能依次运行已提交的Job;
   </description>
  </property>

  <!-- 限制应用程序数量 -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.maximum-applications</name>
    <value>5000</value>
    <description>
    该参数可以对容量调度器提交的应用程序数量设置上限，即为在任何时候给定时间可以运行的最大应用程序数量设置硬限制。此参数root队列的默认值为10000。
    对应的子顶队列以及叶子队列的最大应用上限也有对应的计算公式，比如我们要计算default队列的最大容器大小公式如下:
        default_max_applications = root_max_applications * (100 - yarn.scheduler.capacity.root.hive.capacity)
    最终算得default_max_applications的值为2000(带入上面的公式:"10000 * (100 - 80)%",即:10000 * 0.2)
    </description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.maximum-am-resource-percent</name>
    <value>0.2</value>
    <description>
    该参数用于设置所有正在运行的ApplicationMasters可以使用的集群资源的百分比，即控制并发运行的应用程序的数量。此参数的默认值为10%。
    当设置为0.2这意味着所有ApplicationMaster不能占用集群资源的20%以上(ApplicationMaster容器的RAM内存分配，这是为应用程序创建第一个容器)。
    </description>
  </property>

  <!-- 配置队列管理权限 -->
  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.acl_administer_queue</name>
    <value>hadoop_admin</value>
    <description>
    指定谁可以管理root.hive.operation该叶子队列，其中"*"表示术语指定组的任何人都可以管理此队列。
    可以配置容量调度器队列管理员来执行队列管理操作，例如将应用程序提交到队列，杀死应用程序，停止队列和查看队列信息等。
    上面我配置的"hadoop_admin"，这意味着在hadoop_admin组的所有用户均可以管理"root.hive.operation"队列
    </description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.acl_submit_applications</name>
    <value>jason,hive</value>
    <description>
    此参数可以指定那些用户将应用程序提交到队列的ACL。如果不知定制，则从层次结果中的父队列派生ACL。根队列的默认值为"*"，即表示任何用户
    常规用户无法查看或修改其他用户提交的应用程序，作为集群管理员，你可以对队列和作业执行以下操作:
        (1)在运行时更改队列的定义和属性;
        (2)停止队列以防止提交新的应用程序;
        (3)启动停止的备份队列;
    </description>
  </property>


  <!-- 配置用户映射到队列 -->
  <property>
    <name>yarn.scheduler.capacity.queue-mappings</name>
    <value>u:jason:operation,g:hadoop_admin:development,u:hive:%primary_group</value>
    <description>
    此参数可以将用户映射到指定队列，其中u表示用户，g表示组。
    "u:jason:operation":
        表示将jason用户映射到operation队列中。
    "g:hadoop_admin:development":
        表示将hadoop_admin组中的用户映射到development队列中。
    "u:hive:%primary_group":
        表示将hive用户映射到与Linux中主组名相同的队列。
    温馨提示:
        YARN从左到右匹配此属性的映射，并使用其找到的第一个有效映射。
    </description>
  </property>

  <!-- 配置队列运行状态 -->
  <property>
    <name>yarn.scheduler.capacity.root.state</name>
    <value>RUNNING</value>
    <description>
    可以随时在跟对任意队列级别停止或启动队列，并使用"yarn rmadmin -refreshQueues"使得配置生效，无需重启整个YARN集群。
    队列有两种状态，即STOPPED和RUNNING，默认均是RUNNING状态。
    需要注意的是:
        (1)如果停止root或者父队列，则叶子队列将变为非活动状态(即STOPPED状态)。
            (2)如果停止运行中的队列，则当前正在运行的应用程序会继续运行直到完成，并且不会将新的的应用程序提交到此队列。
        (3)若父队列为STOPPED，则子队列无法配置为RUNNING，若您真这样做，将会抛出异常哟。
        温馨提示:
        可以通过ResourceManager Web UI的Application页面中的Scheduler页面，来监视容量调度器队列的状态和设置。
    </description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.default.state</name>
    <value>RUNNING</value>
    <description>将"root.default"队列的状态设置为"RUNNING"状态</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.state</name>
    <value>RUNNING</value>
    <description>将"root.hive"队列的状态设置为"RUNNING"状态</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.operation.state</name>
    <value>RUNNING</value>
    <description>将"root.hive.operation"队列设置为"RUNNING"状态</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.development.state</name>
    <value>RUNNING</value>
    <description>将"root.hive.development"队列设置为"RUNNING"状态</description>
  </property>

  <property>
    <name>yarn.scheduler.capacity.root.hive.testing.state</name>
    <value>RUNNING</value>
    <description>将"root.hive.testing"队列设置为"RUNNING"状态</description>
  </property>

</configuration>
```
