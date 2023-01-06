---
title: Spark源码-collect流程
author: 汪寻
date: 2022-10-18 11:17:41
updated: 2022-10-18 11:32:25
tags:
 - Spark
categories:
 - Software
---

Spark collect操作流程刨析，从代码中理解Spark执行流程

<!-- more -->

没有通过debug而是以collect为入口向下点，中间有几次RPC调用，了解基础的Netty即可找到它实际的调用方法。Spark版本为3.1.2

<div align=center><img src="collect.png"></div>

## SparkContext.collect
点进collect方法，它调用了sc的重载方法runJob，需要传入两个参数分别是当前rdd和一个处理函数，这个处理函数将运行在每个partition对数据进行处理
```scala
  def collect(): Array[T] = withScope {
    val results = sc.runJob(this, (iter: Iterator[T]) => iter.toArray)
    Array.concat(results: _*)
  }
```

## SparkContext.runJob[T, U: ClassTag](rdd: RDD[T], func: Iterator[T] => U)
点击runJob函数它继续调用自身的重载方法，第三个参数partitions表示处理函数作用在所有的partition，并不是所有的函数都会作用在所有的partition，例如first
```scala
  def runJob[T, U: ClassTag](rdd: RDD[T], func: Iterator[T] => U): Array[U] = {
    runJob(rdd, func, 0 until rdd.partitions.length)
  }
```

## SparkContext.runJob[T, U: ClassTag](rdd: RDD[T],func: Iterator[T] => U,partitions: Seq[Int])
继续点runJob会调用clean函数对处理函数进行闭包清理，有关闭包清理查看另一篇文章 [ClosureCleaner]()
```scala
  def runJob[T, U: ClassTag](
      rdd: RDD[T],
      func: Iterator[T] => U,
      partitions: Seq[Int]): Array[U] = {
    val cleanedFunc = clean(func)
    runJob(rdd, (ctx: TaskContext, it: Iterator[T]) => cleanedFunc(it), partitions)
  }
```

## SparkContext.runJob[T, U: ClassTag](rdd: RDD[T],func: (TaskContext, Iterator[T]) => U,partitions: Seq[Int],resultHandler: (Int, U) => Unit)
继续点两次runJob会到一个比较重要的函数，它几乎是所有action的入口函数
```scala
  def runJob[T, U: ClassTag](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      // resultHandler是一个回调函数，用来生成每一个结果
      resultHandler: (Int, U) => Unit): Unit = {
    if (stopped.get()) {
      throw new IllegalStateException("SparkContext has been shutdown")
    }
    // 标识调用当前方法的代码位置，例如在web界面看到的stage标识，分为短标识和长标识，短标识代表你写的代码中的具体位置和方法，长标识代表代码的调用路径
    val callSite = getCallSite
    val cleanedFunc = clean(func)
    logInfo("Starting job: " + callSite.shortForm)
    if (conf.getBoolean("spark.logLineage", false)) {
      logInfo("RDD's recursive dependencies:\n" + rdd.toDebugString)
    }
    // 在给定的rdd上运行action函数，并将结果放入resultHandler中
    dagScheduler.runJob(rdd, cleanedFunc, partitions, callSite, resultHandler, localProperties.get)
    // 进度标识，不重要
    progressBar.foreach(_.finishAll())
    rdd.doCheckpoint()
  }
```

### doCheckpoint

## DAGScheduler.runJob
向DAGScheduler提交一个action作业并等待作业完成后打印失败或成功日志
```scala
  def runJob[T, U](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      callSite: CallSite,
      resultHandler: (Int, U) => Unit,
      properties: Properties): Unit = {
    val start = System.nanoTime
    // 向DAGScheduler提交一个action作业，重要入口
    val waiter = submitJob(rdd, func, partitions, callSite, resultHandler, properties)
    // 等待作业执行完成
    ThreadUtils.awaitReady(waiter.completionFuture, Duration.Inf)
    // 作业成功打印日志，失败则打印错误
    waiter.completionFuture.value.get match {
      case scala.util.Success(_) =>
        logInfo("Job %d finished: %s, took %f s".format
          (waiter.jobId, callSite.shortForm, (System.nanoTime - start) / 1e9))
      case scala.util.Failure(exception) =>
        logInfo("Job %d failed: %s, took %f s".format
          (waiter.jobId, callSite.shortForm, (System.nanoTime - start) / 1e9))
        // SPARK-8644: Include user stack trace in exceptions coming from DAGScheduler.
        val callerStackTrace = Thread.currentThread().getStackTrace.tail
        exception.setStackTrace(exception.getStackTrace ++ callerStackTrace)
        throw exception
    }
  }
```

