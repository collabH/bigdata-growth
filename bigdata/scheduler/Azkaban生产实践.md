# 创建Flow

## 创建Job

### command Job

```properties
# foo.job
type=command
command=echo "Hello World"
```

## 创建Flows

* Foo Job

```properties
# foo.job
type=command
command=echo foo
```

* Bar Job依赖Foo Job

```properties
# bar.job
type=command
dependencies=foo
command=echo bar
```

## 嵌入式Flows

* flow还可以作为节点包含在其他flow中作为嵌入式flow。要创建嵌入式flow，只需创建一个.job文件，将type=flow和flow.name设置为流的名称。

```protobuf
# baz.job
type=flow
flow.name=bar
```

# Job配置

## 公共配置

| Parameter      | Description                                                  |
| :------------- | :----------------------------------------------------------- |
| retries        | job失败重试的次数                                            |
| retry.backoff  | 每次重试间隔的时间                                           |
| working.dir    | 覆盖执行的工作目录。默认情况下，这是包含正在运行的作业文件的目录。 |
| env.*property* | 设置环境变量                                                 |
| failure.emails | Comma delimited list of emails to notify during a failure. * |
| success.emails | Comma delimited list of emails to notify during a success. * |
| notify.emails  | Comma delimited list of emails to notify during either a success or failure. * |
| type           | job类型                                                      |
| dependencies   | job依赖的job                                                 |

## 运行时参数

| Parameter                       | Description                                                  |
| :------------------------------ | :----------------------------------------------------------- |
| azkaban.job.attempt             | The attempt number for the job. Starts with attempt 0 and increments with every retry. |
| azkaban.job.id                  | The job name.                                                |
| azkaban.flow.flowid             | The flow name that the job is running in.                    |
| azkaban.flow.execid             | The execution id that is assigned to the running flow.       |
| azkaban.flow.projectid          | The numerical project id.                                    |
| azkaban.flow.projectversion     | The project upload version.                                  |
| azkaban.flow.uuid               | A unique identifier assigned to a flow’s execution.          |
| azkaban.flow.start.timestamp    | The millisecs since epoch start time.                        |
| azkaban.flow.start.year         | The start year.                                              |
| azkaban.flow.start.month        | The start month of the year (1-12)                           |
| azkaban.flow.start.day          | The start day of the month.                                  |
| azkaban.flow.start.hour         | The start hour in the day.                                   |
| azkaban.flow.start.minute       | The start minute.                                            |
| azkaban.flow.start.second       | The start second in the minute.                              |
| azkaban.flow.start.milliseconds | The start millisec in the sec                                |
| azkaban.flow.start.timezone     | The start timezone that is set.                              |

## 可传递参数

* 任何包含的`.properties`文件都将被视为在流的各个作业之间共享的属性。属性按目录以分层方式解析。

```properties
partitionNum=3
masterServers=xxx
```

```properties
type=command
retries=3
retry.backoff=30000
notify.emails=xxx@xxxxx
command=sh spark-logic-deleted-run.sh ${partitionNum} ${masterServers}
```

```shell
#!/usr/bin/env bash

rm -rf  cdp-spark-etl-1.0.0-SNAPSHOT.jar
hdfs dfs -get xxx
partitionNum=$1
masterServer=$2
if(($#<2))
then
       echo "请输入partitionNum masterServer"
    exit;
fi

runParams="$partitionNum $masterServer"
if (($3)); then
    runParams=$runParams" "$3
fi
if (($4)); then
    runParams=$runParams" "$4
fi
echo "runParams:$runParams"

spark-submit \
--master yarn \
--deploy-mode cluster \
--driver-memory 1g \
--executor-memory 2g \
--executor-cores 3 \
--num-executors 3 \
--queue default \
--class xxx \
xxx.jar $runParams
```

## Job类型

### Command

* Command类型的job通过`type=command`设置，它是一个基本的命令行执行器。许多其他作业类型封装了命令作业类型，但构造了它们自己的命令行。

| Parameter    | Description                                                  | Required? |
| :----------- | :----------------------------------------------------------- | :-------- |
| command      | The command line string to execute. i.e. `ls -lh`            | yes       |
| command. *n* | 其中n是整数序列（即1,2,3 ......）。 在初始命令之后定义按顺序运行的其他命令。 | no        |

### Java进程

* Java Process Jobs是一个方便的包装器，用于挖掘基于Java的程序。 它等同于使用来自命令行的主要方法运行类。 JavaProcess作业中有以下属性：

| Parameter  | Description                                                  | Required? |
| :--------- | :----------------------------------------------------------- | :-------- |
| java.class | The class that contains the main function. i.e `azkaban.example.text.HelloWorld` | yes       |
| classpath  | Comma delimited list of jars and directories to be added to the classpath. Default is all jars in the current working directory. | no        |
| Xms        | The initial memory pool start size. The default is 64M       | no        |
| Xmx        | The initial maximum memory pool size. The default is 256M    | no        |
| main.args  | A list of comma delimited arguments to pass to the java main function | no        |
| jvm.args   | JVM args. This entire string is passed intact as a VM argument. `-Dmyprop=test -Dhello=world` | no        |

