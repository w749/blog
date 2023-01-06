---
title: ELK命令语法详解
author: 汪寻
date: 2020-10-18 10:17:45
update: 2020-10-18 10:48:38
tags:
 - ES
categories:
 - Software
---

Elastic Search 、Logstash 和 Kibana 的安装使用以及常用的 ES 语法

<!-- more -->

### 架构

反正给我自己看，就不粘贴那些乱七八糟的了

### Elastic Search 安装

```shell
# 下载安装包
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.2.1-linux-x86_64.tar.gz
# 解压修改文件夹名
tar -zxvf elasticsearch-7.2.1-linux-x86_64.tar.gz -C ../servers/
mv elasticsearch-7.2.1/ elasticsearch
# 给文件夹分配用户组，所有节点都要进行
mkdir -p ./elasticsearch/{data,logs}  # 数据和日志
groupadd elk
useradd elk -g elk
chown -R elk. /data/elasticsearch/
chown -R elk. /usr/local/servers/elasticsearch/

# 修改elasticsearch.yml配置文件，先备份默认的
cp ./elasticsearch/config/elasticsearch.yml ./elasticsearch/config/elasticsearch_copy.yml
vi /usr/local/servers/elasticsearch/config/elasticsearch.yml
# 直接粘贴配置，各节点修改node.name名称
path.data: /data/elasticsearch/data  #数据
path.logs: /data/elasticsearch/logs  #日志
cluster.name: ELK  # 集群中的名称
cluster.initial_master_nodes: ["192.168.163.100", "192.168.163.110", "192.168.163.120"]  #主节点
node.name: node01  # 该节点名称，与前面配置hosts保持一致
node.master: true  # 意思是该节点是否可选举为主节点
node.data: true  # 表示这不是数据节点
network.host: 0.0.0.0  # 监听全部ip，在实际环境中应为一个安全的ip
http.port: 9200  # es服务的端口号
http.cors.enabled: true
http.cors.allow-origin: "*"
discovery.zen.minimum_master_nodes: 2 #防止集群“脑裂”，需要配置集群最少主节点数目，通常为 (主节点数目/2) + 1
discovery.seed_hosts: ["192.168.163.100", "192.168.163.110", "192.168.163.120"]

# 将此节点安装目录发送给其他节点，其他节点elasticsearch.yml文件修改node.name节点名称
scp -r elasticsearch root@node02:/usr/local/servers
```

#### 各节点启动

```shell
su - elk  # 切换到指定用户
# 启动elasticsearch
cd /usr/local/servers/elasticsearch/bin
./elasticsearch -d
# 如有错误查看log
cat /data/elasticsearch/logs/ELK.log
# 检查是否启动
netstat -lntup|grep java  # 查看java相关端口是否启动
curl 192.168.163.100:9200  # 查看节点状态
```

#### 可能遇到的问题

```shell
# 问题一：max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]
# 解决：切换到root用户修改配置sysctl.conf
vi /etc/sysctl.conf 
vm.max_map_count=655360  # 添加这条配置
sysctl -p  # 退出执行命令

# 问题二：ERROR: bootstrap checks failed
# max file descriptors [4096] for elasticsearch process likely too low, increase to at least [65536] max number of threads [1024] for user [lishang] likely too low, increase to at least [2048]
# 解决：切换到root用户，编辑limits.conf 添加类似如下内容
vi /etc/security/limits.conf 
# 添加如下
* soft nofile 65536
* hard nofile 131072
* soft nproc 2048
* hard nproc 4096

# 问题三：max number of threads [1024] for user [lish] likely too low, increase to at least [2048]
# 解决：切换到root用户，进入limits.d目录下修改配置文件。
vi /etc/security/limits.d/90-nproc.conf 
# 修改如下内容 
* soft nproc 1024
# 修改为
* soft nproc 2048
```

### Logstash安装

Logstash 用来清洗并导入数据到es，需要注意的是如果是一次性数据导入则导入完成后就关闭进程，否则它会一直监控目标文件，若内容有变动则会重新执行整个conf文件

