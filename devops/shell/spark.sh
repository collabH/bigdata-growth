spark-submit \
--master yarn \
--packages org.forchange.component:common:1.2.5-SNAPSHOT,org.elasticsearch:elasticsearch-spark-20_2.11:7.4.0 \
--repositories https://xxxx/repository/maven-public/ \
--deploy-mode cluster \
--driver-memory 2g \
--executor-memory 6g \
--executor-cores 3 \
--num-executors 2 \
--queue data_dev \
--class org.xxxx.warehouse.etl.driver.NinthStudioWechatCharRecordsDriver \
oss://xxxx-emr/jars/release/etl-1.0-SNAPSHOT.jar ${isIncr}