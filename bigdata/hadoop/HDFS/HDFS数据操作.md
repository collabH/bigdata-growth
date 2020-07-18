# 数据完整性

## 校验和

```
检测数据是否损坏的常见措施是，在数据第一次引入系统时计算校验和(checksum)并在数据通过一个不可靠的通道进行传输时再次计算校验和，这样就能发现数据是否损坏。
```
### 常用错误检测码

* CRC-32，任何大小的数据输入均计算得到一个32位的整数校验和。Hadoop ChecksumFileSystem使用CDRC-32计算校验和，HDFS用于校验和计算的则是一个更有效的变体CRC-32C
## HDFS的数据完整性

```
HDFS会对写入的所有数据计算校验和，并在读取数据时验证校验和。它针对每个由`dfs.bytes-per-checksum`来指定字节的数据计算校验和。默认情况下位512个字节，由于CRC-32校验和是4个字节，所有存储校验和的额外开销低于百分之1
```
### HDFS校验数据是否损坏流程

* 存储数据校验
```
datanode负责在收到数据后存储该数据 及其校验和之前对数据进行验证，它在收到客户端的数据或复制其他datanode的数据时执行这个操作。正在写数据的客户端将数据及其校验和发送到由一系列datanode组成的管线，管线中最后一个datanode负责校验校验和。如果检测到错误，客户端便会收到一个IOException异常的一个子类，对于该异常应以应用程序特定的方式来处理，比如充实这个操作。
```
* 读取数据校验
```
client从datanode读取数据时，会将数据与datanode中存储的校验和进行比较，每个datanode均持有保存一个用于验证的校验和日志(persistent log of checksum verification)，所以它直到每个数据块的最后一次验证时间。客户端成功收到一个数据块后，会告诉该datanode，datanode会更新日志保存统计信息对于检测损坏的磁盘很有价值。
```
* datanode后台校验
```
datanode会在后台线程中运行一个DataBlockScanner，从而定期验证存储这个datanode上的所有数据块，用于防止因为物理存储媒介损坏数据的情况。
```
### HDFS数据损坏修复过程