```shell
# 下载
wget https://artifacts.elastic.co/downloads/logstash/logstash-7.2.1.tar.gz
# 解压
tar -zxvf logstash-7.2.1.tar.gz -C /usr/local/servers
# 新建数据日志文件夹，分配权限
mkdir -p /data/logstash/{logs,data}
chown -R elk. /data/logstash/
chown -R elk. /usr/local/servers/logstash/
# 备份原有配置
cp /usr/local/servers/logstash/config/logstash.yml /usr/local/servers/logstash/config/logstash_copy.yml

# 修改配置
vi /usr/local/servers/logstash/config/logstash.yml
# 直接替换原有内容
http.host: "192.168.163.100"
path.data: /data/logstash/data
path.logs: /data/logstash/logs
xpack.monitoring.enabled: true #kibana监控插件中启动监控logstash
xpack.monitoring.elasticsearch.hosts: ["192.168.163.100", "192.168.163.110", "192.168.163.120"]
# 创建配置文件
vim /usr/local/servers/logstash/config/logstash.conf 
# 输入下文
input {
  beats {
    port => 5044
  }
}
output {
  stdout {
    codec => rubydebug
  }
  elasticsearch {
    hosts => ["192.168.163.100", "192.168.163.110", "192.168.163.120"]
  }
}

# 切换到指定用户
su - elk

# 启动logstash
cd /usr/local/servers/logstash/bin
./logstash
# 或者使用nohup可以后台运行
nohup /usr/local/servers/logstash/bin/logstash &
```

logstash用法是针对每一次数据传入编写一次conf配置文件，文件中需指定输入包括路径和开始位置等参数，接下来是filter清洗数据，最后是output指定输出es的地址，以下为例

```shell
input {
  file {
    path => "/usr/local/servers/logstash/data/movies/movies.csv"
    start_position => "beginning"
  }
}
filter {
  csv {
    separator => ","
    columns => ["id","content","genre"]
  }

  mutate {
    split => { "genre" => "|" }
    remove_field => ["path", "host","@timestamp","message"]
  }

  mutate {

    split => ["content", "("]
    add_field => { "title" => "%{[content][0]}"}
    add_field => { "year" => "%{[content][1]}"}
  }

  mutate {
    convert => {
      "year" => "integer"
    }
    strip => ["title"]
    remove_field => ["path", "host","@timestamp","message","content"]
  }

}
output {
   elasticsearch {
     hosts => ["192.168.163.100:9200", "192.168.163.110:9200", "192.168.163.120:9200"]
     index => "movies"
     document_id => "%{id}"
   }
  stdout {}
}
```

### Kibana安装

```shell
# 下载
wget https://artifacts.elastic.co/downloads/kibana/kibana-7.2.1-linux-x86_64.tar.gz
# 解压
tar -zxvf kibana-7.2.1-linux-x86_64.tar.gz -C /usr/local/servers
#创建日志目录，分配权限
mkdir -p /data/kibana/logs/
chown -R elk. /data/kibana/
chown -R elk. /usr/local/servers/kibana/

# 备份原有配置
cp /usr/local/servers/kibana/config/kibana.yml /usr/local/servers/kibana/config/kibana_copy.yml

# 修改kibana配置文件
vi /usr/local/servers/kibana/config/kibana.yml
# 以下
server.port: 5601 # 配置kibana的端口，windows5601端口有时会被占用
server.host: 192.168.163.100 # 配置监听ip(设置本地ip使用nginx认证登录)
elasticsearch.hosts: ["http://192.168.163.100:9200","http://192.168.163.110:9200","http://192.168.163.120:9200"] # 配置es服务器的ip
logging.dest: /data/kibana/logs/kibana.log # 配置kibana的日志文件路径，默认messages
i18n.locale: "zh-CN" #配置中文语言

# 切换到指定用户
su - elk

# 启动kibana
cd /usr/local/servers/kibana/bin
./kibana
# 或者使用nohup可以后台运行
nohup /usr/local/servers/kibana/bin/kibana &
```

### 停止服务

```shell
# Kibana
ps -ef|grep kibana
# Elasticsearch
jps | grep Elasticsearch
# 返回进程号并kill
kill -9 进程号
```

### ES语法

#### 常用

