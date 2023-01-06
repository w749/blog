---
title: Spark进阶-BlockManager
author: 汪寻
date: 2022-11-02 10:25:51
updated: 2022-11-02 10:45:42
tags:
 - Spark
categories:
 - Software
---

Spark BlockManager及相关组件和主要运行流程介绍

<!-- more -->
> 源码版本是Spark 3.1.2

## BlockManagerMaster
之所以以BlockManagerMaster为起点有两个原因，第一个是因为它的初始化早于BlockManager，第二个是因为它负责将BlockManager的请求操作发送给Driver的BlockManagerMasterEndpoint由它来处理一系列请求，driver和executor都有BlockManagerMaster

它的初始化代码在SparkEnv的create方法中，现在不管是driver还是executor都有自己的BlockManagerMaster，并且都拿到了BlockManagerMaster的RpcEndpointRef和BlockManagerMasterHeartbeat的RpcEndpointRef
```scala
    val blockManagerMaster = new BlockManagerMaster(
      // 创建或者查找对应的RpcEndpointRef，如果在driver端则需要注册，如果是executor则通过名称检索对应的RpcEndpointRef。这里返回BlockManagerMaster的RpcEndpointRef
      registerOrLookupEndpoint(
        BlockManagerMaster.DRIVER_ENDPOINT_NAME,
        new BlockManagerMasterEndpoint(
          rpcEnv,
          isLocal,
          conf,
          listenerBus,
          if (conf.get(config.SHUFFLE_SERVICE_FETCH_RDD_ENABLED)) {
            externalShuffleClient
          } else {
            None
          }, blockManagerInfo,
          mapOutputTracker.asInstanceOf[MapOutputTrackerMaster])),
      // 返回BlockManagerMasterHeartbeat的RpcEndpointRef，不重点关注
      registerOrLookupEndpoint(
        BlockManagerMaster.DRIVER_HEARTBEAT_ENDPOINT_NAME,
        new BlockManagerMasterHeartbeatEndpoint(rpcEnv, isLocal, blockManagerInfo)),
      conf,
      isDriver)
```

## BlockManagerMasterEndpoint
它是的作用是跟踪并保存BlockManager的状态，处理由BlockManagerMaster发送来的一些操作请求并返回所需的状态数据，例如GetLocations（获取指定blockId位置）、RemoveBroadcast（从各BlockManager移除广播变量）等等。当然它只是个中转站，用来解析请求内容并将它发送给其他的BlockManager（driver或者executor）去处理

### 重要属性
- blockManagerInfo: mutable.Map[BlockManagerId, BlockManagerInfo] 维护BlockManagerId和BlockManagerInfo的关系，初始化时它是空的
- executorIdToLocalDirs: Cache[String, Array[String]] 维护executorId和localDirs的映射关系
- blockManagerIdByExecutor: mutable.HashMap[String, BlockManagerId] 维护executorId和BlockManagerId的映射关系
- blockLocations: JHashMap[BlockId, mutable.HashSet[BlockManagerId]] 维护blockId对应拥有此block的BlockMangerId的映射关系

