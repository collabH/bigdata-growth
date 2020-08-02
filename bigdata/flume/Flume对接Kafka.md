# Flume对接kafka的意义

* 如果存在多个业务场景需要相同的数据，如果使用Flume分发的话无法动态的添加，并且需要配置多个channel和sink，对接kafka只需要根据不同的topic隔离，因此生产场景一般会将flume对接kafka使用。

# Flume接入Kafka

## 编写Flume Job

```properties
a1.sources=s1
a1.sinks=k1
a1.channels=c1

# sources
a1.sources.s1.type=netcat
a1.sources.s1.bind=hadoop
a1.sources.s1.port=9999

# channels
a1.channels.c1.type=memory
a1.channels.c1.capacity=1000
a1.channels.c1.transactionCapacity=100

# sink
a1.sinks.k1.type = org.apache.flume.sink.kafka.KafkaSink
a1.sinks.k1.kafka.topic = flume-kafka
a1.sinks.k1.kafka.bootstrap.servers = hadoop:9092,hadoop:9093,hadoop:9094
a1.sinks.k1.kafka.flumeBatchSize = 20
a1.sinks.k1.kafka.producer.acks = 1
a1.sinks.k1.kafka.producer.linger.ms = 1
a1.sinks.k1.kafka.producer.compression.type = snappy

# bind
a1.sources.s1.channels=c1
a1.sinks.k1.channel=c1
```

* 启动

```shell
flume-ng agent -n a1 -c $FLUME_HOME/conf -f netcat-flume-kafka.conf
```

##  配合Flume拦截器动态分发数据至不同topic

### 编写拦截器

```java
public class TypeInterceptor implements Interceptor {
    /**
     * 添加过头的事件
     */
    private List<Event> addHeaderEvents;

    @Override
    public void initialize() {
        this.addHeaderEvents = Lists.newArrayList();
    }

    /**
     * 单个事件拦截
     *
     * @param event
     * @return
     */
    @Override
    public Event intercept(Event event) {
        Map<String, String> headers = event.getHeaders();
        String body = new String(event.getBody());
        //如果event的body包含hello则向header添加一个标签
        if (body.contains("hello")) {
            headers.put("topic", "flume-kafka1");
        } else {
            headers.put("topic", "flume-kafka2");
        }
        return event;
    }

    /**
     * 批量事件拦截
     *
     * @param list
     * @return
     */
    @Override
    public List<Event> intercept(List<Event> list) {
        this.addHeaderEvents.clear();

        list.forEach(event -> addHeaderEvents.add(intercept(event)));

        return this.addHeaderEvents;
    }

    @Override
    public void close() {

    }

    public static class InterceptorBulder implements Interceptor.Builder {

        @Override
        public Interceptor build() {
            return new TypeInterceptor();
        }

        /**
         * 传递配置，可以将外部配置传递至内部
         *
         * @param context 配置上下文
         */
        @Override
        public void configure(Context context) {

        }
    }
}
```

### 编写flume job配置

```properties
a1.sources=s1
a1.sinks=k1
a1.channels=c1

# interceptor
a1.sources.s1.interceptors = i1
a1.sources.s1.interceptors.i1.type = org.research.flume.interceptor.TypeInterceptor$InterceptorBulder
a1.sources.s1.interceptors.i1.preserveExisting = false

# sources
a1.sources.s1.type=netcat
a1.sources.s1.bind=hadoop
a1.sources.s1.port=9999

# channels
a1.channels.c1.type=memory
a1.channels.c1.capacity=1000
a1.channels.c1.transactionCapacity=100

# sink
a1.sinks.k1.type = org.apache.flume.sink.kafka.KafkaSink
a1.sinks.k1.kafka.topic = flume-kafka
a1.sinks.k1.kafka.bootstrap.servers = hadoop:9092,hadoop:9093,hadoop:9094
a1.sinks.k1.kafka.flumeBatchSize = 20
a1.sinks.k1.kafka.producer.acks = 1
a1.sinks.k1.kafka.producer.linger.ms = 1
a1.sinks.k1.kafka.producer.compression.type = snappy

# bind
a1.sources.s1.channels=c1
a1.sinks.k1.channel=c1
```

