---
title: Spark源码-broadcast流程原理
author: 汪寻
date: 2022-10-24
tags:
 - Spark
categories:
 - Software
---

Spark broadcast流程原理，从创建和销毁看广播变量的管理

<!-- more -->
参考[Spark广播变量原理分析](https://blog.51cto.com/u_15067227/2573521)，广播变量主要依赖BlockManager，相关介绍放在[BlockManager](https://wangxukun.top/2022/11/02/Software/Spark%E6%BA%90%E7%A0%81-BlockManager/)

## 写入BroadCast到BlockManager
将需要广播的变量写入到Driver的BlockManager中

<div align=center><img src="broadcast-write.png"></div>

### SparkContext.broadcast
SparkContext创建一个广播变量的入口，返回一个广播变量
```scala
  def broadcast[T: ClassTag](value: T): Broadcast[T] = {
    assertNotStopped()  // 确保Spark Context未停止
    // 如果尝试广播RDD则抛出一个异常
    require(!classOf[RDD[_]].isAssignableFrom(classTag[T].runtimeClass),
      "Can not directly broadcast RDDs; instead, call collect() and broadcast the result.")
    // 创建广播变量并返回
    val bc = env.broadcastManager.newBroadcast[T](value, isLocal)
    val callSite = getCallSite
    logInfo("Created broadcast " + bc.id + " from " + callSite.shortForm)
    cleaner.foreach(_.registerBroadcastForCleanup(bc))
    bc
  }
```

### BroadcastManager.newBroadcast
新建并返回Broadcast，broadcastFactory是BroadcastFactory的唯一实现类TorrentBroadcastFactory
```scala
  def newBroadcast[T: ClassTag](value_ : T, isLocal: Boolean): Broadcast[T] = {
    val bid = nextBroadcastId.getAndIncrement()
    value_ match {
      case pb: PythonBroadcast => pb.setBroadcastId(bid)
      case _ => // do nothing
    }
    broadcastFactory.newBroadcast[T](value_, isLocal, bid)
  }
```

### TorrentBroadcastFactory.newBroadcast
最终返回一个TorrentBroadcast对象，创建对象的同时已经将需要广播的数据写入到BlockManager中了
```scala
  override def newBroadcast[T: ClassTag](value_ : T, isLocal: Boolean, id: Long): Broadcast[T] = {
    new TorrentBroadcast[T](value_, id)
  }
```

### TorrentBroadcast.writeBlocks
将整个广播变量在作为副本写入driver，将数据分为多个block写入到本地的BlockManager中
```scala
  // 此广播变量包含的块总数
  private val numBlocks: Int = writeBlocks(obj)
  // 将对象分为多个block并写入BlockManager中
  private def writeBlocks(value: T): Int = {
    import StorageLevel._
    // 将广播变量在driver存储一份副本
    val blockManager = SparkEnv.get.blockManager
    if (!blockManager.putSingle(broadcastId, value, MEMORY_AND_DISK, tellMaster = false)) {
      throw new SparkException(s"Failed to store $broadcastId in BlockManager")
    }
    try {
      // 将数据分割为指定大小的block，然后对每个block进行序列化，并进行压缩
      val blocks =
        TorrentBroadcast.blockifyObject(value, blockSize, SparkEnv.get.serializer, compressionCodec)
      if (checksumEnabled) {
        checksums = new Array[Int](blocks.length)
      }
      blocks.zipWithIndex.foreach { case (block, i) =>
        if (checksumEnabled) {
          checksums(i) = calcChecksum(block)
        }
        val pieceId = BroadcastBlockId(id, "piece" + i)
        val bytes = new ChunkedByteBuffer(block.duplicate())
        // 将每个block写入BlockManager
        if (!blockManager.putBytes(pieceId, bytes, MEMORY_AND_DISK_SER, tellMaster = true)) {
          throw new SparkException(s"Failed to store $pieceId of $broadcastId " +
            s"in local BlockManager")
        }
      }
      blocks.length
    } catch {
      case t: Throwable =>
        logError(s"Store broadcast $broadcastId fail, remove all pieces of the broadcast")
        blockManager.removeBroadcast(id, tellMaster = true)
        throw t
    }
  }
```

## 读取Broadcast的数据
获取广播变量数据就是从BlockManager获取之前存储的多个block，但是最开始只在driver端存储了数据，所以就需要远程获取，当然为了减少driver的请求压力，每个executor获取到block后就会在自己那存一份，当其他executor要获取同样的数据时会优先从同机架的executor获取

<div align=center><img src="broadcast-read.png"></div>

### Broadcast.value
Broadcast.value是获取广播变量的入口方法，它调用自身的getValue方法，此时需要去看Broadcast的实现类TorrentBroadcast中的getValue方法
```scala
  override protected def getValue() = synchronized {
    val memoized: T = if (_value == null) null.asInstanceOf[T] else _value.get
    if (memoized != null) {
      memoized
    } else {
      // 重点看这个方法
      val newlyRead = readBroadcastBlock()
      _value = new SoftReference[T](newlyRead)
      newlyRead
    }
  }
```

### TorrentBroadcast.readBroadcastBlock
读取广播变量的block，先从本地BlockManager获取，找到后缓存并返回，找不到就去其他BlockManager找，找到了就保存到本地BlockManager并返回
```scala
  private def readBroadcastBlock(): T = Utils.tryOrIOException {
    TorrentBroadcast.torrentBroadcastLock.withLock(broadcastId) {
      // 每个BlockManager都有一个缓存map来存储常用的block数据
      val broadcastCache = SparkEnv.get.broadcastManager.cachedValues

      Option(broadcastCache.get(broadcastId)).map(_.asInstanceOf[T]).getOrElse {
        setConf(SparkEnv.get.conf)
        val blockManager = SparkEnv.get.blockManager
        // 获取本地的BlockManager，然后获取指定id的广播变量数据
        blockManager.getLocalValues(broadcastId) match {
          // 如果在本地找到了那么把它加入到缓存map中并返回
          case Some(blockResult) =>
            if (blockResult.data.hasNext) {
              val x = blockResult.data.next().asInstanceOf[T]
              releaseBlockManagerLock(broadcastId)

              if (x != null) {
                broadcastCache.put(broadcastId, x)
              }

              x
            } else {
              throw new SparkException(s"Failed to get locally stored broadcast data: $broadcastId")
            }
          case None =>
            val estimatedTotalSize = Utils.bytesToString(numBlocks * blockSize)
            logInfo(s"Started reading broadcast variable $id with $numBlocks pieces " +
              s"(estimated total size $estimatedTotalSize)")
            val startTimeNs = System.nanoTime()
            // 如果没找到就会走到这个方法，去其他BlockManager去找对应的block，如果找到了则把数据读取过来
            val blocks = readBlocks()
            logInfo(s"Reading broadcast variable $id took ${Utils.getUsedTimeNs(startTimeNs)}")

            try {
              // 如有需要解压数据并将block数据转为最终的object数据
              val obj = TorrentBroadcast.unBlockifyObject[T](
                blocks.map(_.toInputStream()), SparkEnv.get.serializer, compressionCodec)
              val storageLevel = StorageLevel.MEMORY_AND_DISK
              // 将数据缓存到当前的BlockManager
              if (!blockManager.putSingle(broadcastId, obj, storageLevel, tellMaster = false)) {
                throw new SparkException(s"Failed to store $broadcastId in BlockManager")
              }

              if (obj != null) {
                broadcastCache.put(broadcastId, obj)
              }

              obj
            } finally {
              blocks.foreach(_.dispose())
            }
        }
      }
    }
  }
```

#### BlockManager.getLocalValues
从本地BlockManager获取指定block的数据
```scala
  def getLocalValues(blockId: BlockId): Option[BlockResult] = {
    logDebug(s"Getting local block $blockId")
    // 从本地的BlockInfoManager查找对应BlockId的BlockInfo，lockForReading方法会在当前block未被加写入锁时获取对应的Block Info，找不到返回None
    blockInfoManager.lockForReading(blockId) match {
      case None =>
        logDebug(s"Block $blockId was not found")
        None
      case Some(info) =>
        val level = info.level
        logDebug(s"Level for block $blockId is $level")
        val taskContext = Option(TaskContext.get())
        // 如果存储等级用到了内存那么先在内存中找，找到后封装并返回
        if (level.useMemory && memoryStore.contains(blockId)) {
          val iter: Iterator[Any] = if (level.deserialized) {
            memoryStore.getValues(blockId).get
          } else {
            serializerManager.dataDeserializeStream(
              blockId, memoryStore.getBytes(blockId).get.toInputStream())(info.classTag)
          }
          val ci = CompletionIterator[Any, Iterator[Any]](iter, {
            releaseLock(blockId, taskContext)
          })
          Some(new BlockResult(ci, DataReadMethod.Memory, info.size))
        // 内存中没有就去磁盘找
        } else if (level.useDisk && diskStore.contains(blockId)) {
          val diskData = diskStore.getBytes(blockId)
          val iterToReturn: Iterator[Any] = {
            if (level.deserialized) {
              val diskValues = serializerManager.dataDeserializeStream(
                blockId,
                diskData.toInputStream())(info.classTag)
              // 如果存储等级包含内存那么尝试将数据缓存到内存中加速后续读取
              maybeCacheDiskValuesInMemory(info, blockId, level, diskValues)
            } else {
              val stream = maybeCacheDiskBytesInMemory(info, blockId, level, diskData)
                .map { _.toInputStream(dispose = false) }
                .getOrElse { diskData.toInputStream() }
              serializerManager.dataDeserializeStream(blockId, stream)(info.classTag)
            }
          }
          val ci = CompletionIterator[Any, Iterator[Any]](iterToReturn, {
            releaseLockAndDispose(blockId, diskData, taskContext)
          })
          Some(new BlockResult(ci, DataReadMethod.Disk, info.size))
        } else {
          handleLocalReadFailure(blockId)  // 没找到则抛出异常
        }
    }
  }
```

### TorrentBroadcast.readBlocks
从driver或者executor获取block
```scala
  private def readBlocks(): Array[BlockData] = {
    val blocks = new Array[BlockData](numBlocks)
    val bm = SparkEnv.get.blockManager

    for (pid <- Random.shuffle(Seq.range(0, numBlocks))) {
      val pieceId = BroadcastBlockId(id, "piece" + pid)
      logDebug(s"Reading piece $pieceId of $broadcastId")
      // 依然先从本地找，找到则返回
      bm.getLocalBytes(pieceId) match {
        case Some(block) =>
          blocks(pid) = block
          releaseBlockManagerLock(pieceId)
        case None =>
          // 找不到则远程获取，可以是driver，也可以是executor
          bm.getRemoteBytes(pieceId) match {
            case Some(b) =>
              if (checksumEnabled) {
                val sum = calcChecksum(b.chunks(0))
                if (sum != checksums(pid)) {
                  throw new SparkException(s"corrupt remote block $pieceId of $broadcastId:" +
                    s" $sum != ${checksums(pid)}")
                }
              }
              // 如果远程找到了对应的block则将它放到本地的BlockManager
              if (!bm.putBytes(pieceId, b, StorageLevel.MEMORY_AND_DISK_SER, tellMaster = true)) {
                throw new SparkException(
                  s"Failed to store $pieceId of $broadcastId in local BlockManager")
              }
              blocks(pid) = new ByteBufferBlockData(b, true)
            case None =>
              throw new SparkException(s"Failed to get $pieceId of $broadcastId")
          }
      }
    }
    blocks
  }
```

### BlockManager.getRemoteBytes->getRemoteBlock
先从当前executor上运行的其他作业中找，找到则尝试读取并转换为最终的格式返回，没找到或者读取失败就从driver或者其他executor查找
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
        // 如果为空就去driver或者其他executor查找，它从locationsAndStatus拿到block所在的host、port以及executorId获取对应的blockId数据，后续涉及到netty就不再深入了
        fetchRemoteManagedBuffer(blockId, blockSize, locationsAndStatus).map(bufferTransformer)
      }
    }
  }