### BlockManagerMasterEndpoint.register
每个BlockManager都需要在BlockManagerMasterEndpoint注册，来看一下register方法都做了哪些事
```scala
  private def register(
      idWithoutTopologyInfo: BlockManagerId,
      localDirs: Array[String],
      maxOnHeapMemSize: Long,
      maxOffHeapMemSize: Long,
      storageEndpoint: RpcEndpointRef): BlockManagerId = {
    // 重新封装BlockManagerId
    val id = BlockManagerId(
      idWithoutTopologyInfo.executorId,
      idWithoutTopologyInfo.host,
      idWithoutTopologyInfo.port,
      topologyMapper.getTopologyForHost(idWithoutTopologyInfo.host))

    val time = System.currentTimeMillis()
    // 将executorId和磁盘地址的映射维护到executorIdToLocalDirs
    executorIdToLocalDirs.put(id.executorId, localDirs)
    // register时blockManagerInfo和blockManagerIdByExecutor不能包含相同的id信息
    if (!blockManagerInfo.contains(id)) {
      blockManagerIdByExecutor.get(id.executorId) match {
        case Some(oldId) =>
          // A block manager of the same executor already exists, so remove it (assumed dead)
          logError("Got two different block manager registrations on same executor - "
              + s" will replace old one $oldId with new one $id")
          removeExecutor(id.executorId)
        case None =>
      }
      logInfo("Registering block manager %s with %s RAM, %s".format(
        id.hostPort, Utils.bytesToString(maxOnHeapMemSize + maxOffHeapMemSize), id))

      // 维护executorId和BlockManagerId
      blockManagerIdByExecutor(id.executorId) = id

      val externalShuffleServiceBlockStatus =
        if (externalShuffleServiceRddFetchEnabled) {
          val externalShuffleServiceBlocks = blockStatusByShuffleService
            .getOrElseUpdate(externalShuffleServiceIdOnHost(id), new JHashMap[BlockId, BlockStatus])
          Some(externalShuffleServiceBlocks)
        } else {
          None
        }

      // 维护BlockManagerId和BlockManagerInfo
      blockManagerInfo(id) = new BlockManagerInfo(id, System.currentTimeMillis(),
        maxOnHeapMemSize, maxOffHeapMemSize, storageEndpoint, externalShuffleServiceBlockStatus)

      if (pushBasedShuffleEnabled) {
        addMergerLocation(id)
      }
    }
    listenerBus.post(SparkListenerBlockManagerAdded(time, id, maxOnHeapMemSize + maxOffHeapMemSize,
        Some(maxOnHeapMemSize), Some(maxOffHeapMemSize)))
    id
  }
```

### 以RemoveBroadcast为例跟踪消息流程
```scala
  rddBroadcast.unpersist()  // 程序入口
  unpersist(blocking = false)
  doUnpersist(blocking)
  TorrentBroadcast.doUnpersist(blocking: Boolean)
  TorrentBroadcast.unpersist(id, removeFromDriver = false, blocking)
  // 由driver的BlockManager的BlockManagerMaster发送RemoveBroadcast消息
  SparkEnv.get.blockManager.master.removeBroadcast(id, removeFromDriver, blocking)
  // 向BlockManagerMasterEndpoint发送RemoveBroadcast消息
  driverEndpoint.askSync[Future[Seq[Int]]](RemoveBroadcast(broadcastId, removeFromMaster))
  // 消息会被这个方法处理，查看RemoveBroadcast消息的处理方法就行
  BlockManagerMasterEndpoint.receiveAndReply(context: RpcCallContext)
  BlockManagerMasterEndpoint.removeBroadcast(broadcastId: Long, removeFromDriver: Boolean)
  // BlockManagerMasterEndpoint处理不了，将它发送给BlockManagerStorageEndpoint，BlockManagerStorageEndpoint相关介绍往下看
  bm.storageEndpoint.ask[Int](removeMsg).recover
  BlockManagerStorageEndpoint.receiveAndReply(context: RpcCallContext)
  blockManager.removeBroadcast(broadcastId, tellMaster = true)  // 最终它会调用对应BlockManager的removeBroadcast方法
```
例如RegisterBlockManager、GetLocations这些消息BlockManagerMasterEndpoint可以处理，因为所有的BlockManager都在它这注册，所以它自己处理完之后就可以返回，类似移除Block、移除Shuffle都由各自Executor的BlockManager完成所有发送给对应的BlockManagerStorageEndpoint

## BlockManagerStorageEndpoint
它的作用是接收从BlockManagerMasterEndpoint接收消息并在自己对应的BlockManager执行对应的操作，例如上面的RemoveBroadcast，它和BlockManager是一对一对应的。下面看一下它的初始化
```scala
  // 它的初始化在BlockManager实例化过程中已经完成
  private val storageEndpoint = rpcEnv.setupEndpoint(
    "BlockManagerEndpoint" + BlockManager.ID_GENERATOR.next,
    new BlockManagerStorageEndpoint(rpcEnv, this, mapOutputTracker))

  // 向BlockManagerMasterEndpoint注册自己
  val idFromMaster = master.registerBlockManager(
    id,
    diskBlockManager.localDirsString,
    maxOnHeapMemory,
    maxOffHeapMemory,
    storageEndpoint)
```
在向BlockManagerMasterEndpoint注册时就将BlockManagerStorageEndpoint一起已发送去了，随后又封装在blockManagerInfo对应的BlockManagerInfo中，这样BlockManagerMasterEndpoint就可以向任何一个BlockManager的BlockManagerStorageEndpoint发送消息了

