---
title: Spark进阶-SparkContext之SparnEnv
author: 汪寻
date: 2022-08-11 20:29:45
updated: 2022-08-11 20:46:10
tags:
 - Spark
categories:
 - Software
---

主要介绍了SparkEnv的创建和主要组件的重要功能

<!-- more -->

Spark对任务的计算都依托于Executor的能力，所有的Executor都有自己的Spark执行环境SparkEnv。有了SparkEnv，就可以将数据存储在存储体系中；就能利用计算引擎对计算任务进行处理，就可以在节点间进行通信等。SparkEnv还提供了多种多样的内部组件，实现不同的功能

创建SparkEnv的主要代码是调用SparkEnv的create方法
```scala
  private def create(
      conf: SparkConf,
      executorId: String,
      bindAddress: String,
      advertiseAddress: String,
      port: Int,
      isLocal: Boolean,
      numUsableCores: Int,
      ioEncryptionKey: Option[Array[Byte]],
      listenerBus: LiveListenerBus = null,
      mockOutputCommitCoordinator: Option[OutputCommitCoordinator] = None): SparkEnv = {
    // 主要对账号、权限及身份认证进行设置和管理
    val securityManager = new SecurityManager(conf, ioEncryptionKey)
    // NettyRpcEnv RPC环境
    val rpcEnv = RpcEnv.create(systemName, bindAddress, advertiseAddress, port, conf,
      securityManager, clientMode = !isDriver)
    val serializer = instantiateClassFromConf[Serializer](
      "spark.serializer", "org.apache.spark.serializer.JavaSerializer")
    // 序列化管理器
    val serializerManager = new SerializerManager(serializer, conf, ioEncryptionKey)
    val closureSerializer = new JavaSerializer(conf)
    // 广播管理器
    val broadcastManager = new BroadcastManager(isDriver, conf, securityManager)
    // map信息跟踪处理
    val mapOutputTracker = if (isDriver) {
      new MapOutputTrackerMaster(conf, broadcastManager, isLocal)
    } else {
      new MapOutputTrackerWorker(conf)
    }
    // shuffle管理器
    val shuffleManager = instantiateClass[ShuffleManager](shuffleMgrClass)
        val memoryManager: MemoryManager =
      if (useLegacyMemoryManager) {
        new StaticMemoryManager(conf, numUsableCores)
      } else {
        UnifiedMemoryManager(conf, numUsableCores)
      }
    // 块管理器
    val blockManager = new BlockManager(executorId, rpcEnv, blockManagerMaster,
      serializerManager, conf, memoryManager, mapOutputTracker, shuffleManager,
      blockTransferService, securityManager, numUsableCores)
    // 度量系统
    val metricsSystem = if (isDriver) {
      MetricsSystem.createMetricsSystem("driver", conf, securityManager)
    } else {
      conf.set("spark.executor.id", executorId)
      val ms = MetricsSystem.createMetricsSystem("executor", conf, securityManager)
      ms.start()
      ms
    }
    // 判断是否可以将任务提交到hdfs的权限
    val outputCommitCoordinator = mockOutputCommitCoordinator.getOrElse {
      new OutputCommitCoordinator(conf, isDriver)
    }
    ...
  }
```

### SerializerManager

Spark中很多对象在通过网络传输或者写入存储体系时，都需要序列化。SparkEnv中有两个序列化的组件，分别是SerializerManager和closureSerializer。

这里创建的serializer默认为org.apache.spark.serializer.JavaSerializer，用户可以通过spark.serializer属性配置其他的序列化实现，如org.apache.spark.serializer.Kryo-Serializer。closureSerializer的实际类型固定为org.apache.spark.serializer.JavaSerializer，用户不能够自己指定。

需要注意的是Kryo序列化器比Java默认的序列化器更好用，但是它并不支持所有的Serializable对象，使用时需要手动指定并注册需要序列化的类
```scala
  new SparkConf()
          .setAppName("Test")
          .set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
          .registerKryoClasses(Array(
            classOf[String],
            classOf[Array[String]],
            classOf[GeneralMatcher],
            classOf[Map[Int, String]]
          ))
```

