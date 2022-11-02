---
title: Oozie-入门基础
author: 汪寻
date: 2022-04-20
tags:
 - Oozie
categories:
 - Software
---

Oozie基础命令和Workflow以及Coordinator的简单配置

<!-- more -->

## Command
oozie常用命令

```shell
# 启动oozie
bin/oozied.sh start
# 停止oozie
bin/oozied.sh stop
# 访问页面
curl http://localhost:11000/oozie/
# 提交并运行作业，job.properties在本地，全局配置文件，可在workflow和coordinator中使用
oozie job -oozie http://localhost:11000/oozie -config job.properties -run
# 杀死作业，kill后接jobID
oozie job -oozie http://localhost:11000/oozie -kill 0000411-180116183039102-oozie-hado-W
# 查看作业状态
oozie job -oozie http://localhost:11000/oozie -info 0000411-180116183039102-oozie-hado-W
# 查看日志
oozie job -oozie http://localhost:11000/oozie -log 0000411-180116183039102-oozie-hado-W
# 查看配置文件
oozie job -oozie http://localhost:11000/oozie -configcontent 0000411-180116183039102-oozie-hado-W
# 重跑workflow任务
oozie job -oozie http://localhost:11000/oozie -rerun 0000411-180116183039102-oozie-hado-W -config workflow.xml
# 重跑coordinator任务，action后跟coordinator每次任务id中@后的数字
oozie job -oozie http://localhost:11000/oozie -rerun 0000411-180116183039102-oozie-hado-C -refresh -action 1
# 检查workflow是否合规
oozie validate -oozie http://localhost:11000/oozie myApp/workflow.xml
# 查看所有任务
oozie jobs -oozie http://localhost:11000/oozie
# 查看coordinator任务
oozie jobs -oozie http://localhost:11000/oozie -jobtype coordinator
# 列出所有的ShareLib信息
oozie admin -oozie http://localhost:11000/oozie -shareliblist
# 列出指定的ShareLib服务信息
oozie admin -oozie http://localhost:11000/oozie -shareliblist spark
# 自动切换到最新的ShareLib目录
oozie admin -oozie http://localhost:11000/oozie -sharelibupdate
```

## Workflow
### Control flow nodes
流程控制节点分为两类，一类是start、kill、end等定义流程开始结束的节点；一类是decision、fork、join等提供控制流程执行路径的节点  
配置文件所有的变量都可以通过命令行提交任务时指定`-D name_node=hdfs://localhost:8020`传入  
job-tracker和name-node标签分别对应yarn的server地址和hdfs namenode的地址
1. start、kill、end节点
start和end是必须指定的节点，end标识流程success，kill标识流程failed
```xml
<workflow-app name="foo-wf" xmlns="uri:oozie:workflow:0.1">
	<!-- 流程启动时执行的node名称 -->
    <start to="firstHadoopJob"/>
    ...
    <!-- 流程执行失败时指向kill node，那么oozie就会标记流程失败，不会再执行后续的流程 -->
    <kill name="kill">
        <message>Action failed, error message[${wf:errorMessage(wf:lastErrorNode())}]</message>
    </kill>
    <!-- 指向end node表示流程执行成功从而执行下一个流程 -->
    <end name="end"/>
</workflow-app>
```
2. decision
相当于case when语法，条件返回true时执行对应指定的node，否则就会执行default默认的node
```xml
<workflow-app name="foo-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <decision name="mydecision">
        <switch>
            <case to="reconsolidatejob">
              ${fs:fileSize(secondjobOutputDir) gt 10 * GB}
            </case>
            <case to="rexpandjob">
              ${fs:filSize(secondjobOutputDir) lt 100 * MB}
            </case>
            <case to="recomputejob">
              ${ hadoop:counters('secondjob')[RECORDS][REDUCE_OUT] lt 1000000 }
            </case>
            <default to="end"/>
        </switch>
    </decision>
    ...
</workflow-app>
```
3. fork、join
fork和join必须同时使用，fork指定可以并行执行的流程，所有流程执行完成后汇聚到join才会执行下一个流程，可以多个fork和join嵌套使用。下面的例子就是firstparalleljob和secondparalleljob同时执行，都执行成功后汇聚到joining再执行nextaction
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <fork name="forking">
        <path start="firstparalleljob"/>
        <path start="secondparalleljob"/>
    </fork>
    <action name="firstparallejob">
        <map-reduce>
            <job-tracker>foo:8021</job-tracker>
            <name-node>bar:8020</name-node>
            <job-xml>job1.xml</job-xml>
        </map-reduce>
        <ok to="joining"/>
        <error to="kill"/>
    </action>
    <action name="secondparalleljob">
        <map-reduce>
            <job-tracker>foo:8021</job-tracker>
            <name-node>bar:8020</name-node>
            <job-xml>job2.xml</job-xml>
        </map-reduce>
        <ok to="joining"/>
        <error to="kill"/>
    </action>
    <join name="joining" to="nextaction"/>
    ...