## BlockManager
说了那么多终于到主角了，BlockManager运行在driver和executor上，它向用户提供了在磁盘或者内存中读取或者写入block数据的接口，在它之下仍然有更底层的实现（DiskStore、MemoryStore）
### BlockManager初始化
创建BlockManager实例在SparkEnv中`val blockManager = new BlockManager(...`，创建实例的同时有许多组件也被实例化了，例如DiskBlockManager、MemoryStore、DiskStore、BlockManagerStorageEndpoint、BlockInfoManager等等。只有在调用它的initialize方法时该BlockManager才会真正被初始化
```scala
  def initialize(appId: String): Unit = {
    blockTransferService.init(this)
    externalBlockStoreClient.foreach { blockStoreClient =>
      blockStoreClient.init(appId)
    }
    blockReplicationPolicy = {
      val priorityClass = conf.get(config.STORAGE_REPLICATION_POLICY)
      val clazz = Utils.classForName(priorityClass)
      val ret = clazz.getConstructor().newInstance().asInstanceOf[BlockReplicationPolicy]
      logInfo(s"Using $priorityClass for block replication policy")
      ret
    }

    // 初始化BlockManagerId
    val id = BlockManagerId(executorId, blockTransferService.hostName, blockTransferService.port, None)
    // 向BlockManagerMasterEndpoint注册自己
    val idFromMaster = master.registerBlockManager(
      id,
      diskBlockManager.localDirsString,
      maxOnHeapMemory,
      maxOffHeapMemory,
      storageEndpoint)

    blockManagerId = if (idFromMaster != null) idFromMaster else id
    // Shuffle的服务ID，一般也是当前BlockManagerId
    shuffleServerId = if (externalShuffleServiceEnabled) {
      logInfo(s"external shuffle service port = $externalShuffleServicePort")
      BlockManagerId(executorId, blockTransferService.hostName, externalShuffleServicePort)
    } else {
      blockManagerId
    }

    // Register Executors' configuration with the local shuffle service, if one should exist.
    if (externalShuffleServiceEnabled && !blockManagerId.isDriver) {
      registerWithExternalShuffleServer()
    }

    hostLocalDirManager = {
      if (conf.get(config.SHUFFLE_HOST_LOCAL_DISK_READING_ENABLED) &&
          !conf.get(config.SHUFFLE_USE_OLD_FETCH_PROTOCOL)) {
        Some(new HostLocalDirManager(
          futureExecutionContext,
          conf.get(config.STORAGE_LOCAL_DISK_BY_EXECUTORS_CACHE_SIZE),
          blockStoreClient))
      } else {
        None
      }
    }

    logInfo(s"Initialized BlockManager: $blockManagerId")
  }
```

