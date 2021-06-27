# 监控指标

* Flink提供Counter、Gauge、Histogram和Meter4类指标。

## Counter

* 用来统计一个指标的总量。以Flink中的指标为例，算子的接收记录总数（numRecordsIn）和发送记录总数（numRecordsOut）属于Counter类型。

## Gauge指标瞬时值

* 用来记录一个指标的瞬间值。以Flink中的指标为例，TaskManager中的JVM堆内存使用量（JVM.Heap.Used），记录某个时刻TaskManager进程的JVM堆内存使用量。

## Histogram直方图

* 指标的总量或者瞬时值都是单个值的指标，当想得到指标的最大值、最小值、中位数等统计信息时，需要用到Histogram。Flink中属于Histogram的指标很少，其中最重要的一个是算子的延迟。此项指标会记录数据处理的延迟信息，对任务监控起到很重要的作用。

## Meter平均值

* 用来记录一个指标在某个时间段内的平均值。Flink中类似的指标有Task/算子中的numRecordsInPerSecond，记录此Task或者算子每秒接收的记录数。

# 指标组

* Flink指标体系是一个树形结构