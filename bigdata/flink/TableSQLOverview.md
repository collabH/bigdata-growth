# 概览

## 基本程序结构

* Table API和SQL的程序结构，与流式处理的程序结构十分类似

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .useBlinkPlanner()
                .build();
        StreamTableEnvironment tableEnvironment = StreamTableEnvironment.create(env,settings);
tableEnvironment.createTemporaryView();
Table table=tableEnvironment.from("tableName").select($("id"));
table.executeInsert()
```

## 创建TableEnvironment

* 创建表执行环境

```java
    public static TableEnvironment getEnv() {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setParallelism(1);

        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode().useBlinkPlanner().build();
        return StreamTableEnvironment.create(env, settings);
    }

    public static TableEnvironment getBatchEnv() {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .useBlinkPlanner().inBatchMode().build();
        return TableEnvironment.create(settings);
    }
```



* 基于TableEnvironment做操作
  * 注册Catalog
  * 在Catalog中注册表
  * 执行SQL查询
  * 注册UDF

## 表（Table）

* TableEnvironment可以注册目录Catalog，并可以基于Catalog注册表
* 表是由一个标识符来指定，由catalog名、数据库名和对象名组成。
* 表可以是常规的，也可以是虚拟表（视图）
* 常规表一般可以用来描述外部数据，比如文件、数据库或消息队列数据，也可以从DataStream转换而来
* 视图可以从现有的表中创建，通常是table API或SQL查询的一个结果集。