### write block
write block最终都汇聚到两个方法，BlockStoreUpdater.save和BlockManager.doPutIterator，下面分别看一下这两个方法
BlockManager.doPutIterator写入iterator数据
```scala
  private def doPutIterator[T](
      blockId: BlockId,
      iterator: () => Iterator[T],
      level: StorageLevel,
      classTag: ClassTag[T],
      tellMaster: Boolean = true,
      keepReadLock: Boolean = false): Option[PartiallyUnrolledIterator[T]] = {
    doPut(blockId, level, classTag, tellMaster = tellMaster, keepReadLock = keepReadLock) { info =>
      val startTimeNs = System.nanoTime()
      var iteratorFromFailedMemoryStorePut: Option[PartiallyUnrolledIterator[T]] = None
      // Size of the block in bytes
      var size = 0L
      if (level.useMemory) {
        if (level.deserialized) {
          // 将给定的iterator放入对应的blockId中，最终调用MemoryStore.putIterator方法
          memoryStore.putIteratorAsValues(blockId, iterator(), classTag) match {
            case Right(s) =>
              size = s
            // 如果内存中没有足够空间放不下数据那么会尝试将数据放入磁盘中：StorageLevel.MEMORY_AND_DISK
            case Left(iter) =>
              if (level.useDisk) {
                logWarning(s"Persisting block $blockId to disk instead.")
                diskStore.put(blockId) { channel =>
                  val out = Channels.newOutputStream(channel)
                  serializerManager.dataSerializeStream(blockId, out, iter)(classTag)
                }
                size = diskStore.getSize(blockId)
              } else {
                iteratorFromFailedMemoryStorePut = Some(iter)
              }
          }
        } else { // !level.deserialized
          memoryStore.putIteratorAsBytes(blockId, iterator(), classTag, level.memoryMode) match {
            case Right(s) =>
              size = s
            case Left(partiallySerializedValues) =>
              // Not enough space to unroll this block; drop to disk if applicable
              if (level.useDisk) {
                logWarning(s"Persisting block $blockId to disk instead.")
                diskStore.put(blockId) { channel =>
                  val out = Channels.newOutputStream(channel)
                  partiallySerializedValues.finishWritingToStream(out)
                }
                size = diskStore.getSize(blockId)
              } else {
                iteratorFromFailedMemoryStorePut = Some(partiallySerializedValues.valuesIterator)
              }
          }
        }
      // 如果没使用内存那么直接将数据放入磁盘中
      } else if (level.useDisk) {
        diskStore.put(blockId) { channel =>
          val out = Channels.newOutputStream(channel)
          serializerManager.dataSerializeStream(blockId, out, iterator())(classTag)
        }
        size = diskStore.getSize(blockId)
      }
      // 如果写入成功这里会返回BlockStatus，包含写入级别、写入内存的数据大小和磁盘的数据大小（在MemoryStore和DiskStore中维护）
      val putBlockStatus = getCurrentBlockStatus(blockId, info)
      val blockWasSuccessfullyStored = putBlockStatus.storageLevel.isValid
      if (blockWasSuccessfullyStored) {
        info.size = size
        // 向BlockManagerMasterEndpoint发送更新Block状态的消息
        if (tellMaster && info.tellMaster) {
          reportBlockStatus(blockId, putBlockStatus)
        }
        addUpdatedBlockStatusToTaskMetrics(blockId, putBlockStatus)
        logDebug(s"Put block $blockId locally took ${Utils.getUsedTimeNs(startTimeNs)}")
        if (level.replication > 1) {
          val remoteStartTimeNs = System.nanoTime()
          val bytesToReplicate = doGetLocalBytes(blockId, info)
          val remoteClassTag = if (!serializerManager.canUseKryo(classTag)) {
            scala.reflect.classTag[Any]
          } else {
            classTag
          }
          try {
            replicate(blockId, bytesToReplicate, level, remoteClassTag)
          } finally {
            bytesToReplicate.dispose()
          }
          logDebug(s"Put block $blockId remotely took ${Utils.getUsedTimeNs(remoteStartTimeNs)}")
        }
      }
      assert(blockWasSuccessfullyStored == iteratorFromFailedMemoryStorePut.isEmpty)
      iteratorFromFailedMemoryStorePut
    }
  }
```