```

### BlockManagerMasterEndpoint.getLocationsAndStatus
getLocationsAndStatus方法从driver获取block在本地运行的其他作业的location和status，它向DriverEndpoint发送了一个GetLocationsAndStatus消息，返回BlockLocationsAndStatus。最终调用BlockManagerMasterEndpoint的getLocationsAndStatus方法
```scala
  private def getLocationsAndStatus(
      blockId: BlockId,
      requesterHost: String): Option[BlockLocationsAndStatus] = {
    // blockLocations是一个map，维护所有的blockId对应它的BalckManagerId集合
    val locations = Option(blockLocations.get(blockId)).map(_.toSeq).getOrElse(Seq.empty)
    // 如果存在那么获取对应的BlockStatus
    val status = locations.headOption.flatMap { bmId =>
      if (externalShuffleServiceRddFetchEnabled && bmId.port == externalShuffleServicePort) {
        Option(blockStatusByShuffleService(bmId).get(blockId))
      } else {
        blockManagerInfo.get(bmId).flatMap(_.getStatus(blockId))
      }
    }

    if (locations.nonEmpty && status.isDefined) {
      val localDirs = locations.find { loc =>
        // 找到blockId对应的locations集合并返回
        loc.host == requesterHost &&
          (loc.port == externalShuffleServicePort ||
            blockManagerInfo
              .get(loc)
              .flatMap(_.getStatus(blockId).map(_.storageLevel.useDisk))
              .getOrElse(false))
      }.flatMap { bmId => Option(executorIdToLocalDirs.getIfPresent(bmId.executorId)) }
      Some(BlockLocationsAndStatus(locations, status.get, localDirs))
    } else {
      None
    }
  }
```

## 删除Broadcast数据
unpersist流程：BlockManagerMaster发送RemoveBroadcast消息->DriverEndpoint发送RemoveBroadcast消息->BlockManagerMasterEndpoint发送RemoveBroadcast消息->BlockManagerStorageEndpoint->每个executor对应的BlockManager.removeBroadcast

destroy流程和unpersist类似，只是removeFromDriver参数为true，表示在最后一步removeBroadcast时会将driver的相关block也删掉，此时广播变量就无法使用了，而unpersist仅仅是删除executor上的block数据，仍可以继续使用。
