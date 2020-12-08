# Blink Planner

## runtime

### data

* binary：blink中将原生planner的row格式修改为BinaryRow，减少序列化和让数据存储更加紧凑。

#### MemorySegment

* 底层存储二进制数据的抽象类，分为HybridMemorySegment（混合型存储）和HeapMemorySegment（堆内存储）实现

#### BinaryRowData

* 分为定长数据和可变数据

