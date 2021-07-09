# 快速入门

## 下载构建源码

* 运行内置example

```shell
git clone https://github.com/apache/calcite.git
cd example/csv
./sqlline
!connect jdbc:calcite:model=src/test/resources/model.json admin admin
```