## DAGScheduler.submitJob
先对partitions进行处理，然后将作业JobSubmitted放入eventProcessLoop

SparkListenerJobStart继承自SparkListenerEvent，它有许多子类用来监控不同事件的运行状态，详情查看另一篇文章 [SparkListenerEvent]()
```scala
  def submitJob[T, U](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      callSite: CallSite,
      resultHandler: (Int, U) => Unit,
      properties: Properties): JobWaiter[U] = {
    // 如果存在给定的partition大于分区长度或者小于0则抛出异常
    val maxPartitions = rdd.partitions.length
    partitions.find(p => p >= maxPartitions || p < 0).foreach { p =>
      throw new IllegalArgumentException(
        "Attempting to access a non-existent partition: " + p + ". " +
          "Total number of partitions: " + maxPartitions)
    }
    // 提交一次作业可以有多个job，给每个job分配递增ID
    val jobId = nextJobId.getAndIncrement()
    // 处理partitions为空的情况，没有分区供你处理，直接标识任务开始任务结束
    if (partitions.isEmpty) {
      val clonedProperties = Utils.cloneProperties(properties)
      if (sc.getLocalProperty(SparkContext.SPARK_JOB_DESCRIPTION) == null) {
        // 标识调用的代码位置
        clonedProperties.setProperty(SparkContext.SPARK_JOB_DESCRIPTION, callSite.shortForm)
      }
      val time = clock.getTimeMillis()
      listenerBus.post(
        SparkListenerJobStart(jobId, time, Seq.empty, clonedProperties))
      listenerBus.post(
        SparkListenerJobEnd(jobId, time, JobSucceeded))
      // Return immediately if the job is running 0 tasks
      return new JobWaiter[U](this, jobId, 0, resultHandler)
    }

    assert(partitions.nonEmpty)
    val func2 = func.asInstanceOf[(TaskContext, Iterator[_]) => _]
    val waiter = new JobWaiter[U](this, jobId, partitions.size, resultHandler)
    // 将作业JobSubmitted放入eventProcessLoop，着重介绍DAGSchedulerEventProcessLoop
    eventProcessLoop.post(JobSubmitted(
      jobId, rdd, func2, partitions.toArray, callSite, waiter,
      Utils.cloneProperties(properties)))
    waiter
  }
```

## DAGScheduler.eventProcessLoop
DAGSchedulerEventProcessLoop继承自EventLoop，它提供了一个onReceive用来执行提交给它的事件，包括作业提交JobSubmitted、作业取消JobCancelled、map stage提交MapStageSubmitted等事件，它们统一继承自DAGSchedulerEvent

关于EventLoop它是一个事件循环，用于接收来自调用者（提交任务）的事件并处理事件线程中的所有事件。它将启动一个独占事件线程来处理所有事件，有兴趣的可以看一下源码，实现并不复杂
```scala
private[scheduler] class DAGSchedulerEventProcessLoop(dagScheduler: DAGScheduler)
  extends EventLoop[DAGSchedulerEvent]("dag-scheduler-event-loop") with Logging {

  private[this] val timer = dagScheduler.metricsSource.messageProcessingTimer

  // 从事件队列轮询事件时在事件线程中调用
  override def onReceive(event: DAGSchedulerEvent): Unit = {
    val timerContext = timer.time()
    try {
      doOnReceive(event)
    } finally {
      timerContext.stop()
    }
  }

  private def doOnReceive(event: DAGSchedulerEvent): Unit = event match {
    case JobSubmitted(jobId, rdd, func, partitions, callSite, listener, properties) =>
      dagScheduler.handleJobSubmitted(jobId, rdd, func, partitions, callSite, listener, properties)

    case MapStageSubmitted(jobId, dependency, callSite, listener, properties) =>
      dagScheduler.handleMapStageSubmitted(jobId, dependency, callSite, listener, properties)
    // 后面还有许多
  }

  override def onError(e: Throwable): Unit = {
    logError("DAGSchedulerEventProcessLoop failed; shutting down SparkContext", e)
    try {
      dagScheduler.doCancelAllJobs()
    } catch {
      case t: Throwable => logError("DAGScheduler failed to cancel all jobs.", t)
    }
    dagScheduler.sc.stopInNewThread()
  }

  override def onStop(): Unit = {
    // Cancel any active jobs in postStop hook
    dagScheduler.cleanUpAfterSchedulerStop()
  }
}
```