```shell
# 功能性
GET _cat/indices  # 查看所有索引及基础信息
GET 索引名/_mapping  # 查看索引内的映射关系
GET _cluster/health  # 查看集群状态
GET _cluster/stats  # 查看集群详细状态
GET /_cluster/settings  # 查看集群配置
GET _cat/nodes?v  # 查看所有nodes

# 查询
from & size  # 从哪开始返回几条数据
_source  # 指定要返回的字段
size & sort  # 返回按列排序的多少条数据
query & match  # 匹配某个字段等于某个值
query & range  # 匹配某个字段在某个范围内
query & fuzzy  # 模糊查询
query & bool & must/must_not & match/range  # 多个条件同时满足/不满足，bool下可同时指定must和must_not
query & bool & filter & mtach/range  # 和must差不多，但不算分，效率比must快
query & bool & should & mtach/range  # should内是或的关系
_sql  # 直接传入sql语句，进行简单的查询

# 聚合
aggs & sum/max/avg/min/value_count  # 返回多个聚合结果
aggs & stats  # 返回上方所有的聚合结果，返回数据的描述性信息
aggs & terms  # 分组并统计每个类型出现的次数，类似于groupby然后count
aggs & terms & aggs & terms  # 嵌套达到groupby两个或多个字段并count的效果
aggs & terms & aggs & stats  # groupby后返回每个bucket指定字段的统计信息
aggs & top_hits  # 在top_hits指定sort参数达到返回按列排序的前几条数据，那么用size&sort不香吗
aggs & range  # 对数值进行分桶并计算每个bucket中的数量，指定ranges参数
aggs & histogram  # 按同样的区间对字段进行分组统计数量，指定interval步长即可
```

#### 功能性

```shell
# 查看所有索引及基础信息
GET _cat/indices

# 查看索引内的映射关系
GET 索引名/_mapping

# 查看集群状态
GET _cluster/health

# 查看集群详细状态
GET _cluster/stats

# 查看集群配置
GET /_cluster/settings

# 查看索引存放的shards
GET _cat/shards

# 查看master机器
GET _cat/master?v

# 查看所有nodes
GET _cat/nodes?v
```

#### 写入更新

```shell
# 写入单条数据
PUT user/_doc/1
{
  "name":"wxk",
  "age":26,
  "isRich":"true"
}


# 定义mapping，一般es会自动创建mapping，先上传测试数据，然后修改mapping再提交，最后再上传数据
# 第一步：插入一条测试数据
PUT user/_doc/1
{
  "name":"wxk",
  "age":26,
  "isRich":"true"
}
# 第二步：查看自动创建的mapping并复制下来
GET user/_mapping
# 第三步：删除测试索引
DELETE user
# 第四步：将复制的mapping拿过来修改后PUT使用，最后再次上传所有数据
PUT user
{    
  "mappings" : {
    "properties" : {
      "age" : {
        "type" : "long"
      },
      "isRich" : {
        "type" : "boolean"
        },
      "name" : {
        "type" : "text",
        "fields" : {
          "keyword" : {
            "type" : "keyword",
            "ignore_above" : 256
          }
        }
      }
    }
  }
}

# 禁止索引，在mapping中指定，指定后不能通过该字段进行搜索
PUT user
{
    "mappings" : {
      "properties" : {
        "age" : {
          "type" : "long"
        },
        "name" : {
          "type" : "text",
          "index": false
        }
      }
    }
  }

 # 查询空值，需要在mapping指定null_value，查询空值直接查询指定的null_value，注意只能在keyword类型使用
PUT user
{
    "mappings" : {
      "properties" : {
        "age" : {
          "type" : "long"
        },
        "name" : {
          "type" : "keyword",
          "null_value": "null"
        }
      }
    }
  }
```

#### 全文查询