</workflow-app>
```
### Action nodes
action node是由oozie分发到不同的yarn节点去完成的，当执行成功返回到ok继续下个流程，当执行失败返回到error执行下个流程，可以指定到kill或者忽略错误正常指定到下个流程  
oozie提供了失败重试的功能，它会在失败后一定时间内重新执行，间隔的时间和重试次数都需要在外部指定  
下面选择几种常用的流程配置文件
1. HDFS
oozie只提供了这几种简单的文件操作命令，configuration.property可以传入hdfs相关的配置，影响下面命令的执行
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.5">
    ...
    <action name="hdfscommands">
         <fs>
            <name-node>hdfs://foo:8020</name-node>
            <configuration>
              <property>
                <name>some.property</name>
                <value>some.value</value>
              </property>
            </configuration>
            <delete path='/usr/tucu/temp-data'/>
            <mkdir path='archives/${wf:id()}'/>
            <move source='${jobInput}' target='archives/${wf:id()}/processed-input'/>
            <chmod path='${jobOutput}' permissions='-rwxrw-rw-' dir-files='true'><recursive/></chmod>
            <chgrp path='${jobOutput}' group='testgroup' dir-files='true'><recursive/></chgrp>
        </fs>
        <ok to="myotherjob"/>
        <error to="errorcleanup"/>
    </action>
    ...
</workflow-app>
```
2. SSH
如果需要在指定的服务器运行命令那么ssh相对shell是个更好的选择，它会先登录目标服务器再执行命令，前提是可以免密登录
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <action name="myssjob">
        <ssh>
            <host>localhost:22<host>
            <command>chmod</command>
            <args>-R</args>
            <args>777</args>
            <args>/home/root/*</args>
        </ssh>
        <ok to="myotherjob"/>
        <error to="errorcleanup"/>
    </action>
    ...
</workflow-app>
```
3. Java
运行java程序相当于hadoop jar...命令，注意jar包要放在和workflow.xml相同路径的lib文件夹下，或者使用archive指定
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <action name="myfirstjavajob">
        <java>
            <job-tracker>foo:8021</job-tracker>
            <name-node>bar:8020</name-node>
            <prepare>
                <delete path="${jobOutput}"/>
            </prepare>
            <configuration>
                <property>
                    <name>mapred.queue.name</name>
                    <value>default</value>
                </property>
            </configuration>
            <main-class>org.apache.oozie.MyFirstMainClass</main-class>
            <java-opts>-Dblah</java-opts>
			<arg>argument1</arg>
			<arg>argument2</arg>
        </java>
        <ok to="myotherjob"/>
        <error to="errorcleanup"/>
    </action>
    ...
</workflow-app>
```
4. Sqoop
直接在command标签内写入sqoop后的所有命令和参数即可
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <action name="myfirsthivejob">
        <sqoop xmlns="uri:oozie:sqoop-action:0.2">
            <job-traker>foo:8021</job-tracker>
            <name-node>bar:8020</name-node>
            <prepare>
                <delete path="${jobOutput}"/>
            </prepare>
            <configuration>
                <property>
                    <name>mapred.compress.map.output</name>
                    <value>true</value>
                </property>
            </configuration>
            <command>import --connect jdbc:hsqldb:file:db.hsqldb --table TT --target-dir hdfs://localhost:8020/user/tucu/foo -m 1</command>
        </sqoop>
        <ok to="myotherjob"/>
        <error to="errorcleanup"/>
    </action>
    ...
</workflow-app>
```
5. Spark
除了master、node、name和class参数外其它参数都可以放到spark-opts中
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    ...
    <action name="sparkJob">
	    <spark xmlns="uri:oozie:spark-action:0.1">
	        <job-tracker>${job_tracker}</job-tracker>
	        <name-node>${name_node}</name-node>
	        <prepare>
	            <delete path="${output}"/>
	        </prepare>
	        <master>yarn-cluster</master>
	        <mode>cluster</mode>
	        <name>spark-test</name>
	        <class>com.hh.anta.analyzer.jobs.statreport.backbone.LargeIpAnalysis</class>
	        <jar>${jar_path}</jar>
	        <spark-opts>--num-executors 4 --executor-memory 10g --executor-cores 2 --driver-memory 2g</spark-opts>
	        <arg>${input}</arg>
	        <arg>${output}</arg>
	    </spark>
	</action>
    ...
</workflow-app>
```
## Coordinator
Coordinator是用来执行Workflow工作流的周期性调度工作，它和workflow一样采用xml配置文件的方式配置工作流，有关它的例子可以查看[示例](https://www.aboutyun.com//forum.php/?mod=viewthread&tid=7721&extra=page%3D1&page=1&)

### 重要定义
- Actual time实际时间：指某事实际发生的时间
- Nominal time理论时间：指某事理论上发生的时间。理论上它和实际时间应该匹配，但在实际中由于延迟，实际时间可能会发生晚于理论时间
- Dataset数据集：它为工作流提供数据目录，一般是HDFS上的路径。一个Datasets通常有几个Dataset实例，每个实例都可以被单独引用
- Synchronous Dataset同步数据集：它以固定的时间间隔生成，每个时间间隔都有一个关联的数据集实例。同步数据集实例由它们的理论时间标识
- Coordinator Action协调器操作：它是一种工作流，它在满足一组条件时启动(输入Dataset实例可用)
- Coordinator Application协调器应用程序：它定义了创建Coordinator Action的条件(频率)以及启动action的时间。同时还定义了开始时间和结束时间
- Coordinator Job协调作业：它是协调定义的可执行实例。作业提交是通过提交作业配置来完成的，该配置解析应用程序定义中的所有参数
- Data pipeline数据管道：它是一组使用和产生相互依赖的Dataset的Coordinator Application的管道
- Coordinator Definition Language协调器定义语言：用于描述Dataset和Coordinator Application的语言
- Coordinator Engine协调器引擎：执行Coordinator Job的系统

### Control
定义了一个Coordinator Job的控制信息，主要包括如下三个配置元素
1. timeout
超时时间，单位为分钟。当一个Coordinator Job启动的时候，会初始化多个Coordinator动作，timeout用来限制这个初始化过程。默认值为-1，表示永远不超时
2. concurrency
并发数，指多个Coordinator Job并发执行，默认值为1
3. execution
配置多个Coordinator Job并发执行的策略：默认是FIFO。另外还有两种：LIFO（最新的先执行）、LAST_ONLY（只执行最新的Coordinator Job，其它的全部丢弃）

### Dataset
定义了一个hdfs uri，通过频率和开始时间周期性的生成hdfs目录
1. name
Dataset名称
2. frequency
频率用来指定同一工作流执行的时间间隔，oozie提供了几种内置的方法用来指定间隔
    - `${coord:minutes(int n)}`，单位为分钟的时间间隔
    - `${coord:hours(int n)}`，单位为小时的时间间隔
    - `${coord:days(int n)}`，单位为天的时间间隔
    - `${coord:months(int n)}`，单位为月的时间间隔
    - `${cron syntax}`，使用crontab表达式，例如`${0,10 15 * * 2-6}`
3. initial-instance
工作流启动的初始时间，它会根据初始时间和frequency周期性的执行工作流。注意格式需要跟timezone相匹配
4. timezone
Oozie的默认处理时区是UTC，一般要将它修改为当地的时区，oozie支持两种方式，分别是`GMT[+/-]##:## (eg: GMT+05:30)`和`Zoneinfo标识(eg: Asia/Shanghai)`。而且需要注意oozie中的datatime是要根据timezone来指定的（eg：timezone设为GMT+8:00，那么开始时间的格式就是2019-10-1T00:00+0800）
5. uri-template
定义的是hdfs上的路径模板，因为是周期性的存储数据，那么保存的目录就应该是动态生成的  
路径模板由常量和变量组成，常量是你自己提供的，变量是oozie提供的几个时间度量值，用来获取当前的时间，分别是`YEAR、MONTH、DAY、HOUR、MINUTE`，对应输出的格式为`YYYYMMDDHHmm`
6. done-flag
工作流完成标识符，用来告诉oozie什么情况下认为当前任务已完成，给它指定不同的值将代表不同的含义：不指定标签时当目录下出现_SUCCESS文件那么标记任务成功；指定标签但值为空时只要当前文件夹存在即为成功；指定标签并且指定值那么只有文件夹下出现指定值的文件时才会标记成功
```xml
<datasets>
  <include>hdfs://foo:8020/app/dataset-definitions/globallogs.xml</include>
  <dataset name="logs" frequency="${coord:hours(12)}"
           initial-instance="2009-02-15T08:15Z" timezone="Americas/Los_Angeles">
    <uri-template>
    hdfs://foo:8020/app/logs/${market}/${YEAR}${MONTH}/${DAY}/${HOUR}/${MINUTE}/data
    </uri-template>
    <done-flag></done-flag>
  </dataset>

  <dataset name="stats" frequency="${coord:months(1)}"
           initial-instance="2009-01-10T10:00Z" timezone="Americas/Los_Angeles">
    <uri-template>hdfs://foo:8020/usr/app/stats/${YEAR}/${MONTH}/data</uri-template>
    <done-flag>over</done-flag>
  </dataset>
</datasets>
```
7. input-events
coordinator每次执行时的输入文件，可以是指定的一个文件或者多个时间点生成的多个文件  
一个Coordinator应用的输入事件指定了要执行一个Coordinator动作必须满足的输入条件，只有当input-events对应的所有文件夹都已创建或者生成了done-flag文件，工作流才会进入running状态
```xml
<input-events>
    <data-in name="BB_INPUT_PREFIX" dataset="BbInputPrefix">
        <start-instance>${coord:current(0)}</start-instance>
        <end-instance>${coord:current(5)}</end-instance>
    </data-in>
    <data-in name="IDC_INPUT_PREFIX" dataset="IdcInputPrefix">
        <instance>${coord:current(5)}</instance>
    </data-in>
</input-events>
```
8. output-events
一个Coordinator动作可能会生成一个或多个dataset实例，这些实例由output-events定义
```xml
<output-events>
    <data-out name="BB_OUTPUT_PREFIX" dataset="BbOutputPrefix">
        <instance>${coord:current(5)}</instance>
    </data-out>
    <data-out name="IDC_OUTPUT_PREFIX" dataset="IdcOutputPrefix">
        <instance>${coord:current(5)}</instance>
    </data-out>
</output-events>
```
9. action
定义coordinator需要触发的workflow，其中定义的property可以在workflow中使用，因为是定时任务，所以输入输出目录就是从这里动态生成的
```xml
<action>
	<workflow>
	  <app-path>${wf_app_path}</app-path>
	  <configuration>
	    <property>
	      <name>dayTime</name>
	      <value>${coord:formatTime(coord:dateOffset(coord:nominalTime(), -1, 'DAY'), 'yyyy-MM-dd')}</value>
	    </property>
	  </configuration>
	</workflow>
</action>
```
有几个常见的函数需要掌握：
${coord:dataIn(String name)}：获取input-events下指定的dataIn对应的所有路径，dataOut作用相同  
${coord:formatTime(String timeStamp, String format)}：格式化日期，format参数对应的模板是`yyyyMMddHHmmss`，详细的参考[官网](https://docs.oracle.com/javase/6/docs/api/java/text/SimpleDateFormat.html)  
${coord:dateOffset(String baseDate, int instance, String timeUnit)}：偏移指定的时间间隔，baseDate需传入带时区标准的日期时间格式，timeUnit的参数可以是DAY、HOUR、MINUTE  
${coord:nominalTime()}：Coordinator的开始时间加上整数倍的频率得到的时间，也就是应该运行当前工作流的时间，可以作为formatTime和dateOffset的输入参数
${coord:current(int n)}：返回日期时间：从一个Coordinator动作（Action）创建时开始计算，第n个dataset实例执行时间


## Extra
### Expression Language Functions
Oozie除了允许使用工作流作业属性来参数化工作流作业外，还提供了一组EL函数，这些函数支持对工作流动作节点和决策节点中的谓词进行更复杂的参数化，还有很多跟hadoop相关的常量和函数查看[官网](https://oozie.apache.org/docs/4.1.0/WorkflowFunctionalSpec.html#a4.2.4_Hadoop_EL_Constants)
1. Basic EL Constants
oozie定义了一些常量，可以直接拿来用
	- KB: 1024, one kilobyte.
	- MB: 1024 * KB, one megabyte.
	- GB: 1024 * MB, one gigabyte.
	- TB: 1024 * GB, one terabyte.
	- PB: 1024 * TG, one petabyte.
2. Workflow EL Functions
这部分直接可以在workflow配置文件中使用${wf:id()}调用，下面列出了常见的操作，更多属性查看[官网](https://oozie.apache.org/docs/4.1.0/WorkflowFunctionalSpec.html#a4.2.3_Workflow_EL_Functions)
```shell
String wf:id()  # 返回当前工作流的ID
String wf:name()  # 返回当前工作流的名称
String wf:appPath()  # 返回当前工作流的路径
String wf:conf(String name)  # 返回当前工作流配置属性的值，如果未定义则返回空字符串
String wf:user()  # 返回启动当前工作流的用户名
String wf:group()  # 返回当前工作流的组/ACL
String wf:callback(String stateVar)  # 返回当前工作流操作节点的回调URL, stateVar可以是该操作的退出状态(=OK=或ERROR)，也可以是执行任务的远程系统用退出状态替换的令牌
String wf:errorMessage(String message)  # 返回指定操作节点的错误消息，如果没有处于error状态的操作节点退出，则返回一个空字符串
```
### Workflow Lifecycle
oozie针对工作流定义了不同的状态，它在运行过程中可以处于任何状态
	- PREP:当工作流作业第一次创建时，它将处于PREP状态，定义了工作流但还没有运行
	- RUNNING:当创建的工作流启动时，它会进入RUNNING状态，当它没有达到结束状态时就会一直保持在RUNNING状态，直到错误或它被挂起
	- SUSPENDED:正在运行的工作流可以挂起，它将一直处于SUSPENDED状态，直到该工作流作业恢复或被终止
	- SUCCEEDED:当一个正在运行的工作流任务到达结束节点时，最终状态为SUCCEEDED
	- KILLED:当管理员或所有者通过对Oozie的请求杀死一个已创建的、正在运行的或挂起的工作流作业时，工作流将进入KILLED状态
	- FAILED:当一个正在运行的工作流作业由于意外错误而失败时，它将以FAILED状态结束
### 失败重试
工作流失败后oozie可以提供失败重试机制，需要指定重试间隔和重试次数，注意开启失败重试必须做好之前失败工作流的数据清理工作
    1. 第一步需要修改一个配置文件，默认oozie只会在几个指定的错误发生时失败重试，需要将它修改为只要发生错误就进行失败重试：`oozie.service.LiteWorkflowStoreService.user.retry.error.code.ext=ALL`  
    2. 第二步是在workflow配置文件中指定重试间隔和重试次数
```xml
<workflow-app name="etl_ds_hive2_action-${etl_name}" xmlns="uri:oozie:workflow:0.5">
    <start to="hive2_action"/>
    <action name="hive2_action" cred="hive2" retry-max="3" retry-interval="2" >  <!--指定失败重试次数和失败间隔，单位是分钟-->
        <ssh>
            <host>localhost:22<host>
            <command>chmod</command>
            <args>-R</args>
            <args>777</args>
            <args>/home/root/*</args>
        </ssh>
        <ok to="end"/>
        <error to="Kill"/>
    </action>
    <kill name="Kill">
        <message>Action failed, error message[${wf:errorMessage(wf:lastErrorNode())}]</message>
    </kill> 
    <end name="end"/>
</workflow-app>

```
 
 ### 配置可以解析UTC+8时区
 新安装的oozie默认只可以解析UTC格式的时间，配置后指定开始和结束时间时就可以使用东八区时间了。CDH配置高级中“oozie-site.xml 的 Oozie Server 高级配置代码段（安全阀）”这个选项内添加下面的代码后重启
 ```xml
<property>
    <name>oozie.processing.timezone</name>
    <value>GMT+0800</value>
</property>
 ```


## 示例
一个小例子，每五分钟执行一次，检测输入路径内的最近三个事件（按dataset的frequency往前数三个事件，如果对应的文件夹存在则满足条件，否则一直等待），满足条件后在指定的输出路径新建文件夹，注意使用fs action时的权限  
coordinator.xml
```xml
<coordinator-app name="coord-test" frequency="${coord:minutes(5)}"
     start="${start_time}" end="${end_time}" timezone="GMT+08:00"
     xmlns="uri:oozie:coordinator:0.1">
     <datasets>
          <dataset name="logs-1" frequency="${coord:minutes(1)}"
               initial-instance="${log_start_time}" timezone="GMT+08:00">
               <uri-template>${input_prefix}/${HOUR}${MINUTE}</uri-template>
               <done-flag></done-flag>
          </dataset>
          <dataset name="logs-2" frequency="${coord:minutes(5)}"
               initial-instance="${log_start_time}" timezone="GMT+08:00">
               <uri-template>${output_prefix}/${HOUR}${MINUTE}</uri-template>
               <done-flag></done-flag>
          </dataset>
     </datasets>
     <input-events>
          <data-in name="input" dataset="logs-1">
               <start-instance>${coord:current(-3)}</start-instance>
               <end-instance>${coord:current(0)}</end-instance>
          </data-in>
     </input-events>
     <output-events>
          <data-out name="output" dataset="logs-2">
               <instance>${coord:current(0)}</instance>
          </data-out>
     </output-events>
     <action>
          <workflow>
               <app-path>${wf_application_path}</app-path>
               <configuration>
                    <property>
                         <name>HDFS_INPUT</name>
                         <value>${coord:dataIn('input')}</value>
                    </property>
                    <property>
                         <name>HDFS_OUTPUT</name>
                         <value>${coord:dataOut('output')}</value>
                    </property>
               </configuration>
          </workflow>
     </action>
</coordinator-app>
```
workflow.xml
```xml
<workflow-app name="sample-wf" xmlns="uri:oozie:workflow:0.1">
    <start to="myssjob"/>
    <action name="myssjob">
         <fs>
            <!-- 注意执行权限 -->
            <mkdir path='${HDFS_OUTPUT}/result'/>
        </fs>
        <ok to="end"/>
        <error to="kill"/>
    </action>
    <kill name="kill">
        <message>Action failed, error message[${wf:errorMessage(wf:lastErrorNode())}]</message>
    </kill>
    <end name="end"/>
</workflow-app>
```
start.sh
```bash
#!/bin/bash

start_time=2022-07-21T13:30+0800
end_time=2022-07-21T13:40+0800
log_start_time=2022-07-21T13:20+0800
workflow_user=hdfs
input_prefix=/user/wxk/oozie/hdfs/input
output_prefix=/user/wxk/oozie/hdfs/output
name_node=hdfs://namenode.haohan.com:8020
wf_application_path=hdfs://namenode.haohan.com:8020/user/wxk/oozie/hdfs/config

oozie job -oozie http://localhost:11000/oozie -run \
    -D oozie.wf.validate.ForkJoin=false \
    -D oozie.use.system.libpath=true \
    -D oozie.coord.application.path=${wf_application_path} \  # 告知oozie配置所在位置，如果非定时任务则使用oozie.wf.application.path
    -D useStrictFilterStrategy=true \
    -D user.name=${workflow_user} \
    -D mapreduce.job.user.name=${workflow_user} \
    -D wf_application_path=${wf_application_path} \
    -D start_time=${start_time} \
    -D end_time=${end_time} \
    -D log_start_time=${log_start_time} \
    -D input_prefix=${input_prefix} \
    -D output_prefix=${output_prefix} \
    -D name_node=${name_node}
```