## DAGScheduler.handleJobSubmitted
提交一个job的操作，该函数中主要获取到了父级依赖，父级stage和ResultStage，标识job运行并提交ResultStage
```scala
  private[scheduler] def handleJobSubmitted(jobId: Int,
      finalRDD: RDD[_],
      func: (TaskContext, Iterator[_]) => _,
      partitions: Array[Int],
      callSite: CallSite,
      listener: JobListener,
      properties: Properties): Unit = {
    var finalStage: ResultStage = null
    try {
      // 获取ResultStage，每碰到一个action算子就产生一个ResultStage
      finalStage = createResultStage(finalRDD, func, partitions, jobId, callSite)
    } catch {
      case e: BarrierJobSlotsNumberCheckFailed =>
        val numCheckFailures = barrierJobIdToNumTasksCheckFailures.compute(jobId,
          (_: Int, value: Int) => value + 1)

        logWarning(s"Barrier stage in job $jobId requires ${e.requiredConcurrentTasks} slots, " +
          s"but only ${e.maxConcurrentTasks} are available. " +
          s"Will retry up to ${maxFailureNumTasksCheck - numCheckFailures + 1} more times")
        // 未达到最大失败次数时在一个新的线程中重新提交该任务
        if (numCheckFailures <= maxFailureNumTasksCheck) {
          messageScheduler.schedule(
            new Runnable {
              override def run(): Unit = eventProcessLoop.post(JobSubmitted(jobId, finalRDD, func,
                partitions, callSite, listener, properties))
            },
            timeIntervalNumTasksCheck,
            TimeUnit.SECONDS
          )
          return
        } else {
          barrierJobIdToNumTasksCheckFailures.remove(jobId)
          listener.jobFailed(e)
          return
        }

      case e: Exception =>
        logWarning("Creating new stage failed due to exception - job: " + jobId, e)
        listener.jobFailed(e)
        return
    }
    // Job submitted, clear internal data.
    barrierJobIdToNumTasksCheckFailures.remove(jobId)
    // 新建一个ActiveJob，每一个action算子是一个job
    val job = new ActiveJob(jobId, finalStage, callSite, listener, properties)
    clearCacheLocs()
    logInfo("Got job %s (%s) with %d output partitions".format(
      job.jobId, callSite.shortForm, partitions.length))
    logInfo("Final stage: " + finalStage + " (" + finalStage.name + ")")
    logInfo("Parents of final stage: " + finalStage.parents)
    logInfo("Missing parents: " + getMissingParentStages(finalStage))

    val jobSubmissionTime = clock.getTimeMillis()
    // 将此ActiveJob放入jobIdToActiveJob和activeJobs
    jobIdToActiveJob(jobId) = job
    activeJobs += job
    // 将ActiveJob绑定到ResultStage
    finalStage.setActiveJob(job)
    val stageIds = jobIdToStageIds(jobId).toArray
    val stageInfos = stageIds.flatMap(id => stageIdToStage.get(id).map(_.latestInfo))
    listenerBus.post(
      SparkListenerJobStart(job.jobId, jobSubmissionTime, stageInfos,
        Utils.cloneProperties(properties)))
    // 提交ResultStage
    submitStage(finalStage)
  }
```