从源码中可以看到Spark默认对广播对象、Shuffle输出数据和溢出到磁盘的Shuffle的数据都是进行压缩的，而对RDD默认是不压缩的，默认的CompressionCodec是lz4
```scala
  // Whether to compress broadcast variables that are stored
  private[this] val compressBroadcast = conf.getBoolean("spark.broadcast.compress", true)
  // Whether to compress shuffle output that are stored
  private[this] val compressShuffle = conf.getBoolean("spark.shuffle.compress", true)
  // Whether to compress RDD partitions that are stored serialized
  private[this] val compressRdds = conf.getBoolean("spark.rdd.compress", false)
  // Whether to compress shuffle output temporarily spilled to disk
  private[this] val compressShuffleSpill = conf.getBoolean("spark.shuffle.spill.compress", true)

  private lazy val compressionCodec: CompressionCodec = CompressionCodec.createCodec(conf)  // lz4
```
它提供了对Block输入输出的压缩和加密，对Block输出流的序列化以及输入流的反序列化等方法

### BroadcastManager

Broadcast在实例化时就会调用自身的initialize方法，通过initialized属性判断TorrentBroadcastFactory是否已经实例化，另外两个成员方法分别是newBroadcast用来创建TorrentBroadcast实例，unbroadcast用来取消广播变量。

调用TorrentBroadcastFactory的newBroadcast方法时就会调用它的writeBlocks方法，它将需要广播的数据使用BlockManager写到Driver和Executor上。需要读取广播中的数据调用getValue方法，它调用私有的readBroadcastBlock方法。

writeBlocks
```scala
  private def writeBlocks(value: T): Int = {
    import StorageLevel._
    // Store a copy of the broadcast variable in the driver so that tasks run on the driver
    // do not create a duplicate copy of the broadcast variable's value.
    val blockManager = SparkEnv.get.blockManager
    // 将广播对象写入本地存储体系
    if (!blockManager.putSingle(broadcastId, value, MEMORY_AND_DISK, tellMaster = false)) {
      throw new SparkException(s"Failed to store $broadcastId in BlockManager")
    }
    // 将广播对象转换为多个块，块大小默认为4M
    val blocks =
      TorrentBroadcast.blockifyObject(value, blockSize, SparkEnv.get.serializer, compressionCodec)
    if (checksumEnabled) {
      checksums = new Array[Int](blocks.length)
    }
    // 遍历每一个块
    blocks.zipWithIndex.foreach { case (block, i) =>
      if (checksumEnabled) {
        checksums(i) = calcChecksum(block)
      }
      val pieceId = BroadcastBlockId(id, "piece" + i)
      val bytes = new ChunkedByteBuffer(block.duplicate())
      // 以序列化的方式将块写入driver和executor
      if (!blockManager.putBytes(pieceId, bytes, MEMORY_AND_DISK_SER, tellMaster = true)) {
        throw new SparkException(s"Failed to store $pieceId of $broadcastId in local BlockManager")
      }
    }
    blocks.length
  }
```

readBroadcastBlock
```scala
  private def readBroadcastBlock(): T = Utils.tryOrIOException {
    TorrentBroadcast.synchronized {
      setConf(SparkEnv.get.conf)
      val blockManager = SparkEnv.get.blockManager
      // 首先从本地找广播变量
      blockManager.getLocalValues(broadcastId).map(_.data.next()) match {
        case Some(x) =>
          // 如果可以获取到则加锁并返回该对象
          releaseLock(broadcastId)
          x.asInstanceOf[T]

        case None =>
          logInfo("Started reading broadcast variable " + id)
          val startTimeMs = System.currentTimeMillis()
          // 本地获取不到则到driver和executor获取块
          val blocks = readBlocks().flatMap(_.getChunks())
          logInfo("Reading broadcast variable " + id + " took" + Utils.getUsedTimeMs(startTimeMs))
          // 将获取到的块再转换回原来的对象
          val obj = TorrentBroadcast.unBlockifyObject[T](
            blocks, SparkEnv.get.serializer, compressionCodec)
          // Store the merged copy in BlockManager so other tasks on this executor don't
          // need to re-fetch it.
          val storageLevel = StorageLevel.MEMORY_AND_DISK
          // 最后再将原来的对象写入到本地的存储体系
          if (!blockManager.putSingle(broadcastId, obj, storageLevel, tellMaster = false)) {
            throw new SparkException(s"Failed to store $broadcastId in BlockManager")
          }
          obj
      }
    }
  }
```