BlockStoreUpdater.save写入bytes数据
```scala
    def save(): Boolean = {
    doPut(blockId, level, classTag, tellMaster, keepReadLock) { info =>
      val startTimeNs = System.nanoTime()

      val replicationFuture = if (level.replication > 1) {
        Future {
          // 将block复制到另一个节点
          replicate(blockId, blockData(), level, classTag)
        }(futureExecutionContext)
      } else {
        null
      }
      if (level.useMemory) {
        // 将block写入内存中
        val putSucceeded = if (level.deserialized) {
          // 如果是未经序列化的数据那么将它封装为BlockData并获取输入流最终调用MemoryStore.putIterator方法
          saveDeserializedValuesToMemoryStore(blockData().toInputStream())
        } else {
          // 如果是序列化的bytes调用MemoryStore.putBytes方法
          saveSerializedValuesToMemoryStore(readToByteBuffer())
        }
        // 如果内存写入失败那么写入到磁盘
        if (!putSucceeded && level.useDisk) {
          logWarning(s"Persisting block $blockId to disk instead.")
          saveToDiskStore()
        }
      } else if (level.useDisk) {
        // 写入到磁盘，最终调用DiskStore.putBytes方法
        saveToDiskStore()
      }
      // 下面的流程就和BlockManager.doPutIterator方法一样了
      val putBlockStatus = getCurrentBlockStatus(blockId, info)
      val blockWasSuccessfullyStored = putBlockStatus.storageLevel.isValid
      if (blockWasSuccessfullyStored) {
        info.size = blockSize
        if (tellMaster && info.tellMaster) {
          reportBlockStatus(blockId, putBlockStatus)
        }
        addUpdatedBlockStatusToTaskMetrics(blockId, putBlockStatus)
      }
      logDebug(s"Put block ${blockId} locally took ${Utils.getUsedTimeNs(startTimeNs)}")
      if (level.replication > 1) {
        try {
          ThreadUtils.awaitReady(replicationFuture, Duration.Inf)
        } catch {
          case NonFatal(t) =>
            throw new SparkException("Error occurred while waiting for replication to finish", t)
        }
      }
      if (blockWasSuccessfullyStored) {
        None
      } else {
        Some(blockSize)
      }
    }.isEmpty
  }
```

### read block
read block同样分为两个方法，BlockManager.getLocalValues和BlockManager.getRemoteBlock，分别是从本地获取block和从远程获取block，当然内部也同样分为直接读取values和读取bytes两种方式

BlockManager.getLocalValues从本地获取block
```scala
  def getLocalValues(blockId: BlockId): Option[BlockResult] = {
    logDebug(s"Getting local block $blockId")
    blockInfoManager.lockForReading(blockId) match {
      case None =>
        logDebug(s"Block $blockId was not found")
        None
      case Some(info) =>
        val level = info.level
        logDebug(s"Level for block $blockId is $level")
        val taskContext = Option(TaskContext.get())
        if (level.useMemory && memoryStore.contains(blockId)) {
          // 从内存中获取block，如果未经序列化那么直接读取并返回，如果序列化了那么需要调用SerializerManager.dataDeserializeStream进行反序列化
          val iter: Iterator[Any] = if (level.deserialized) {
            memoryStore.getValues(blockId).get
          } else {
            serializerManager.dataDeserializeStream(
              blockId, memoryStore.getBytes(blockId).get.toInputStream())(info.classTag)
          }
          
          // 包装iterator并释放读锁，返回BlockResult
          val ci = CompletionIterator[Any, Iterator[Any]](iter, {
            releaseLock(blockId, taskContext)
          })
          Some(new BlockResult(ci, DataReadMethod.Memory, info.size))
        } else if (level.useDisk && diskStore.contains(blockId)) {
          // 从磁盘读取block数据
          val diskData = diskStore.getBytes(blockId)
          val iterToReturn: Iterator[Any] = {
            if (level.deserialized) {
              val diskValues = serializerManager.dataDeserializeStream(
                blockId,
                diskData.toInputStream())(info.classTag)
              // 尝试将数据缓存到内存以加快后续读取速度
              maybeCacheDiskValuesInMemory(info, blockId, level, diskValues)
            } else {
              val stream = maybeCacheDiskBytesInMemory(info, blockId, level, diskData)
                .map { _.toInputStream(dispose = false) }
                .getOrElse { diskData.toInputStream() }
              serializerManager.dataDeserializeStream(blockId, stream)(info.classTag)
            }
          }
          // 包装iterator并释放读锁，返回BlockResult
          val ci = CompletionIterator[Any, Iterator[Any]](iterToReturn, {
            releaseLockAndDispose(blockId, diskData, taskContext)
          })
          Some(new BlockResult(ci, DataReadMethod.Disk, info.size))
        } else {
          handleLocalReadFailure(blockId)
        }
    }
  }
```

