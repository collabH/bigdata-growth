# SparkSQL API

## Structured API基本使用

[一、创建DataFrame和Dataset](<SparkSQL API.md#一创建DataFrame和Dataset>)\
[二、Columns列操作](<SparkSQL API.md#二Columns列操作>)\
[三、使用Structured API进行基本查询](<SparkSQL API.md#三使用Structured-API进行基本查询>)\
[四、使用Spark SQL进行基本查询](<SparkSQL API.md#四使用Spark-SQL进行基本查询>)\


### 一、创建DataFrame和Dataset

#### 1.1 创建DataFrame

Spark 中所有功能的入口点是 `SparkSession`，可以使用 `SparkSession.builder()` 创建。创建后应用程序就可以从现有 RDD，Hive 表或 Spark 数据源创建 DataFrame。示例如下：

```scala
val spark = SparkSession.builder().appName("Spark-SQL").master("local[2]").getOrCreate()
val df = spark.read.json("/usr/file/json/emp.json")
df.show()

// 建议在进行 spark SQL 编程前导入下面的隐式转换，因为 DataFrames 和 dataSets 中很多操作都依赖了隐式转换
import spark.implicits._
```

可以使用 `spark-shell` 进行测试，需要注意的是 `spark-shell` 启动后会自动创建一个名为 `spark` 的 `SparkSession`，在命令行中可以直接引用即可：

![](https://gitee.com/heibaiying/BigData-Notes/raw/master/pictures/spark-sql-shell.png)\


#### 1.2 创建Dataset

Spark 支持由内部数据集和外部数据集来创建 DataSet，其创建方式分别如下：

**1. 由外部数据集创建**

```scala
// 1.需要导入隐式转换
import spark.implicits._

// 2.创建 case class,等价于 Java Bean
case class Emp(ename: String, comm: Double, deptno: Long, empno: Long, 
               hiredate: String, job: String, mgr: Long, sal: Double)

// 3.由外部数据集创建 Datasets
val ds = spark.read.json("/usr/file/emp.json").as[Emp]
ds.show()
```

**2. 由内部数据集创建**

```scala
// 1.需要导入隐式转换
import spark.implicits._

// 2.创建 case class,等价于 Java Bean
case class Emp(ename: String, comm: Double, deptno: Long, empno: Long, 
               hiredate: String, job: String, mgr: Long, sal: Double)

// 3.由内部数据集创建 Datasets
val caseClassDS = Seq(Emp("ALLEN", 300.0, 30, 7499, "1981-02-20 00:00:00", "SALESMAN", 7698, 1600.0),
                      Emp("JONES", 300.0, 30, 7499, "1981-02-20 00:00:00", "SALESMAN", 7698, 1600.0))
                    .toDS()
caseClassDS.show()
```

#### 1.3 由RDD创建DataFrame

Spark 支持两种方式把 RDD 转换为 DataFrame，分别是使用反射推断和指定 Schema 转换：

**1. 使用反射推断**

```scala
// 1.导入隐式转换
import spark.implicits._

// 2.创建部门类
case class Dept(deptno: Long, dname: String, loc: String)

// 3.创建 RDD 并转换为 dataSet
val rddToDS = spark.sparkContext
  .textFile("/usr/file/dept.txt")
  .map(_.split("\t"))
  .map(line => Dept(line(0).trim.toLong, line(1), line(2)))
  .toDS()  // 如果调用 toDF() 则转换为 dataFrame 
```

**2. 以编程方式指定Schema**

```scala
import org.apache.spark.sql.Row
import org.apache.spark.sql.types._


// 1.定义每个列的列类型
val fields = Array(StructField("deptno", LongType, nullable = true),
                   StructField("dname", StringType, nullable = true),
                   StructField("loc", StringType, nullable = true))

// 2.创建 schema
val schema = StructType(fields)

// 3.创建 RDD
val deptRDD = spark.sparkContext.textFile("/usr/file/dept.txt")
val rowRDD = deptRDD.map(_.split("\t")).map(line => Row(line(0).toLong, line(1), line(2)))


// 4.将 RDD 转换为 dataFrame
val deptDF = spark.createDataFrame(rowRDD, schema)
deptDF.show()
```

#### 1.4 DataFrames与Datasets互相转换

Spark 提供了非常简单的转换方法用于 DataFrame 与 Dataset 间的互相转换，示例如下：

```shell
# DataFrames转Datasets
scala> df.as[Emp]
res1: org.apache.spark.sql.Dataset[Emp] = [COMM: double, DEPTNO: bigint ... 6 more fields]

# Datasets转DataFrames
scala> ds.toDF()
res2: org.apache.spark.sql.DataFrame = [COMM: double, DEPTNO: bigint ... 6 more fields]
```

### 二、Columns列操作

#### 2.1 引用列

Spark 支持多种方法来构造和引用列，最简单的是使用 `col()` 或 `column()` 函数。

```scala
col("colName")
column("colName")

// 对于 Scala 语言而言，还可以使用$"myColumn"和'myColumn 这两种语法糖进行引用。
df.select($"ename", $"job").show()
df.select('ename, 'job).show()
```

#### 2.2 新增列

```scala
// 基于已有列值新增列
df.withColumn("upSal",$"sal"+1000)
// 基于固定值新增列
df.withColumn("intCol",lit(1000))
```

#### 2.3 删除列

```scala
// 支持删除多个列
df.drop("comm","job").show()
```

#### 2.4 重命名列

```scala
df.withColumnRenamed("comm", "common").show()
```

需要说明的是新增，删除，重命名列都会产生新的 DataFrame，原来的 DataFrame 不会被改变。

\


### 三、使用Structured API进行基本查询

```scala
// 1.查询员工姓名及工作
df.select($"ename", $"job").show()

// 2.filter 查询工资大于 2000 的员工信息
df.filter($"sal" > 2000).show()

// 3.orderBy 按照部门编号降序，工资升序进行查询
df.orderBy(desc("deptno"), asc("sal")).show()

// 4.limit 查询工资最高的 3 名员工的信息
df.orderBy(desc("sal")).limit(3).show()

// 5.distinct 查询所有部门编号
df.select("deptno").distinct().show()

// 6.groupBy 分组统计部门人数
df.groupBy("deptno").count().show()
```

\


### 四、使用Spark SQL进行基本查询

#### 4.1 Spark SQL基本使用

```scala
// 1.首先需要将 DataFrame 注册为临时视图
df.createOrReplaceTempView("emp")

// 2.查询员工姓名及工作
spark.sql("SELECT ename,job FROM emp").show()

// 3.查询工资大于 2000 的员工信息
spark.sql("SELECT * FROM emp where sal > 2000").show()

// 4.orderBy 按照部门编号降序，工资升序进行查询
spark.sql("SELECT * FROM emp ORDER BY deptno DESC,sal ASC").show()

// 5.limit  查询工资最高的 3 名员工的信息
spark.sql("SELECT * FROM emp ORDER BY sal DESC LIMIT 3").show()

// 6.distinct 查询所有部门编号
spark.sql("SELECT DISTINCT(deptno) FROM emp").show()

// 7.分组统计部门人数
spark.sql("SELECT deptno,count(ename) FROM emp group by deptno").show()
```

#### 4.2 全局临时视图

上面使用 `createOrReplaceTempView` 创建的是会话临时视图，它的生命周期仅限于会话范围，会随会话的结束而结束。

你也可以使用 `createGlobalTempView` 创建全局临时视图，全局临时视图可以在所有会话之间共享，并直到整个 Spark 应用程序终止后才会消失。全局临时视图被定义在内置的 `global_temp` 数据库下，需要使用限定名称进行引用，如 `SELECT * FROM global_temp.view1`。

```scala
// 注册为全局临时视图
df.createGlobalTempView("gemp")

// 使用限定名称进行引用
spark.sql("SELECT ename,job FROM global_temp.gemp").show()
```

## 聚合函数

### 简单聚合

#### count

```scala
df.select(count($"id")).show()
```

#### countDistinct

```scala
// 计算姓名不重复的员工人数
empDF.select(countDistinct("deptno")).show()
```

#### approx\_count\_distinct

* 通常在使用大型数据集时，你可能关注的只是近似值而不是准确值，这时可以使用 approx\_count\_distinct 函数，并可以使用第二个参数指定最大允许误差。

```scala
empDF.select(approx_count_distinct("ename",0.1)).show()
```

#### first & last

* 获取 DataFrame 中指定列的第一个值或者最后一个值。

```scala
empDF.select(first("ename"),last("job")).show()
```

#### min & max

* 获取 DataFrame 中指定列的最小值或者最大值。

```scala
empDF.select(min("sal"),max("sal")).show()
```

#### sum & sumDistinct

* 求和以及求指定列所有不相同的值的和。

```scala
empDF.select(sum("sal")).show()
empDF.select(sumDistinct("sal")).show()
```

#### avg

* 内置的求平均数的函数。

```scala
empDF.select(avg("sal")).show()
```

#### 聚合数据到集合

```scala
 empDF.agg(collect_set("job"), collect_list("ename")).show()
```

## Join

Spark 中支持多种连接类型：

* **Inner Join** : 内连接；
* **Full Outer Join** : 全外连接；
* **Left Outer Join** : 左外连接；
* **Right Outer Join** : 右外连接；
* **Left Semi Join** : 左半连接；
* **Left Anti Join** : 左反连接；
* **Natural Join** : 自然连接；
* **Cross (or Cartesian) Join** : 交叉 (或笛卡尔) 连接。

其中内，外连接，笛卡尔积均与普通关系型数据库中的相同，如下图所示：

![](https://gitee.com/heibaiying/BigData-Notes/raw/master/pictures/sql-join.jpg)