```shell
# 查看索引内所有内容
GET kibana_sample_data_flights/_search
# from,size从指定位置开始返回指定数量的记录
GET kibana_sample_data_flights/_search
{
  "from": 5,
  "size": 5
}
# match匹配查询，直接匹配目标字符串，不做分词处理，需要注意索引内是否分词
GET kibana_sample_data_flights/_search
{
  "query": {
    "match": {
      "Origin": "Rajiv Gandhi International Airport"
    }
  }
}
# range查询范围
GET kibana_sample_data_flights/_search
{
  "query": {
    "range": {
      "FlightTimeHour": {
        "gte": 1,
        "lte": 3
      }
    }
  }
}
# _source返回自定字段
GET kibana_sample_data_flights/_search
{
  "_source": ["OriginLocation", "FlightTimeHour"], 
  "query": {
    "range": {
      "FlightTimeHour": {
        "gte": 1,
        "lte": 3  
      }
    }
  }
}
# term查询不会对输入进行分词处理，而是作为一个整体
GET kibana_sample_data_flights/_search
{
  "query": {
    "term": {
      "Origin": {
        "value": "Rajiv Gandhi International Airport"
      }
    }
  }
}
# terms则是可以输入多个对象来匹配，对象之间是或关系
GET kibana_sample_data_flights/_search
{
  "query": {
    "terms": {
      "Origin": [
        "Rajiv Gandhi International Airport",
        "Chengdu Shuangliu International Airport"
      ]
    }
  }
}
# wildcard使用通配符查询
GET kibana_sample_data_flights/_search
{
  "query": {
    "wildcard": {
      "Origin": {
         "value": "*utm_source=*"
      }
    }
  }
}
# sort对查询结果按字段进行排序，desc降序，asc升序
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "terms": {
      "Origin": [
        "Rajiv Gandhi International Airport",
        "Chengdu Shuangliu International Airport"
      ]
    }
    },
    "sort": [
      {
        "FlightTimeMin": {
          "order": "desc"
        }
      }
    ]
}
# constant_score不尽兴相关性算分，并把查询的数据进行缓存，提升效率
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "constant_score": {
      "filter": {
        "match": {
          "Origin": "Rajiv Gandhi International Airport"
        }
      },
      "boost": 1.0
    }
  }
}
# match_phrase将输入作为一个短语来匹配
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "match_phrase": {
      "Origin": "Rajiv Gandhi International Airport"
    }
  }
}
# multi_match从多个字段中去匹配查询目标
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "multi_match": {
      "query": "Rajiv Gandhi International Airport",
      "fields": ["Origin", "OriginCityName"]
    }
  }
}
# query_string针对字符串的查询，字符串之间用AND和OR连接
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "query_string": {
      "default_field": "FIELD",
      "query": "this AND that OR thus"
      "default_operator": "OR"
    }
  }
}
# simple_query_string针对在多个字段中查找目标
GET kibana_sample_data_flights/_search
{
  "_source": ["Origin", "OriginLocation", "FlightTimeMin"], 
  "query": {
    "simple_query_string": {
      "query": "International Airport",
      "fields": ["Origin", "OriginLocation"], 
      "default_operator": "OR"
    }
  }
}
# fuzzy模糊查询，按得分值降序
GET movies/_search
{
  "query": {
    "fuzzy": {
      "title": "Clara"
    }
  }
}
# fuzzy&fuzziness控制对模糊值的改变次数来匹配目标最终文档，fuzzinaess的取值范围为0、1、2
GET movies/_search
{
  "query": {
    "fuzzy": {
      "title": {
        "value": "Clara", 
        "fuzziness": 1
      }
    }
  }
}
# bool&must多条件查询
GET movies/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "simple_query_string": {
          "query": "beautiful mind",
          "fields": ["title"]
        }},
        {
          "range": {
            "year": {
              "gte": 1990,
              "lte": 1992
            }
          }
        }
      ]
    }
  }
}
# bool&must&must not多条件查询
GET movies/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "simple_query_string": {
          "query": "beautiful mind",
          "fields": ["title"]
        }},
        {
          "range": {
            "year": {
              "gte": 1990,
              "lte": 1992
            }
          }
        }
      ],
      "must_not": [
        {"simple_query_string": {
          "query": "Story",
          "fields": ["title"]
        }}
      ]
    }
  }
}
# bool&filter筛选，和must差不多，支持多条件
GET movies/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "simple_query_string": {
          "query": "beautiful",
          "fields": ["title"]
        }},
        {
          "range": {
            "year": {
              "gte": 1990,
              "lte": 1992
            }
          }
        }
      ]
    }
  }
}
# bool&should多条件之间是或者的关系
GET movies/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "simple_query_string": {
          "query": "beautiful",
          "fields": ["title"]
        }},
        {
          "range": {
            "year": {
              "gte": 1990,
              "lte": 1992
            }
          }
        }
      ]
    }
  }
}

# 使用sql语句进行查询
GET _sql
{
  "query": """
  SELECT sum(AvgTicketPrice) agg_sum FROM "kibana_sample_data_flights" where DestCountry = 'US'
  """
}
# translate将SQL语句解析为es查询json
GET _sql/translate
{
  "query": """
  SELECT sum(AvgTicketPrice) agg_sum FROM "kibana_sample_data_flights" where DestCountry = 'US'
  """
}
# format参数可返回多种形式的结果（json、yaml、txt、csv等）默认json
GET _sql?format=csv
{
  "query": """
  SELECT AvgTicketPrice,Cancelled,DestCountry FROM "kibana_sample_data_flights" where DestCountry = 'US' limit 10
  """
}
```

#### 聚合查询

