# 概述

* 源自Google的MapReduce论文，论文发表于2014.12
* 优点:海量数据离线处理&易开发&易运行
* 无法实时流式计算

**官方文档:**[https://hadoop.apache.org/docs/r3.2.1/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html](https://hadoop.apache.org/docs/r3.2.1/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html)

>MapReduce是一个软件框架，可以轻松的编写应用程序，以可靠、容错的方式并行处理大型硬件集群上的大量数据，MapReduce作业通常将输入数据集分为独立的块，这些任务由map tasks以完成并行的方式处理。框架对map的输出进行排序，然后将其输入到reduce任务。通常，作业的输入和输出都存储在文件系统中。该框架负责安排任务，监视任务并重新执行失败的任务。
## WordCount统计流程

**实际为分治算法**

![图片](https://uploader.shimo.im/f/BnsXXhBV2fMzx9rT.png!thumbnail)

>输入文件可以拆分为多个快，通常这个块于HDFS的blocksize对应，然后一个Map处理一个块处理完的结果存在本地，再经过Shuffle网络传输把相同的key写入到一个reduce中，最终写到文件系统。
## MapReduce编程模型执行流程

* 准备map处理的输入数据
* Mapper处理
* Shuffle过程
* Reduce处理
* 结果输出
## 输入输出

```java
MapReduce框架仅对<key,value>键值对运行，该框架将作业的输入视为一组<key，value>对，并生成一组<key，value>对作为其输出。该键值对必须由框架序列化，因此需要实现Writable接口，关键类必须实现WritableComparable接口，以方便框架进行排序。
# 如下数据
   public class MyWritableComparable implements WritableComparable<MyWritableComparable> {
        // Some data
        private int counter;
        private long timestamp;
        
        public void write(DataOutput out) throws IOException {
          out.writeInt(counter);
          out.writeLong(timestamp);
        }
        
        public void readFields(DataInput in) throws IOException {
          counter = in.readInt();
          timestamp = in.readLong();
        }
        
        public int compareTo(MyWritableComparable o) {
          int thisValue = this.value;
          int thatValue = o.value;
          return (thisValue &lt; thatValue ? -1 : (thisValue==thatValue ? 0 : 1));
        }
 
        public int hashCode() {
          final int prime = 31;
          int result = 1;
          result = prime  result + counter;
          result = prime  result + (int) (timestamp ^ (timestamp &gt;&gt;&gt; 32));
          return result
        }
      }
# MapReduce流程
(input) <k1, v1> -> map -> <k2, v2> -> combine -> <k2, v2> -> reduce -> <k3, v3> (output)
针对上述wordCount，key是偏移量，value是一行的数据
```
# MapReduce多节点流程图

![图片](https://uploader.shimo.im/f/a3VY3eRGQGMCS8v7.png!thumbnail)

![图片](https://uploader.shimo.im/f/vqUj6KEBxnEYHT2B.png!thumbnail)

## 核心概念

* Split:交由MapReduce作业来处理的数据块，是MapReduce最小的计算单元
  * HDFS:blocksize是HDFS最小的存储单元，默认128MB
  * 默认情况下，Split和blocksize一一对应，也可以手工设置Split的计算单元大小和blocksize的大小
* InputFormat:输入
```java
将我们输入数据进行分片(split):InputSplit[] getSplits(JobConf job, int numSplits)
TextInputFormat:处理文本格式数据
```
* OutputFormat:输出
* Combiner
* Partitioner
# 架构图

## MapReduce1.x架构图

![图片](https://uploader.shimo.im/f/vUiyJQlgx1Y38Ij2.png!thumbnail)

* JobTracker
  * 作业的管理者
  * 将作业分解成一堆的任务:Task(MapTask和ReduceTask)
  * 将任务分派给Tasktracker运行
  * 作业的监控、容错处理
  * 在一定的时间间隔内，没有收到TaskTracker的心跳信息，判断TaskTracker挂掉，该TaskTracker运行的任务会被指定到其他TaskTracker执行
* TaskTracker
  * 任务执行者
  * 在TaskTracker执行Task(MapTask和ReduceTask)
  * 与JobTracker进行交互:执行/启动/停止作业，发送心跳信息
* MapTask
  * 自己开发的map任务交由TaskTracker处理
  * 解析每条记录的数据，交给自己的map方法处理
  * 将map的输出结果写到本地磁盘(有写作业只有map没有reduce==>HDFS)
* ReduceTask
  * 将MapTask输出的数据进行读取
  * 按照数据进行分组传给我们自己编写的reduce方法处理
  * 输出结果写到HDFS(或者其他存储引擎)
## MapReduce2.x架构图

![图片](https://uploader.shimo.im/f/o9zbPYFObf4tu7j3.png!thumbnail)

**参考YARN流程图**

[https://cdn.nlark.com/yuque/0/2020/png/361846/1581324841119-c5e810e4-3c9c-4fc7-a82a-42f55fbbbe10.png?x-oss-process=image/resize,w_1492](https://cdn.nlark.com/yuque/0/2020/png/361846/1581324841119-c5e810e4-3c9c-4fc7-a82a-42f55fbbbe10.png?x-oss-process=image/resize,w_1492)

# WordCount项目Demo

## 自定义Mapper类

```java
@Slf4j
public class MyMapper extends Mapper<LongWritable, Text, Text, LongWritable> {

    private LongWritable one = new LongWritable(1);

    @Override
    protected void map(LongWritable key, Text value, Context context) throws IOException, InterruptedException {
        //收到到的每一行数据按照指定分隔符进行拆分
        String line = value.toString();
        log.info("input line:{}", line);
        String[] words = StringUtils.split(line, " ");
        for (String word : words) {
            //通过上下文将map的结果输出
            context.write(new Text(word), one);
        }
    }
}
```
## 自定义Reducer类

```java
public class MyReducer extends Reducer<Text, LongWritable, Text, LongWritable> {
    /**
     * reduce方法
     *
     * @param key     键
     * @param values  值
     * @param context 上下文
     * @throws IOException
     * @throws InterruptedException
     */
    @Override
    protected void reduce(Text key, Iterable<LongWritable> values, Context context) throws IOException, InterruptedException {
        long sum = 0;
        for (LongWritable value : values) {
            //计算key出现的次数总和
            sum += value.get();
        }
        context.write(key, new LongWritable(sum));
    }
}
```
## 编写启动驱动

```java
public class WordCountApp {
    /**
     * Driver:封装MapReduce作业的所有信息
     * 编译打包上传至hadoop服务器，然后用yarn进行执行
     * hadoop jar jarname 主类 2 2
     *
     * @param args
     */
    public static void main(String[] args) throws IOException, ClassNotFoundException, InterruptedException {
        String jobName = "mapreduce-wordCount";
        Configuration configuration = new Configuration();

        //创建Job
        Job job = Job.getInstance(configuration, jobName);

        //设置Job处理类
        job.setJarByClass(WordCountApp.class);
        //设置作业处理的输入路径
        FileInputFormat.setInputPaths(job, new Path(args[0]));

        //设置自定义的Mapper处理类和Reducer处理类以及对应输出参数类型
        job.setMapperClass(MyMapper.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(LongWritable.class);

        job.setReducerClass(MyReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(LongWritable.class);

        //设置作业处理的输出路径
        TextOutputFormat.setOutputPath(job, new Path(args[1]));

        //提交作业
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
```
## 报错

### 相同的代码和脚本再次执行会报错

```java
在MapReduce中，输出文件是不能事先存在的
1.先手工通过hdfs shell方式手动删除
   hdfs dfs -rm /a.txt
2.代码中完成自动删除功能
Path path = new Path(args[1]);
FileSystem fileSystem = FileSystem.get(configuration);
if (fileSystem.exists(path)) {
    fileSystem.delete(path, true);
    System.out.println("output file exists");
}  
```
# MapReduce如何使用三方包或二方包

```xml
1. 将jar包上传至HDFS中，然后使用
//将jar包上传至hdfs集群中，然后代码中设置jar包依赖 
job.addArchiveToClassPath(new Path("hdfs://hadoop:8020/hello/commons-lang3-3.9.jar"));
2.将所有依赖的二方三方包打包成整个jar包
<!--mvn assembly:assembly 将所有包打包至一个jar中-->
<build>
    <plugins>
        <plugin>
            <artifactId>maven-assembly-plugin</artifactId>
            <configuration>
                <archive>
                    <manifest>
                        <mainClass>com.reasearch.hadoop.practice.UserAgentApp</mainClass>
                    </manifest>
                </archive>
                <descriptorRefs>
                    <descriptorRef>jar-with-dependencies</descriptorRef>
                </descriptorRefs>
            </configuration>
        </plugin>
    </plugins>
</build>
```
## 运行MapReduce任务命令

```
yarn jar hadoop-study-1.0-SNAPSHOT.jar com.reasearch.hadoop.mapreduce.parititioner.PartitionerApp /banner.txt /banner
```
# Combiner

* 本地reducer
* 减少Map task输出的数据量以及数据网络传输量

![图片](https://uploader.shimo.im/f/12Efx0ltTdUXwpP2.png!thumbnail)

>可以看出来，Combiner会在Map端进行本地的Reducer操作，在传递到最终的reducer处理这样传递的数据少很多

![图片](https://uploader.shimo.im/f/rl8nxYYHRvonnqDT.png!thumbnail)

## demo及适用场景

* 求和
* 次数
```
//通过job设置combiner处理类,其实逻辑上和reduce一摸一样
job.setCombinerClass(MyReducer.class);
```
# Parititioner

* Parititioner决定MapTask输出的数据交由那个ReduceTask处理
* 默认实现:分发的key的hash值对Reduce Task个数取模
# Jobhistory

* 记录已经运行完的MapReducer信息到指定的HDFS目录下
* 默认不开启
## 开启history

### 配置

```xml
1.修改mapped-site.xml配置
        <property>
                <name>mapreduce.jobhistory.address</name>
                <value>hadoop:10020</value>
        </property>
# web地址
        <property>
                <name>mapreduce.jobhistory.webapp.address</name>
                <value>hadoop:19888</value>
        </property>
# mapreduce作业运行完时放置hdfs目录
        <property>
                <name>mapreduce.jobhistory.done-dir</name>
                <value>/history/done</value>
        </property>
# 正在运行中的放置hdfs目录
         <property>
                <name>mapreduce.jobhistory.intermediate-done-dir</name>
                <value>/history/done_intermediate</value>
        </property>
2.修改yarn-site.xml文件
# 开启yarnlog的聚合功能
         <property>
              <name>yarn.log-aggregation-enable</name>
              <value>true</value>
        </property>
```
### 启动脚本

```shell
# 重启yarn
./sbin/stop-yarn.sh
./sbin/start-yarn.sh
# 启动mr-jobhistory-daemon.sh
./sbin/mr-jobhistory-daemon.sh start historyserver
```