### DAGScheduler.createResultStage
ResultStage继承自Stage，Stage有两个子类分别是ResultStage和ShuffleMapStage，ShuffleMapStage存在于两个shuffle依赖之间，而ResultStage则是整个job的最后一个依赖
```scala
  private def createResultStage(
      rdd: RDD[_],
      func: (TaskContext, Iterator[_]) => _,
      partitions: Array[Int],
      jobId: Int,
      callSite: CallSite): ResultStage = {
    // 返回给定rdd的直接父级的shuffle依赖以及与此stage的rdd关联的ResourceProfiles（ResourceProfile支持对指定Stage的资源如内存、磁盘等进行干预）
    val (shuffleDeps, resourceProfiles) = getShuffleDependenciesAndResourceProfiles(rdd)
    val resourceProfile = mergeResourceProfilesForStage(resourceProfiles)
    checkBarrierStageWithDynamicAllocation(rdd)
    checkBarrierStageWithNumSlots(rdd, resourceProfile)
    checkBarrierStageWithRDDChainPattern(rdd, partitions.toSet.size)
    // 根据当前rdd的父级shuffle依赖获取或者创建它的ShuffleMapStage
    val parents = getOrCreateParentStages(shuffleDeps, jobId)
    // stageId在同一个job中递增
    val id = nextStageId.getAndIncrement()
    val stage = new ResultStage(id, rdd, func, partitions, parents, jobId,
      callSite, resourceProfile.id)
    stageIdToStage(id) = stage  // 更新stageId和stage的map
    updateJobIdStageIdMaps(jobId, stage)  // 更新jobId和stageId的map
    stage
  }
```

## DAGScheduler.submitStage
提交当前ResultStage，但首先提交它的父级未提交的ShuffleMapStage，这个方法会从ResultStage向上迭代寻找父级ShuffleMapStage并从最开始向后提交stage
```scala
  private def submitStage(stage: Stage): Unit = {
    // 找到最早创建该stage的jobId
    val jobId = activeJobForStage(stage)
    if (jobId.isDefined) {
      logDebug(s"submitStage($stage (name=${stage.name};" +
        s"jobs=${stage.jobIds.toSeq.sorted.mkString(",")}))")
      if (!waitingStages(stage) && !runningStages(stage) && !failedStages(stage)) {
        // 寻找它的父级未提交的ShuffleMapStage
        val missing = getMissingParentStages(stage).sortBy(_.id)
        logDebug("missing: " + missing)
        if (missing.isEmpty) {
          logInfo("Submitting " + stage + " (" + stage.rdd + "), which has no missing parents")
          // 如果没找到则代表已经找到起始的ShuffleMapStage，从起始stage开始提交
          submitMissingTasks(stage, jobId.get)
        } else {
          // 如果找到了则将遍历继续寻找父级ShuffleMapStage的ShuffleMapStage
          for (parent <- missing) {
            submitStage(parent)
          }
          waitingStages += stage
        }
      }
    } else {
      abortStage(stage, "No active job for stage " + stage.id, None)
    }
  }
```

## DAGScheduler.submitMissingTasks
查找stage对应的需要运行的taskID和位置等信息，由TaskScheduler提交并运行