<div align=center><img src="readBroadcast.jpg"></div>

### MapOutputTracker

mapOutputTracker用于跟踪map任务的输出状态，此状态便于reduce任务定位map输出结果所在的节点地址，进而获取中间输出结果。每个map任务或者reduce任务都会有其唯一标识，分别为mapId和reduceId。每个reduce任务的输入可能是多个map任务的输出，reduce会到各个map任务所在的节点上拉取Block，这一过程叫做Shuffle。每次Shuffle都有唯一的标识shuffleId。

```scala
  // 注册或查找MapOutputTrackerEndpoint
  def registerOrLookupEndpoint(
      name: String, endpointCreator: => RpcEndpoint):
    RpcEndpointRef = {
    if (isDriver) {
      logInfo("Registering " + name)
      rpcEnv.setupEndpoint(name, endpointCreator)
    } else {
      RpcUtils.makeDriverRef(name, conf, rpcEnv)
    }
  }

  // Driver则创建MapOutputTrackerMaster，Executor则创建MapOutputTrackerWorker
  val mapOutputTracker = if (isDriver) {
    new MapOutputTrackerMaster(conf, broadcastManager, isLocal)
  } else {
    new MapOutputTrackerWorker(conf)
  }

  // trackerEndpoint属性持有MapOutputTrackerMasterEndpoint
  mapOutputTracker.trackerEndpoint = registerOrLookupEndpoint(MapOutputTracker.ENDPOINT_NAME,
    new MapOutputTrackerMasterEndpoint(
      rpcEnv, mapOutputTracker.asInstanceOf[MapOutputTrackerMaster], conf))
```

可以看到针对当前实例是Driver还是Executor，创建mapOutputTracker的方式有所不同。
- 如果当前应用程序是Driver，则创建MapOutputTrackerMaster，然后创建MapOutputTrackerMasterEndpoint，并且注册到Dispatcher中，注册名为MapOutputTracker。
- 如果当前应用程序是Executor，则创建MapOutputTrackerWorker，并从远端Driver实例的NettyRpcEnv的Dispatcher中查找MapOutputTrackerMasterEndpoint的引用。
无论是Driver还是Executor，最后都由mapOutputTracker的属性trackerEndpoint持有MapOutputTrackerMasterEndpoint的引用

