# 架构设计



# 参数配置

```properties
access.control.allow.methods = 
	access.control.allow.origin = 
	admin.listeners = null
	bootstrap.servers = [localhost:9092]
	client.dns.lookup = default
	config.providers = []
	connector.client.config.override.policy = None
	header.converter = class org.apache.kafka.connect.storage.SimpleHeaderConverter
	internal.key.converter = class org.apache.kafka.connect.json.JsonConverter
	internal.value.converter = class org.apache.kafka.connect.json.JsonConverter
	key.converter = class org.apache.kafka.connect.json.JsonConverter
	listeners = null
	metric.reporters = []
	metrics.num.samples = 2
	metrics.recording.level = INFO
	metrics.sample.window.ms = 30000
	offset.flush.interval.ms = 9223372036854775807
	offset.flush.timeout.ms = 5000
	offset.storage.file.filename = 
	offset.storage.partitions = null
	offset.storage.replication.factor = null
	offset.storage.topic = 
	plugin.path = null
	rest.advertised.host.name = null
	rest.advertised.listener = null
	rest.advertised.port = null
	rest.extension.classes = []
	rest.host.name = null
	rest.port = 8083
	ssl.client.auth = none
	task.shutdown.graceful.timeout.ms = 5000
	topic.tracking.allow.reset = true
	topic.tracking.enable = true
	value.converter = class org.apache.kafka.connect.json.JsonConverter
```