BlockManager.getRemoteBlock远程获取block
```scala
  private[spark] def getRemoteBlock[T](
      blockId: BlockId,
      bufferTransformer: ManagedBuffer => T): Option[T] = {
    logDebug(s"Getting remote block $blockId")
    require(blockId != null, "BlockId is null")

    // 因为所有的block都在driver注册，所以直接去driver查找block在本地运行的其他作业的location和status
    val locationsAndStatusOption = master.getLocationsAndStatus(blockId, blockManagerId.host)
    if (locationsAndStatusOption.isEmpty) {
      logDebug(s"Block $blockId is unknown by block manager master")
      None
    } else {
      val locationsAndStatus = locationsAndStatusOption.get
      val blockSize = locationsAndStatus.status.diskSize.max(locationsAndStatus.status.memSize)

      locationsAndStatus.localDirs.flatMap { localDirs =>
        // 从在同一主机上运行的其他作业的本地目录中读取block数据，随后转换为ManagedBuffer
        val blockDataOption =
          readDiskBlockFromSameHostExecutor(blockId, localDirs, locationsAndStatus.status.diskSize)
        val res = blockDataOption.flatMap { blockData =>
          try {
            Some(bufferTransformer(blockData))
          } catch {
            case NonFatal(e) =>
              logDebug("Block from the same host executor cannot be opened: ", e)
              None
          }
        }
        logInfo(s"Read $blockId from the disk of a same host executor is " +
          (if (res.isDefined) "successful." else "failed."))
        res
      }.orElse {
        // 如果为空就去driver或者其他executor查找，它从locationsAndStatus拿到block所在的host、port以及executorId获取对应的blockId数据
        fetchRemoteManagedBuffer(blockId, blockSize, locationsAndStatus).map(bufferTransformer)
      }
    }
  }
```

### remove block
remove block没什么好说的，分别从MemoryStore和DiskStore移除对应blockId的block数据
```scala
  private def removeBlockInternal(blockId: BlockId, tellMaster: Boolean): Unit = {
    val blockStatus = if (tellMaster) {
      val blockInfo = blockInfoManager.assertBlockIsLockedForWriting(blockId)
      Some(getCurrentBlockStatus(blockId, blockInfo))
    } else None

    // 分别从memory和disk移除block
    val removedFromMemory = memoryStore.remove(blockId)
    val removedFromDisk = diskStore.remove(blockId)
    if (!removedFromMemory && !removedFromDisk) {
      logWarning(s"Block $blockId could not be removed as it was not found on disk or in memory")
    }
    // blockInfoManager移除掉blockId和BlockInfo的映射关系
    blockInfoManager.removeBlock(blockId)
    if (tellMaster) {
      reportBlockStatus(blockId, blockStatus.get.copy(storageLevel = StorageLevel.NONE))
    }
  }
```

### 其他组件
- BlockInfoManager：管理当前BlockManager上面所有的BlockInfo，它维护了一个`infos: mutable.HashMap[BlockId, BlockInfo]`存储现有的block映射，`writeLocksByTask: mutable.HashMap[TaskAttemptId, mutable.Set[BlockId]]`用来维护每个task对block加的写锁，`readLocksByTask: mutable.HashMap[TaskAttemptId, ConcurrentHashMultiset[BlockId]]`维护每个task对block加的读锁，每个block可以有多个读锁。同时也提供这些block的读写锁的释放
- BlockInfo：跟踪保存每个Block的元数据
- BlockId：标识不同block的接口，它的实现有RDDBlockId、ShuffleBlockId、ShuffleDataBlockId等等
- BlockData：抽象出block的读取方式，并提供读取底层数据的不同方法
- DiskBlockManager：创建并维护每个block到文件地址的映射，一个block映射一个文件。主要的方法就是getFile，根据filename确定文件的路径并返回，还有创建SPARK_LOCAL_DIRS文件夹清理文件夹的功能
- DiskStore：结合DiskBlockManager提供外部读取和写入block的接口，具体方式就是DiskBlockManager通过blockId计算其hash值的方式确定每个block存储的file
- MemoryManager：管理计算的内存和存储的内存，唯一的实现类是UnifiedMemoryManager，它要解决的问题是需要提供多大的内存用于Store存储
- MemoryStore：数据以MemoryEntry的方形式存在`private val entries = new LinkedHashMap[BlockId, MemoryEntry[_]]`中，MemoryStore要做的就是对外提供接口对entries进行管理。有关Spark内存的管理查看[Spark-Memory]()