重点看一下MapOutputTracker中获取map状态信息的方法getStatuses
```scala
  private def getStatuses(shuffleId: Int): Array[MapStatus] = {
    val statuses = mapStatuses.get(shuffleId).orNull
    // 从当前MapOutputTracker的mapstatuses缓存中获取MapStatus数组，有的话直接返回
    if (statuses == null) {
      logInfo("Don't have map outputs for shuffle " + shuffleId + ", fetching them")
      val startTime = System.currentTimeMillis
      var fetchedStatuses: Array[MapStatus] = null
      // 因为可能有多个线程获取，所以必须设为线程安全的操作
      fetching.synchronized {
        // fetching存储正在获取map信息的shuffleId，说明其他线程正在获取，当前线程等待即可
        while (fetching.contains(shuffleId)) {
          try {
            fetching.wait()
          } catch {
            case e: InterruptedException =>
          }
        }

        // 这里有两种情况，第一种情况是第一个进来的线程走到这并把shuffleId放入fetching；
        // 第二种情况是后来的线程在线程解除等待后走到这，此时fetchedStatuses可能已被第一个线程放入对应的map信息
        fetchedStatuses = mapStatuses.get(shuffleId).orNull
        if (fetchedStatuses == null) {
          fetching += shuffleId
        }
      }

      // 第一个线程执行里面的操作
      if (fetchedStatuses == null) {
        logInfo("Doing the fetch; tracker endpoint = " + trackerEndpoint)
        try {
          // askTracker向MapOutputTrackerMasterEndpoint发送GetMapOutputStatuses消息，以获取map任务的状态信息
          val fetchedBytes = askTracker[Array[Byte]](GetMapOutputStatuses(shuffleId))
          // 请求方接收到map任务状态信息后，调用MapOutputTracker的deserializeMapStatuses方法对map任务状态进行反序列化操作，然后放入本地的mapStatuses缓存中
          fetchedStatuses = MapOutputTracker.deserializeMapStatuses(fetchedBytes)
          logInfo("Got the output locations")
          mapStatuses.put(shuffleId, fetchedStatuses)
        } finally {
          // 不管这次是否获取到map信息，都需要把shuffleId从fetching移除并唤醒其他正在等待的线程，如果获取失败后续线程会继续执行上面的操作
          fetching.synchronized {
            fetching -= shuffleId
            fetching.notifyAll()
          }
        }
      }
      logDebug(s"Fetching map output statuses for shuffle $shuffleId took " +
        s"${System.currentTimeMillis - startTime} ms")

      // 如果获取到的话就直接返回
      if (fetchedStatuses != null) {
        return fetchedStatuses
      } else {
        logError("Missing all output locations for shuffle " + shuffleId)
        throw new MetadataFetchFailedException(
          shuffleId, -1, "Missing all output locations for shuffle " + shuffleId)
      }
    } else {
      // 后续线程直接从当前MapOuputTracker的mapStatuses缓存中获取对应的map信息
      return statuses
    }
  }
```

#### MapOutputTrackerMaster

接下来重点看一下MapOutputTrackerMaster，它提供了获取map信息的具体实现方法，也就是`askTracker[Array[Byte]](GetMapOutputStatuses(shuffleId))`的具体实现

MapOutputTrackerMaster的几个重要属性：
- mapStatuses：用于存储shuffleId与Array[MapStatus]的映射关系。由于MapStatus维护了map输出Block的地址BlockManagerId，所以reduce任务知道从何处获取map任务的中间输出
- cachedSerializedStatuses：用于存储shuffleId与序列化后的状态的映射关系。其中key对应shuffleId, value为对MapStatus序列化后的字节数组。
- mapOutputRequests：使用阻塞队列来缓存GetMapOutputMessage（获取map任务输出）的请求
- threadpool：用于获取map输出的固定大小的线程池。此线程池提交的线程都以后台线程运行，且线程名以map-output-dispatcher为前缀，线程池大小可以使用spark.shuffle.mapOutput.dispatcher.numThreads属性配置，默认大小为8

在创建MapOutputTrackerMaster的最后，会创建对map输出请求进行处理的线程池threadpool，它里面有固定数量的线程处理Executor发送过来的获取map信息的请求
```scala
  private val threadpool: ThreadPoolExecutor = {
    val numThreads = conf.getInt("spark.shuffle.mapOutput.dispatcher.numThreads", 8)
    val pool = ThreadUtils.newDaemonFixedThreadPool(numThreads, "map-output-dispatcher")
    for (i <- 0 until numThreads) {
      // 启动与线程池大小相同数量的线程，每个线程执行的任务都是MessageLoop
      pool.execute(new MessageLoop)
    }
    pool
  }

  // MessageLoop实现了Java的Runnable接口
  private class MessageLoop extends Runnable {
    override def run(): Unit = {
      try {
        while (true) {
          try {
            // 从mapOutputRequests中获取GetMapOutputMessage
            // 由于mapOutputRequests是个阻塞队列，所以当mapOutputRequests中没有GetMapOutputMessage时，MessageLoop线程会被阻塞
            // GetMapOutputMessage是个样例类，包含了shuffleId和RpcCallContext两个属性
            val data = mapOutputRequests.take()
            // 如果取到的GetMapOutputMessage是PoisonPill（“毒药”），那么此MessageLoop线程将退出（通过return语句）
            // 随后将PoisonPill重新放入到mapOutput-Requests中，这是因为threadpool线程池极有可能不止一个MessageLoop线程，为了让大家都“毒发身亡”，还需要把“毒药”放回到receivers中，这样其他“活着”的线程就会再次误食“毒药”，达到所有MessageLoop线程都结束的效果
             if (data == PoisonPill) {
              mapOutputRequests.offer(PoisonPill)
              return
            }
            val context = data.context
            val shuffleId = data.shuffleId
            val hostPort = context.senderAddress.hostPort
            logDebug("Handling request to send map output locations for shuffle " + shuffleId +
              " to " + hostPort)
            // 调用getSerializedMapOutputStatuses方法获取GetMapOutputMessage携带的shuffleId所对应的序列化任务状态信息
            val mapOutputStatuses = getSerializedMapOutputStatuses(shuffleId)
            // 调用RpcCallContext的回调方法reply，将序列化的map任务状态信息返回给客户端（即其他节点的Executor）
            context.reply(mapOutputStatuses)
          } catch {
            case NonFatal(e) => logError(e.getMessage, e)
          }
        }
      } catch {
        case ie: InterruptedException => // exit
      }
    }
  }
```