```scala
  private def submitMissingTasks(stage: Stage, jobId: Int): Unit = {
    
    // 返回需要计算的taskID
    val partitionsToCompute: Seq[Int] = stage.findMissingPartitions()

    // 省略

    // 获取taskID对应的运行位置
    val taskIdToLocations: Map[Int, Seq[TaskLocation]] = try {
      stage match {
        case s: ShuffleMapStage =>
          partitionsToCompute.map { id => (id, getPreferredLocs(stage.rdd, id))}.toMap
        case s: ResultStage =>
          partitionsToCompute.map { id =>
            val p = s.partitions(id)
            (id, getPreferredLocs(stage.rdd, p))
          }.toMap
      }
    } catch {
      case NonFatal(e) =>
        stage.makeNewStageAttempt(partitionsToCompute.size)
        listenerBus.post(SparkListenerStageSubmitted(stage.latestInfo,
          Utils.cloneProperties(properties)))
        abortStage(stage, s"Task creation failed: $e\n${Utils.exceptionString(e)}", Some(e))
        runningStages -= stage
        return
    }

    // 创建一个新的StageInfo并将_latestInfo指向最新的StageInfo
    stage.makeNewStageAttempt(partitionsToCompute.size, taskIdToLocations.values.toSeq)

    // 更新stage从DAGScheduler提交到TaskScheduler的时间并标识该stage一提交
    if (partitionsToCompute.nonEmpty) {
      stage.latestInfo.submissionTime = Some(clock.getTimeMillis())
    }
    listenerBus.post(SparkListenerStageSubmitted(stage.latestInfo,
      Utils.cloneProperties(properties)))

    // 将stage序列化并作为广播变量
    var taskBinary: Broadcast[Array[Byte]] = null
    var partitions: Array[Partition] = null
    try {
      var taskBinaryBytes: Array[Byte] = null
      RDDCheckpointData.synchronized {
        taskBinaryBytes = stage match {
          case stage: ShuffleMapStage =>
            JavaUtils.bufferToArray(
              closureSerializer.serialize((stage.rdd, stage.shuffleDep): AnyRef))
          case stage: ResultStage =>
            JavaUtils.bufferToArray(closureSerializer.serialize((stage.rdd, stage.func): AnyRef))
        }
        partitions = stage.rdd.partitions
      }

      if (taskBinaryBytes.length > TaskSetManager.TASK_SIZE_TO_WARN_KIB * 1024) {
        logWarning(s"Broadcasting large task binary with size " +
          s"${Utils.bytesToString(taskBinaryBytes.length)}")
      }
      // 将taskBinaryBytes广播出去
      taskBinary = sc.broadcast(taskBinaryBytes)
    } catch {
      case e: NotSerializableException =>
      // 省略
    }

    // 创建对应的ShuffleMapTask或者ResultTask，它们是Task的子类，对应ShuffleMapStage和ResultStage。一个Stage可以有多个task并行处理
    val tasks: Seq[Task[_]] = try {
      val serializedTaskMetrics = closureSerializer.serialize(stage.latestInfo.taskMetrics).array()
      stage match {
        case stage: ShuffleMapStage =>
          stage.pendingPartitions.clear()
          // 根据需要运行的taskId创建多个task
          partitionsToCompute.map { id =>
            val locs = taskIdToLocations(id)
            val part = partitions(id)
            stage.pendingPartitions += id
            new ShuffleMapTask(stage.id, stage.latestInfo.attemptNumber,
              taskBinary, part, locs, properties, serializedTaskMetrics, Option(jobId),
              Option(sc.applicationId), sc.applicationAttemptId, stage.rdd.isBarrier())
          }

        case stage: ResultStage =>
          partitionsToCompute.map { id =>
            val p: Int = stage.partitions(id)
            val part = partitions(p)
            val locs = taskIdToLocations(id)
            new ResultTask(stage.id, stage.latestInfo.attemptNumber,
              taskBinary, part, locs, id, properties, serializedTaskMetrics,
              Option(jobId), Option(sc.applicationId), sc.applicationAttemptId,
              stage.rdd.isBarrier())
          }
      }
    } catch {
      case NonFatal(e) =>
        abortStage(stage, s"Task creation failed: $e\n${Utils.exceptionString(e)}", Some(e))
        runningStages -= stage
        return
    }

    // 接下来就由TaskScheduler提交task去运行了，它的实现类是TaskSchedulerImpl，可以被其他scheduler实现例如YARN
    if (tasks.nonEmpty) {
      logInfo(s"Submitting ${tasks.size} missing tasks from $stage (${stage.rdd}) (first 15 " +
        s"tasks are for partitions ${tasks.take(15).map(_.partitionId)})")
      taskScheduler.submitTasks(new TaskSet(
        tasks.toArray, stage.id, stage.latestInfo.attemptNumber, jobId, properties,
        stage.resourceProfileId))
    } else {
      markStageAsFinished(stage, None)
      // 省略
    }
  }
```