```shell
# 对某个字段求和（sum）、平均（avg）、计数（value_count）、非重复计数（cardinality）
GET employee/_search
{
    "size": 0,  # 只返回聚合结果，默认为20，返回20条原数据
  "aggs": {
    "sum_agg": {  # 求和后的字段名称
      "sum": {
        "field": "sal"
      }
    }
  }
}

# 一次进行多个聚合
GET kibana_sample_data_flights/_search
{
  "size": 0, 
  "aggs": {
    "max": {
      "max": {
        "field": "AvgTicketPrice"
      }
    }, 
    "avg": {
      "avg": {
        "field": "AvgTicketPrice"
      }
    },
    "min": {
      "min": {
        "field": "AvgTicketPrice"
      }
    }
  }
}

# stats查看数据类型的数据最大最小平均值等描述性信息
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "stats": {
        "field": "sal"
      }
    }
  }
}

# terms对filed中的每个类型进行分组并统计每个类型出现的次数，类似于groupby然后count
GET kibana_sample_data_flights/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "terms": {
        "field": "DestCountry"
      }
    }
  }
}

# terms&terms嵌套达到groupby两个或多个字段并count的效果
GET kibana_sample_data_flights/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "terms": {
        "field": "DestCountry"
      },
      "aggs": {
        "NAME": {
          "terms": {
            "field": "DestWeather"
          }
        }
      }
    }
  }
}

# trems&states查看某一字段中的不同类型对应的最大最小描述性信息（groupby后max、min、avg等）
GET employee/_search
{
  "size": 0, 
  "aggs": {
    "NAME": {
      "terms": {
        "field": "job"
      },
      "aggs": {
        "NAME": {
          "stats": {
            "field": "sal"
          }
        }
      }
    }
  }
}

# top_hits&size&sort返回按列排序后的前几条数据
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "top_hits": {
        "size": 2, 
        "sort": [
          {
            "age": {
              "order": "desc"
              }
          }
        ]
      }
    }
  }
}

# range对数值进行分组并对每个区间进行计数
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "range": {
        "field": "sal",
        "ranges": [
          {
            "key": "0-10000", 
            "to": 10001
          },
          {
            "key": "10000-20000", 
            "from": 10001, 
            "to": 20001
          },
          {
            "key": "20000-30000", 
            "from": 20001, 
            "to": 30001
          }
        ]
      }
    }
  }
}

# histogram是对数值进行分区间，sep为固定值，并对每个区间进行计数
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "histogram": {
        "field": "sal",
        "interval": 10000
      }
    }
  }
}

# min_bucket筛选平均工资最低的工种
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME1": {
      "terms": {
        "field": "job"
      },
      "aggs": {
        "NAME2": {
          "avg": {
            "field": "sal"
          }
        }
      }
    },
    "NAME": {
      "min_bucket": {
        "buckets_path": "NAME1>NAME2"  # 这里为路径，按name指定
      }
    }
  }
}

# range&avg先分组再计算组内平均值
GET employee/_search
{
  "size": 0,
  "aggs": {
    "NAME": {
      "range": {
        "field": "sal",
        "ranges": [
          {
            "key": "大于30", 
            "from": 30
          }
        ]
      },
      "aggs": {
        "NAME": {
          "avg": {
            "field": "sal"
          }
        }
      }
    }
  }
}

# query&aggs先筛选再聚合
GET employee/_search
{
  "query": {
    "match": {
      "job": "java"
    }
  },
  "size": 0, 
  "aggs": {
    "NAME": {
      "stats": {
        "field": "sal"
      }
    }
  }
}

# 针对两次聚合不同数据源的聚合，aggs下分name后filter接下来再聚合
GET employee/_search
{
  "size": 0,
  "aggs": {
    "平均工资": {
      "avg": {
        "field": "sal"
      }
    },
    "筛选大于30": {
      "filter": {
        "range": {
          "age": {
            "gte": 30
          }
        }
      },
      "aggs": {
        "大于30平均工资": {
          "avg": {
            "field": "sal"
          }
        }
      }
    }
  }
}
```

#### 搜索建议/高亮