最后主要通过调用MapOutputTrackerMaster的post方法将GetMapOutputMessage放入mapOutputRequests
```scala
  def post(message: GetMapOutputMessage): Unit = {
    mapOutputRequests.offer(message)
  }
```

MapOutputTrackerMaster的运行原理

<div align=center><img src="MapOutputTrackerMaster.jpg"></div>

1. 表示某个Executor调用MapOutputTrackerWorker的getStatuses方法获取某个shuffle的map任务状态信息，当发现本地的mapStatuses没有相应的缓存，则调用askTracker方法发送GetMapOutputStatuses消息。askTracker实际是通过MapOutputTrackerMasterEndpoint的NettyRpcEndpointRef向远端发送GetMapOutputStatuses消息。发送实际依托于NettyRpcEndpointRef持有的TransportClient。MapOutputTrackerMasterEndpoint在接收到GetMapOutputStatuses消息后，将GetMapOutputMessage消息放入mapOutput Requests队尾
2. 表示MessageLoop线程从mapOutputRequests队头取出GetMapOutputMessage
3. 表示从shuffleIdLocks数组中取出与当前GetMapOutputMessage携带的shuffleId相对应的锁
4. 表示首先从cachedSerializedStatuses缓存中获取shuffleId对应的序列化任务状态信息
5. 表示当cachedSerializedStatuses中没有shuffleId对应的序列化任务状态信息，则获取mapStatuses中缓存的shuffleId对应的任务状态数组
6. 表示将任务状态数组进行序列化，然后使用BroadcastManager对序列化的任务状态进行广播
7. 表示将序列化的任务状态放入cachedSerializedStatuses缓存中
8. 表示将广播对象放入cachedSerializedBroadcast缓存中
9. 表示将获得的序列化任务状态信息，通过回调GetMapOutputMessage消息携带的RpcCallContext的reply方法回复客户端

#### Shuffle注册

DAGScheduler在创建ShuffleMapStage的时候，将调用Map-OutputTrackerMaster的containsShuffle方法，查看是否已经存在shuffleId对应的MapStatus。如果MapOutputTrackerMaster中未注册此shuffleId，那么调用MapOutput-TrackerMaster的registerShuffle方法注册shuffleId
```scala
  // 查询ShuffleId是否被跟踪
  def containsShuffle(shuffleId: Int): Boolean = {
    cachedSerializedStatuses.contains(shuffleId) || mapStatuses.contains(shuffleId)
  }

  // 注册一个MapStatuses为空的ShuffleId
  def registerShuffle(shuffleId: Int, numMaps: Int) {
    if (mapStatuses.put(shuffleId, new Array[MapStatus](numMaps)).isDefined) {
      throw new IllegalArgumentException("Shuffle ID " + shuffleId + " registered twice")
    }
    // add in advance
    shuffleIdLocks.putIfAbsent(shuffleId, new Object())
  }

  // 
  ```

