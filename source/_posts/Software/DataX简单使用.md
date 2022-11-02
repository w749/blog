---
title: DataX简单使用
author: 汪寻
date: 2021-07-23
tags:
 - ETL
categories:
 - Software


---

DataX 是由阿里巴巴开源的离线数据同步框架，它支持的数据源是采用插件式管理，目前支持大多数关系型数据库以及非关系型数据库，查看 DataX 支持的数据源可以在 [Github](https://github.com/alibaba/datax) 或者 [CODE China](https://codechina.csdn.net/mirrors/alibaba/datax/) 查看，也可以对源码进行二次开发。

<!-- more -->

### 常用命令

常用的命令只有一个 data.py，使用它有两个目的，一个是查看指定的 reader 和 writer 的模板配置，它采用的是 json 形式的配置方式，简单易理解；另外一个就是根据配置信息启动一个离线同步任务。

```shell
# 查看帮助
$DATAX_HOME/bin/datax.py --help
# 查看模板配置文件，它会返回一个json模板以及github链接，里面有每个参数的配置信息
$DATAX_HOME/bin/datax.py -r mysqlreader -w hdfswriter
# 开始一个同步任务，同步完成后会弹出统计信息，包括用时和成功失败行数等
$DATAX_HOME/bin/datax.py $DATAX_HOME/job/job.json
# 传入参数到json文件中，json文件中则采用${table}来接收参数
$DATAX_HOME/bin/datax.py -p"-Dtable=datax_test -Ddt=2020-10-31" $DATAX_HOME/job/job.json
```

每个 reader 或者 writer 包含的依赖都在`$DATAX_HOM/plugin`目录下，在依赖版本落后时可以替换依赖来完成需求。每次执行任务的 log 可以在`$DATAX_HOM/log`目录下找到，它是按日期分到不同的文件夹，再按 json 配置文件名加时间来区分不同任务的。

-p 参数特别有用，在使用定时任务的时候就可以在 shell 中给命令传入不同的参数同步指定的数据。

### 示例

这是一个 MySQL 到 HDFS 的示例， reader 可以使用 table、column 和 where 的方式，也可以采用 querySql 的方式，若采用 querySql 则 table、column 和 where 参数无效

```json
{
    "job": {
        "content": [
            {
                "reader": {
                    "name": "mysqlreader", 
                    "parameter": {
                        "column": ["id", "name", "age", "ctime"],
                        "connection": [
                            {
                                "jdbcUrl": ["jdbc:mysql://localhost:3306/test"], 
                                "table": ["${table}"]
                                # "querySql": ["select * from ${table} where data(ctime) = '${dt}'"]
                            }
                        ], 
                        "password": "root", 
                        "username": "123456", 
                        "where": "date(ctime) = ${dt}"
                    }
                }, 
                "writer": {
                    "name": "hdfswriter", 
                    "parameter": {
                        "column": [
                            {"name":"id","type":"int"},
                            {"name":"name","type":"string"},
                            {"name":"age","type":"int"},
                            {"name":"ctime","type":"string"}
                        ], 
                        "compress": "snappy", 
                        "defaultFS": "hdfs://node01:9000", 
                        "fieldDelimiter": "\t", 
                        "fileName": "datax_test", 
                        "fileType": "orc", 
                        "path": "/tmp/tmp/other/", 
                        "writeMode": "append"
                    }
                }
            }
        ], 
        "setting": {
            "speed": {
                "channel": "5"
            }
        }
    }
}
```

### 调优

局部调优

```json
"setting": {
            "speed": {
                "channel": 2,  # 此处为数据导入的并发度，建议根据服务器硬件进行调优
                "record": -1,  # 此处解除对读取行数的限制
                "byte": -1,  # 此处解除对字节的限制
                "batchSize": 2048  # 每次读取batch的大小
            }
        }
    }
}
```
