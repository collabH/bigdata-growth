# MapReduce数据操作

## 数据完整性

### 校验和

```
检测数据是否损坏的常见措施是，在数据第一次引入系统时计算校验和(checksum)并在数据通过一个不可靠的通道进行传输时再次计算校验和，这样就能发现数据是否损坏。
```

#### 常用错误检测码

* CRC-32，任何大小的数据输入均计算得到一个32位的整数校验和。Hadoop ChecksumFileSystem使用CDRC-32计算校验和，HDFS用于校验和计算的则是一个更有效的变体CRC-32C

### HDFS的数据完整性

```
HDFS会对写入的所有数据计算校验和，并在读取数据时验证校验和。它针对每个由`dfs.bytes-per-checksum`来指定字节的数据计算校验和。默认情况下位512个字节，由于CRC-32校验和是4个字节，所有存储校验和的额外开销低于百分之1
```

#### HDFS校验数据是否损坏流程

* 存储数据校验

```
datanode负责在收到数据后存储该数据及其校验和之前对数据进行验证，它在收到客户端的数据或复制其他datanode的数据时执行这个操作。正在写数据的客户端将数据及其校验和发送到由一系列datanode组成的管线，管线中最后一个datanode负责校验校验和。如果检测到错误，客户端便会收到一个IOException异常的一个子类，对于该异常应以应用程序特定的方式来处理，比如重试这个操作。
```

* 读取数据校验

```
client从datanode读取数据时，会将数据与datanode中存储的校验和进行比较，每个datanode均持有保存一个用于验证的校验和日志(persistent log of checksum verification)，所以它直到每个数据块的最后一次验证时间。客户端成功收到一个数据块后，会告诉该datanode，datanode会更新日志保存统计信息对于检测损坏的磁盘很有价值。
```

* datanode后台校验

```
datanode会在后台线程中运行一个DataBlockScanner，从而定期验证存储这个datanode上的所有数据块，用于防止因为物理存储媒介损坏数据的情况。
```

#### HDFS数据损坏修复过程

```
client在读取数据块时，如果检测到错误，首先向namenode报告已损坏的数据块及其正在尝试读操作的这个datanode，再抛出ChecksumException异常。namenode将这个数据块副本标记为已损坏，这样它不再将client处理请求直接发送到这个节点，或尝试将这个副本复制到另一个datanode。然后安排这个数据块的一个副本复制到另一个datanode，如此一来，数据块的副本因子又回到了期望水平。此后删除已损坏的数据块副本。
```

### LocalFileSystem

```
Hadoop的LocalFileSytem执行客户端的校验和验证，当你写入一个名为filename的文件时，文件系统客户端会明确在包含每个文件块校验和的同一个目录内新建一个.filename.crc隐藏文件。文件快的大小由属性file.bytes-per-checksum控制，默认512字节。文件块的大小作为元数据存储在.crc文件中，所以文件块大小的设置已经发生变化，仍然可以正确读取文件。
```

### ChecksumFileSystem

```
LocalFileSystem通过ChecksumFileSystem来完成自己的任务，通过ChecksumfileSystem向其他文件系统(无校验和系统)类加入校验和很简单，因为CheckFileSystem继承自FileSystem，使用方法如下:
FileSystem checksummedFS=new ChecksumFileSystem(FileSystem.get(path));
底层文件系统称为"源"(raw)文件系统，可以使用ChecksumFileSystem实例的getRawFileSystem()方法获取它。ChecksumFileSystem类还有其他一些与校验和相关的有用方法，比如getChecksumFile()获取任意一个文件的校验和文件路径。
```

## 压缩

### 文件压缩的好处

```
1.减少存储文件所需要的磁盘空间
2.加速数据在网络和磁盘上的传输。
```

### 基本原则

* 运算密集型的job，少用压缩，CPU密集型
* IO密集型的JOB多用压缩。

### Hadoop支持的压缩算法

* Codec是压缩-解压缩算法的一种实现。Hadoop中，一个对CompressionCodec接口的实现就代表一个codec。

### 压缩方式选择

#### Gzip

* 优点:压缩率比较高，而且压缩/解压缩速度比较快，Hadoop自带的压缩格式，处理数据和处理文本一样，Linux自带的压缩格式。
* 缺点:不支持Split

**适用场景**

* 每个文件压缩之后在`130M之内的(1块之内)`，都可以考虑Gzip。

#### Bzip2

* 优点:支持Split，高压缩率，系统自带。
* 缺点:压缩/解压缩速度慢

**适用场景**

* 适合对速度要求不高，但对文件大小要求比较高的场景，并且适合于数据存档时使用。

#### Lzo