当ShuffleMapStage内的所有ShuffleMapTask运行成功后，将调用MapOutputTrackerMaster的registerMapOutputs方法。registerMapOutputs方法将把ShuffleMapStage中每个Shuffle-MapTask的MapStatus保存到shuffleId在mapStatuses中对应的数组中
```scala
  def registerMapOutputs(shuffleId: Int, statuses: Array[MapStatus], changeEpoch: Boolean = false) {
    mapStatuses.put(shuffleId, statuses.clone())
    if (changeEpoch) {
      incrementEpoch()
    }
  }
```

### 构建存储体系

存储体系。存储体系中最重要的组件包括Shuffle管理器ShuffleManager、内存管理器MemoryManager、块传输服务BlockTransferService、对所有BlockManager进行管理的BlockManagerMaster、磁盘块管理器DiskBlockManager、块锁管理器BlockInfoManager及块管理器BlockManager，这里只看各个组件的实例化，详细的内容在其他文章中说明
```scala
    val shortShuffleMgrNames = Map(
      "sort" -> classOf[org.apache.spark.shuffle.sort.SortShuffleManager].getName,
      "tungsten-sort" -> classOf[org.apache.spark.shuffle.sort.SortShuffleManager].getName)
    val shuffleMgrName = conf.get("spark.shuffle.manager", "sort")
    val shuffleMgrClass = shortShuffleMgrNames.getOrElse(shuffleMgrName.toLowerCase, shuffleMgrName)
    val shuffleManager = instantiateClass[ShuffleManager](shuffleMgrClass)

    val useLegacyMemoryManager = conf.getBoolean("spark.memory.useLegacyMode", false)
    val memoryManager: MemoryManager =
      if (useLegacyMemoryManager) {
        new StaticMemoryManager(conf, numUsableCores)
      } else {
        UnifiedMemoryManager(conf, numUsableCores)
      }

    val blockManagerPort = if (isDriver) {
      conf.get(DRIVER_BLOCK_MANAGER_PORT)
    } else {
      conf.get(BLOCK_MANAGER_PORT)
    }

    val blockTransferService =
      new NettyBlockTransferService(conf, securityManager, bindAddress, advertiseAddress,
        blockManagerPort, numUsableCores)

    val blockManagerMaster = new BlockManagerMaster(registerOrLookupEndpoint(
      BlockManagerMaster.DRIVER_ENDPOINT_NAME,
      new BlockManagerMasterEndpoint(rpcEnv, isLocal, conf, listenerBus)),
      conf, isDriver)

    // NB: blockManager is not valid until initialize() is called later.
    val blockManager = new BlockManager(executorId, rpcEnv, blockManagerMaster,
      serializerManager, conf, memoryManager, mapOutputTracker, shuffleManager,
      blockTransferService, securityManager, numUsableCores)
```

1. 根据spark.shuffle.manager属性，实例化ShuffleManager。Spark2.x.x版本提供了sort和tungsten-sort两种ShuffleManager的实现。无论是sort还是tungsten-sort，其实现类都是SortShuffleManager
2. MemoryManager的主要实现有StaticMemoryManager和UnifiedMemoryManager。StaticMemoryManager是Spark早期版本遗留下来的内存管理器实现，可以配置spark.memory.useLegacyMode属性来指定，该属性默认为false，因此默认的内存管理器是UnifiedMemoryManager
3. 获取当前SparkEnv的块传输服务BlockTransferService对外提供的端口号。如果当前实例是Driver，则从SparkConf中获取由常量DRIVER_BLOCK_MANAGER_PORT指定的端口。如果当前实例是Executor，则从SparkConf中获取由常量BLOCK_MANAGER_PORT指定的端口
4. 创建块传输服务BlockTransferService。这里使用的是BlockTransferService的子类NettyBlockTransferService, NettyBlockTransferService将提供对外的块传输服务。也正是因为MapOutputTracker与NettyBlockTransferService的配合，才实现了Spark的Shuffle
5. 查找或注册BlockManagerMasterEndpoint，这里和MapOutputTracker处理方式相同