```
client在读取数据块时，如果检测到错误，首先向namenode报告已损坏的数据块及其正在尝试读操作的这个datanode，再抛出ChecksumException异常。namenode将这个数据块副本标记为已损坏，这样它不再将client处理请求直接发送到这个节点，或尝试将这个副本复制到另一个datanode。然后安排这个数据块的一个副本复制到另一个datanode，如此一来，数据块的副本因子又回到了期望水平。此后删除已损坏的数据块副本。
```
![图片](https://uploader.shimo.im/f/J68yZzp7bJIopuOF.png!thumbnail)

## LocalFileSystem

```
Hadoop的LocalFileSytem执行客户端的校验和验证，当你写入一个名为filename的文件时，文件系统客户端会明确在包含每个文件块校验和的同一个目录内新建一个.filename.crc隐藏文件。文件快的大小由属性file.bytes-per-checksum控制，默认512字节。文件快的大小作为元数据存储在.crc文件中，所以文件快大小的设置已经发生变化，仍然可以正确读取文件。
```
## ChecksumFileSystem

```
LocalFileSystem通过ChecksumFileSystem来完成自己的任务，通过ChecksumfileSystem向其他文件系统(无校验和系统)类加入校验和很简单，因为CheckFileSystem继承自FileSystem，使用方法如下:
FileSystem checksummedFS=new ChecksumFileSystem(FileSystem.get(path));
底层文件系统称为"源"(raw)文件系统，可以使用ChecksumFileSystem实例的getRawFileSystem()方法获取它。ChecksumFileSystem类还有其他一些与校验和相关的有用方法，比如getChecksumFile()获取任意一个文件的校验和文件路径。
```
![图片](https://uploader.shimo.im/f/RpKTCDxmb8s5eqzZ.png!thumbnail)

# 压缩

## 文件压缩的好处

```
1.减少存储文件所需要的磁盘空间
2.加速数据在网络和磁盘上的传输。
```
## Hadoop支持的压缩算法

![图片](https://uploader.shimo.im/f/YEnZZzbIx5MKTsYC.png!thumbnail)

## codec

```
Codec是压缩-解压缩算法的一种实现。Hadoop中，一个对CompressionCodec接口的实现就代表一个codec。
```
![图片](https://uploader.shimo.im/f/pUTHtygN9p0vjPy2.png!thumbnail)

## 应该使用那种压缩格式？

![图片](https://uploader.shimo.im/f/RkonoKV497sq3Bmp.png!thumbnail)

![图片](https://uploader.shimo.im/f/6oOZR5VnLzUw2jzd.png!thumbnail)

# 序列化

```
序列化是将结构化对象转换为字节流以便在网络上传播或写到磁盘进行永久存储的过程。
反序列化是指将字节流转向结构化对象的逆过程。
```
## 序列化在分布式数据处理领域

* 进程间通信
  * RPC远程过程调用
  * 格式

![图片](https://uploader.shimo.im/f/GaL0wQOugzATVY9u.png!thumbnail)

* 永久存储

![图片](https://uploader.shimo.im/f/XN7AOaQIos4zb5fM.png!thumbnail)

## Writable接口

![图片](https://uploader.shimo.im/f/fYE7g4Uv2jESytO9.png!thumbnail)

### Java基本类型的Writable类

![图片](https://uploader.shimo.im/f/dLwuWNCy1DIpODgU.png!thumbnail)

### Text类型

```
Text是针对UTF-8序列的Writable类。
Text通过整型(边长编码的方式)来存储字符串编码中所需的 字节数，因此该最大值为2GB。
```
## 序列化框架

```
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
### 注册方式

```
为了注册Serialization实现，需要将io.serizalizations属性设置为一个由逗号分隔的类名列表。它的默认值包括:org.apache.hadoop.io.serializer.WritableSerialization和org.apache.hadoop.io.serializer.avro下的实现类。
```
# 基于文件的数据结构

## SequenceFile

```
SequenceFile是二进制键-值对提供一个持久数据结构，它作为日志文件的存储格式时，可以自定义选择键，以及值。
SequenceFiles也可以作为小文件的容器。HDFS和MapReduce时正对大文件优化的，所以通过SequenceFile将小文件包装起来，可以获得更高效的存储和处理。
```
### SequenceFile写操作

```
通过createWriter()静态方法可以创建SequenceFile对象，并返回SeuqenceFile.Writer实例。得到Writer后可以通过append()在文件末尾附加键-值对。写完后通过close()方法来关闭。
```
### SequenceFile读操作

```
创建SequenceFile.Reader实例后反复调用next()方法递归读取记录。
```
### 命令行使用SequenceFile

```
hdfs dfs -text可以以文本形式显示顺序文件。
```
### SequenceFile的排序和合并

```
通过SequenceFile.Sorter类中的sort()和merge()方法，但是需要手动对数据进行分区以此来达到并行排序的效果。
```
## SequeceFile的格式

```
顺序文件的前三个字节为SEQ(顺序文件代码),随后的一个字节标示顺序文件的版本号。
```
![图片](https://uploader.shimo.im/f/yFAnxBKm1QY5SiM2.png!thumbnail)

## MapFile

```
MapFile是已经排过序的SequenceFile，它有索引，可以按键查找。索引自身就是一个SequceceFile，包含了map中的以小部分键(默认情况下，是每个128个键)。由于索引能加载进内存，因此可以提供对主数据文件的快速查找。主数据文件也是一个SequenceFile文件，包含所有map条目，这些条目都是根据键进行了排序。
MapFile提供一个用于读写、与SequenceFile非常相似的结构，Mapfile.Writer进行写操作时，map条目必须顺序添加，否则会抛出IOException异常。
```
### MapFile的变种

![图片](https://uploader.shimo.im/f/EFi2mNWGog8h9WLa.png!thumbnail)