## TaskScheduler.submitTasks
提交一个需要运行的task序列到Pool，最终由SchedulerBackend更新并启动它们
```scala
  override def submitTasks(taskSet: TaskSet): Unit = {
    val tasks = taskSet.tasks
    logInfo("Adding task set " + taskSet.id + " with " + tasks.length + " tasks "
      + "resource profile " + taskSet.resourceProfileId)
    this.synchronized {
      // 创建TaskSetManager，它在TaskSchedulerImpl中的单个TaskSet中调度任务。此类跟踪每个task，如果任务task失败（最多失败次数以内）重试任务
      val manager = createTaskSetManager(taskSet, maxTaskFailures)
      val stage = taskSet.stageId
      val stageTaskSets =
        taskSetsByStageIdAndAttempt.getOrElseUpdate(stage, new HashMap[Int, TaskSetManager])

      stageTaskSets.foreach { case (_, ts) =>
        ts.isZombie = true
      }
      stageTaskSets(taskSet.stageAttemptId) = manager
      // 将TaskSetManager添加到Pool队列中，由它来根据Fair或者FIFO算法调度TaskSetManager
      schedulableBuilder.addTaskSetManager(manager, manager.taskSet.properties)

      if (!isLocal && !hasReceivedTask) {
        starvationTimer.scheduleAtFixedRate(new TimerTask() {
          override def run(): Unit = {
            if (!hasLaunchedTask) {
              logWarning("Initial job has not accepted any resources; " +
                "check your cluster UI to ensure that workers are registered " +
                "and have sufficient resources")
            } else {
              this.cancel()
            }
          }
        }, STARVATION_TIMEOUT_MS, STARVATION_TIMEOUT_MS)
      }
      hasReceivedTask = true
    }
    // 更新并安排运行task，向driver发送一条ReviveOffers消息，再往后就是RPC相关的点了
    backend.reviveOffers()
  }
```

## CoarseGrainedSchedulerBackend.reviveOffers
backend是SchedulerBackend，它是一个特质，由其他调度系统继承并重写，例如Mesos、Yarn等等。

这里以YarnSchedulerBackend为例，假设提交到Yarn上，它其实调用的是CoarseGrainedSchedulerBackend的reviveOffers方法，向driver发送一个ReviveOffers消息
```scala
  // 创建DriverEndpoint
  protected def createDriverEndpoint(): DriverEndpoint = new DriverEndpoint()
  // 获取DriverEndpointRef，向谁发送消息就要获取谁的Ref
  val driverEndpoint = rpcEnv.setupEndpoint(ENDPOINT_NAME, createDriverEndpoint())
    // createDriverEndpoint方法被YarnSchedulerBackend重写了，所以返回的是YarnDriverEndpoint，但是YarnDriverEndpoint没重写receive方法，所以接收消息还是得看DriverEndpoint的receive
      override def createDriverEndpoint(): DriverEndpoint = {
        new YarnDriverEndpoint()
      }
  // ReviveOffers就是一个Spark内部的消息，像start或stop一样代表不同的含义
  override def reviveOffers(): Unit = Utils.tryLogNonFatalError {
    driverEndpoint.send(ReviveOffers)
  }
```

## DriverEndpoint.receive->ReviveOffers->makeOffers
DriverEndpoint的receive的方法对ReviveOffers的处理方法就是调用makeOffers方法，这个方法目的是封装task的任务描述，然后在executor启动这些任务
```scala
    private def makeOffers(): Unit = {
      // 返回我们提交的task的任务描述，包含taskId，executorId、task内容、jar包和file等
      val taskDescs = withLock {
        // 过滤掉killed的executor
        val activeExecutors = executorDataMap.filterKeys(isExecutorActive)
        val workOffers = activeExecutors.map {
          case (id, executorData) =>
            // 用来存放executor上可用的免费资源，暂且不管ExecutorData是如何管理它自身的资源的
            new WorkerOffer(id, executorData.executorHost, executorData.freeCores,
              Some(executorData.executorAddress.hostPort),
              executorData.resourcesInfo.map { case (rName, rInfo) =>
                (rName, rInfo.availableAddrs.toBuffer)
              }, executorData.resourceProfileId)
        }.toIndexedSeq
        // 获取task的任务描述，这个方法中会从上面的Pool对象中的队列里按FIFO或者Fair算法获取TaskSetManager列表，也就是我们刚才提交的task
        // 然后给这些TaskSetManager分配WorkerOffer资源，细节比较复杂
        scheduler.resourceOffers(workOffers, true)
      }
      if (taskDescs.nonEmpty) {
        launchTasks(taskDescs)  // 启动这些任务
      }
    }
```