* 优点:压缩/解压缩速度比较快，合理的压缩率，使用建立Index时支持Split，是Hadoop流行的压缩格式，可以在linux下通过lzop命令按照
* 缺点:压缩率比Gzip低，Hadoop本身不支持，需要安装;应用中需要对Lzo格式的文件做处理(支持Split需要建立索引，需要支持InputFormat格式为LZO格式)

**适用场景**

* 适合大的文本文件，压缩之后还大于200M的可以考虑，单个文件越大，优势越大。

#### Snappy

* 优点:高压缩速度和合理的压缩率
* 缺点:不支持Split，压缩率比Gzip要低；Hadoop本身不支持，需要安装。

**适用场景**

* 当MR作业的MapTask输出端适合使用，作为Map到Reduce的中间数据压缩格式，以及MR作业的输出和另一个MR作业的输入，这种关联JOB，但是压缩完的数据不能过大，因为Snappy不支持切分。

### 压缩位置选择

![压缩位置的选择](https://github.com/collabH/repository/blob/master/bigdata/spark/%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/img/%E5%8E%8B%E7%BC%A9%E4%BD%8D%E7%BD%AE%E7%9A%84%E9%80%89%E6%8B%A9.jpg)

### 压缩参数配置

* core-site.xml `io.compression.codecs` 默认值:`org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.BZip2Codec`输入阶段配置压缩
* mapred-site.xml `mapreduce.map.output.compress` 默认值`false`,mapper输出阶段是否开启压缩
* mapped-site.xml `mapreduce.map.output.compress.codec` 默认值:`org.apche.hadoop.io.compress.DefaultCodec` mapper输出阶段使用的压缩格式
* mapred-site.xml `mapreduce.output.fileoutputformat.compress` 默认为`false`，reduce输出阶段是否开启压缩
* mapred-site.xml `mapreduce.output.fileoutputformat.compress.codec` 默认值:`org.apche.hadoop.io.compress.DefaultCodec` reduce输出阶段使用的压缩格式
* mapred-site.xml `mapreduce.output.fileoutputformat.compress.type` 默认值:`RECORD` Reduce输出压缩类型，SequenceFile输出使用的压缩类型，支持Record和NONE以及Block格式

### 压缩使用

#### 压缩案例

* 使用createOutputStream(OutputStream)方法创建一个CompressionOutputStream将以压缩格式写入底层的流

```java
public class CompressFile {

    private static String compressFile = "/Users/babywang/Desktop/input/order.txt";

    public void defleateCompress() throws IllegalAccessException, InstantiationException, IOException {
        FileInputStream fis = new FileInputStream(new File(compressFile));

        DefaultCodec codec = ReflectionUtils.newInstance(DefaultCodec.class, new Configuration());
        CompressionOutputStream cos = codec.createOutputStream(new FileOutputStream(new File(compressFile + codec.getDefaultExtension())));
        IOUtils.copyBytes(fis, cos, 1024 * 1024 * 5, false);
        IOUtils.closeStream(fis);
        IOUtils.closeStream(cos);
    }

    public void gzipCompress() throws Exception {
        FileInputStream fis = new FileInputStream(new File(compressFile));

        GzipCodec codec = ReflectionUtils.newInstance(GzipCodec.class, new Configuration());
        CompressionOutputStream cos = codec.createOutputStream(new FileOutputStream(new File(compressFile + codec.getDefaultExtension())));
        IOUtils.copyBytes(fis, cos, 1024 * 1024 * 5, false);
        IOUtils.closeStream(fis);
        IOUtils.closeStream(cos);

    }

    public void bzip2Compress() throws Exception {
        FileInputStream fis = new FileInputStream(new File(compressFile));

        BZip2Codec codec = ReflectionUtils.newInstance(BZip2Codec.class, new Configuration());
        CompressionOutputStream cos = codec.createOutputStream(new FileOutputStream(new File(compressFile + codec.getDefaultExtension())));
        IOUtils.copyBytes(fis, cos, 1024 * 1024 * 5, false);
        IOUtils.closeStream(fis);
        IOUtils.closeStream(cos);
    }

    public static void main(String[] args) throws Exception {
        CompressFile compressFile = new CompressFile();
        compressFile.bzip2Compress();
        compressFile.defleateCompress();
        compressFile.gzipCompress();

    }
}
```

#### 解压缩案例

* 调用createInputStream(InputStream)方法创建一个CompressionInputFormat从底层的压缩流读取数据。

```java
public class DeCompressFile {

    private static String compressFilePath = "/Users/babywang/Desktop/input/order.txt";
    private static String compressFile = "/Users/babywang/Desktop/input/order.txt.deflate";

    public void defleateDeCompress() throws IllegalAccessException, InstantiationException, IOException {
        //拿到压缩工程
        CompressionCodecFactory factory = new CompressionCodecFactory(new Configuration());

        CompressionCodec codec = factory.getCodec(new Path(compressFile));
        if (codec == null) {
            System.out.println("该文件压缩格式不存在");
            return;
        }

        CompressionInputStream cis = codec.createInputStream(new FileInputStream(new File(compressFilePath + codec.getDefaultExtension())));

        FileOutputStream fos = new FileOutputStream(new File(compressFilePath + ".decoded"));

        IOUtils.copyBytes(cis, fos, 1024 * 1024 * 5, false);
        IOUtils.closeStream(cis);
        IOUtils.closeStream(fos);
    }


    public static void main(String[] args) throws Exception {
        DeCompressFile compressFile = new DeCompressFile();
        compressFile.defleateDeCompress();
    }
}
```

#### MapReduce启用压缩

**Map输出端采用压缩**

```java
Configuration conf = getConf();
conf.setBoolean("mapreduce.map.output.compress", true);
conf.setClass("mapreduce.map.output.compress.codec", DefaultCodec.class, CompressionCodec.class);
Job job = Job.getInstance(conf);

return job.waitForCompletion(true) ? 0 : 1;
```

**Reduce输出采用压缩**

```java
Configuration conf = getConf();
// reduce输出端压缩
conf.setBoolean("mapreduce.output.fileoutputformat.compress", true);
conf.setClass("mapreduce.output.fileoutputformat.compress.codec", DefaultCodec.class, CompressionCodec.class);
Job job = Job.getInstance(conf);
// reduce端输出压缩
FileOutputFormat.setCompressOutput(job, true);
FileOutputFormat.setOutputCompressorClass(job, DefaultCodec.class);
return 0;
```

## 序列化

```
序列化是将结构化对象转换为字节流以便在网络上传播或写到磁盘进行永久存储的过程。
反序列化是指将字节流转向结构化对象的逆过程。
```

### 序列化在分布式数据处理领域

* 进程间通信
  * RPC远程过程调用
  * 格式
* 永久存储

#### Text类型

```
Text是针对UTF-8序列的Writable类。
Text通过整型(边长编码的方式)来存储字符串编码中所需的 字节数，因此该最大值为2GB。
```

### 序列化框架

```java
Hadoop的Serialization接口是可以提供自定义实现的序列化框架
@InterfaceAudience.LimitedPrivate({"HDFS", "MapReduce"})
@InterfaceStability.Evolving
public interface Serialization<T> {
  
  /**
   * Allows clients to test whether this {@link Serialization}
   * supports the given class.
   */
  boolean accept(Class<?> c);
  
  /**
   * @return a {@link Serializer} for the given class.
   */
  Serializer<T> getSerializer(Class<T> c);

  /**
   * @return a {@link Deserializer} for the given class.
   */
  Deserializer<T> getDeserializer(Class<T> c);
}
```

#### 注册方式

```
为了注册Serialization实现，需要将io.serizalizations属性设置为一个由逗号分隔的类名列表。它的默认值包括:org.apache.hadoop.io.serializer.WritableSerialization和org.apache.hadoop.io.serializer.avro下的实现类。
```

## 基于文件的数据结构

### SequenceFile

```
SequenceFile是二进制键-值对提供一个持久数据结构，它作为日志文件的存储格式时，可以自定义选择键，以及值。
SequenceFiles也可以作为小文件的容器。HDFS和MapReduce时正对大文件优化的，所以通过SequenceFile将小文件包装起来，可以获得更高效的存储和处理。
```

#### SequenceFile写操作

```
通过createWriter()静态方法可以创建SequenceFile对象，并返回SeuqenceFile.Writer实例。得到Writer后可以通过append()在文件末尾附加键-值对。写完后通过close()方法来关闭。
```

#### SequenceFile读操作

```
创建SequenceFile.Reader实例后反复调用next()方法递归读取记录。
```

#### 命令行使用SequenceFile

```
hdfs dfs -text可以以文本形式显示顺序文件。
```

#### SequenceFile的排序和合并

```
通过SequenceFile.Sorter类中的sort()和merge()方法，但是需要手动对数据进行分区以此来达到并行排序的效果。
```

### SequeceFile的格式

```
顺序文件的前三个字节为SEQ(顺序文件代码),随后的一个字节标示顺序文件的版本号。
```

### MapFile

```
MapFile是已经排过序的SequenceFile，它有索引，可以按键查找。索引自身就是一个SequceceFile，包含了map中的以小部分键(默认情况下，是每个128个键)。由于索引能加载进内存，因此可以提供对主数据文件的快速查找。主数据文件也是一个SequenceFile文件，包含所有map条目，这些条目都是根据键进行了排序。
MapFile提供一个用于读写、与SequenceFile非常相似的结构，Mapfile.Writer进行写操作时，map条目必须顺序添加，否则会抛出IOException异常。
```
