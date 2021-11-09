# Spark

## hudi配置

* **`hoodie.[insert|upsert|bulkinsert].shuffle.parallelism`**:hudi对输入进行分区的并行度默认为1500，大小为inputdatasize/500MB
* **Off-heap（堆外）内存：**Hudi写入parquet文件，需要使用一定的堆外内存，如果遇到此类故障，请考虑设置类似 `spark.yarn.executor.memoryOverhead`或 `spark.yarn.driver.memoryOverhead`的值。
* **Spark 内存：**通常Hudi需要能够将单个文件读入内存以执行合并或压缩操作，因此执行程序的内存应足以容纳此文件。另外，Hudi会缓存输入数据以便能够智能地放置数据，因此预留一些 `spark.memory.storageFraction`通常有助于提高性能。