## DriverEndpoint.launchTasks
启动这些任务，将task任务描述序列化后封装为LaunchTask消息发送到对应的executor去执行
```scala
    private def launchTasks(tasks: Seq[Seq[TaskDescription]]): Unit = {
      for (task <- tasks.flatten) {
        // 序列化TaskDescription
        val serializedTask = TaskDescription.encode(task)
        // 省略
        else {
          val executorData = executorDataMap(task.executorId)
          // 在这里分配task资源，这些资源在task运行完之后释放
          val rpId = executorData.resourceProfileId
          val prof = scheduler.sc.resourceProfileManager.resourceProfileFromId(rpId)
          val taskCpus = ResourceProfile.getTaskCpusOrDefaultForProfile(prof, conf)
          executorData.freeCores -= taskCpus
          task.resources.foreach { case (rName, rInfo) =>
            assert(executorData.resourcesInfo.contains(rName))
            executorData.resourcesInfo(rName).acquire(rInfo.addresses)
          }

          logDebug(s"Launching task ${task.taskId} on executor id: ${task.executorId} hostname: " +
            s"${executorData.executorHost}.")

          // 将LaunchTask消息发送到对应的executor去执行
          executorData.executorEndpoint.send(LaunchTask(new SerializableBuffer(serializedTask)))
        }
      }
    }
```

## ExecutorBackend.receive
上述LaunchTask消息最终发送给CoarseGrainedExecutorBackend，它实现了ExecutorBackend，所以直接去看它的receive方法
```scala
  override def receive: PartialFunction[Any, Unit] = {
    // 省略
    case LaunchTask(data) =>
      if (executor == null) {
        exitExecutor(1, "Received LaunchTask command but executor was null")
      } else {
        // 反序列化TaskDescription
        val taskDesc = TaskDescription.decode(data.value)
        logInfo("Got assigned task " + taskDesc.taskId)
        taskResources(taskDesc.taskId) = taskDesc.resources
        // 终于到了Executor
        executor.launchTask(this, taskDesc)
      }
    // 省略
  }
```

## Executor.launchTask
在该Executor执行task并将结果发送给driver
```scala
  def launchTask(context: ExecutorBackend, taskDescription: TaskDescription): Unit = {
    // 启动一个TaskRunner，它是一个单独的线程，去运行TaskDescription对应的task，执行逻辑在TaskRunner的run方法中
    // 最终还是调用Task的run方法，针对ShuffleMapTask和ResultTask有不同的执行方法，ShuffleMapTask则将中间结果写到磁盘中，ResultTask执行完之后发送StatusUpdate任务成功和结果消息给DriverEndpoint
    val tr = new TaskRunner(context, taskDescription, plugins)
    // 将该task标识为正在运行
    runningTasks.put(taskDescription.taskId, tr)
    // 执行该task
    threadPool.execute(tr)
    if (decommissioned) {
      log.error(s"Launching a task while in decommissioned state.")
    }
  }
```

## DriverEndpoint.receive->StatusUpdate
driver接收到结果数据消息后更新task状态、释放资源、将结果数据传给JobWaiter中的resultHandler
```scala
    override def receive: PartialFunction[Any, Unit] = {
      case StatusUpdate(executorId, taskId, state, data, resources) =>
        // 更新task状态，并将最终的结果数据传给最开始的JobWaiter中的resultHandler，由此就形成了一个闭环
        scheduler.statusUpdate(taskId, state, data.value)
        // 释放task申请的资源
        if (TaskState.isFinished(state)) {
          executorDataMap.get(executorId) match {
            case Some(executorInfo) =>
              val rpId = executorInfo.resourceProfileId
              val prof = scheduler.sc.resourceProfileManager.resourceProfileFromId(rpId)
              val taskCpus = ResourceProfile.getTaskCpusOrDefaultForProfile(prof, conf)
              executorInfo.freeCores += taskCpus
              resources.foreach { case (k, v) =>
                executorInfo.resourcesInfo.get(k).foreach { r =>
                  r.release(v.addresses)
                }
              }
              makeOffers(executorId)
            case None =>
              // Ignoring the update since we don't know about the executor.
              logWarning(s"Ignored task status update ($taskId state $state) " +
                s"from unknown executor with ID $executorId")
          }
        }
      // 省略
    }
```