```shell
# suggest搜索建议，针对未添加到索引中的文本
GET movies/_search
{
  "suggest": {
    "NAME": {
      "text": "beauti",
      "term": {
        "field": "title"
      }
    }
  }
}

# suggest搜索建议，设置不管在不在索引中都提供搜索建议，设置suggest_mode为always
GET movies/_search
{
  "suggest": {
    "NAME": {
      "text": "beauty",
      "term": {
        "field": "title",
        "suggest_mode":"always"  # 默认为missing，设置为popular为常见的建议
      }
    }
  }
}

# completion自动补全功能的实现（首先要将mapping需要补全的字段类型设置为completion，然后在传入数据）
GET movies_completion/_search
{
  "_source": [""],  # 不显示其他字段内容，只显示匹配的title
  "suggest": {
    "NAME": {
      "prefix":"bea",  # 前缀为bea字段为title的自动补全
      "completion": {
        "field":"title"，
        "skip_duplicates":true， # 忽略重复值，返回唯一值
        "size":10  # 默认显示5条
      }
    }
  }
}

# highlight高亮查询出来匹配的文本
GET movies/_search
{
  "query": {
    "multi_match": {
      "query": "romance",
      "fields": ["title", "genre"]
    }
  }, 
  "highlight": {
    "fields": {
      "title": {},
      "genre": {
        "pre_tags": "<span>",  # 定义查询出来的标签，默认标签为em
        "post_tags": "</span>"
      }
    }
  }
}

# highlight&highlight_query实现对筛选后的结果再对其他字段再次筛选并进行高亮
GET movies/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {
          "year": 2012
        }},
        {"match": {
          "title": "romance"
        }}
      ]
    }
  },
  "highlight": {
    "fields": {
      "title": {},  # 这是直接高亮上方筛选中title中包含romance
      "genre": {
        "pre_tags": "<span>",
        "post_tags": "</span>",
        "highlight_query": {  # 对上层筛选出来的结果按children进行再次筛选并高亮
          "match": {
            "genre": "children"
          }
        }
      }
    }
  }
}
```

#### IK分词器

ik分词器安装及使用自己的词库

```shell
# 下载安装，下载解压即可，然后复制到其他主机，需要重启es
wget https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.10.1/elasticsearch-analysis-ik-7.10.1.zip
unzip elasticsearch-analysis-ik-7.10.1.zip -d /usr/local/servers/elasticsearch/plugins/ik

# 添加自己的分词库及停用词库
# 第一步：新建自己的文件夹和分词文件、停用词文件
cd /usr/local/servers/elasticsearch/plugins/ik/config/ik
mkdir custom
touch custom/myword.dic custom/mystopword.dic
# 第二步：在myword.dic文件中写入自己的词库，在mystopword.dic下写入自己的停用词
vi myword.dic
vi mystopword.dic
# 第三步：修改ik配置文件指向自己的分词库
vi config/IKAnalyzer.cfg.xml

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
        <comment>IK Analyzer 扩展配置</comment>
        <!--用户可以在这里配置自己的扩展字典 -->
        <entry key="ext_dict">custom/myword.dic</entry>  # 这里是分词库相对路径
         <!--用户可以在这里配置自己的扩展停止词字典-->
        <entry key="ext_stopwords">custom/mystopword.dic</entry>  # 这里是停用词库相对路径
        <!--用户可以在这里配置远程扩展字典 -->
        <!-- <entry key="remote_ext_dict">words_location</entry> -->
        <!--用户可以在这里配置远程扩展停止词字典-->
        <!-- <entry key="remote_ext_stopwords">words_location</entry> -->
</properties>
# 第四步：重启elasticsearch服务
```

使用IK分词器

```shell
# 一般分词（包含ik_smart和ik_max_word两种方式）
GET _analyze
{
  "analyzer": "ik_smart",  # ik_smart倾向于尽量少的分词，ik_max_word则是尽可能多的列出所有情况
  "text": "中国教育真是好啊"
}

# 实际使用IK分词器
# 首先需要定义mapping，指定字段使用IK分词器，其次就可以正常传入数据并且查询了，特殊词组则建立或新增自己的分词库
PUT news
{
  "mappings": {
    "properties": {
      "title": {
        "type": "text",
        "analyzer": "ik_max_word",  # 传入数据的时候使用最详细的分词，这样匹配度会更高
        "search_analyzer": "ik_smart"  # 查询时的匹配则使用尽量少的分词，使查询结果不至于偏差太大
      }, 
      "content": {
        "type": "text", 
        "analyzer": "ik_max_word", 
        "search_analyzer": "ik_smart"
      }
    }
  }
}
```

### Logstash语法

[grok语法](https://cloud.tencent.com/developer/article/1499881) | [官方文档](https://www.elastic.co/guide/en/logstash/current/index.html) | [grok测试](http://grokdebug.herokuapp.com/)