# History Kafka Producer改造

## 存在问题

* debezium源码中的History Kafka Producer发送消息并没有提供消息压缩方案，history一般存储schema的变更相关，往往会很大，每次connector重启的时候history的体积对debezium影响最大，因此在history相关配置中加入压缩参数.

## 解决方案

* `KafkaDatabaseHistory`添加History Producer压缩参数,`database.history..kafka.compression.type`

```java
public static final Field COMPRESSION_TYPE = Field.create(CONFIGURATION_FIELD_PREFIX_STRING + "kafka.compression.type")
            .withDisplayName("Kafka compression type")
            .withType(Type.STRING)
            .withDefault("gzip")
            .withWidth(Width.LONG)
            .withImportance(Importance.HIGH)
            .withDescription("Specify the final compression type for a given topic." +
                    " This configuration accepts the standard compression codecs ('gzip', 'snappy', 'lz4', 'zstd')." +
                    " It additionally accepts 'uncompressed' which is equivalent to no compression; and 'producer'" +
                    " which means retain the original compression codec set by the producer.")
            .withValidation(KafkaDatabaseHistory.forKafka(Field::isRequired));

 public void configure(Configuration config, HistoryRecordComparator comparator, DatabaseHistoryListener listener, boolean useCatalogBeforeSchema) {
        super.configure(config, comparator, listener, useCatalogBeforeSchema);
        if (!config.validateAndRecord(ALL_FIELDS, LOGGER::error)) {
            throw new ConnectException("Error configuring an instance of " + getClass().getSimpleName() + "; check the logs for details");
        }
        this.topicName = config.getString(TOPIC);
        this.pollInterval = Duration.ofMillis(config.getInteger(RECOVERY_POLL_INTERVAL_MS));
        this.maxRecoveryAttempts = config.getInteger(RECOVERY_POLL_ATTEMPTS);

        String bootstrapServers = config.getString(BOOTSTRAP_SERVERS);
        String compressionType = config.getString(COMPRESSION_TYPE);
        // Copy the relevant portions of the configuration and add useful defaults ...
        String dbHistoryName = config.getString(DatabaseHistory.NAME, UUID.randomUUID().toString());
        this.consumerConfig = config.subset(CONSUMER_PREFIX, true).edit()
                .withDefault(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers)
                .withDefault(ConsumerConfig.CLIENT_ID_CONFIG, dbHistoryName)
                .withDefault(ConsumerConfig.GROUP_ID_CONFIG, dbHistoryName)
                .withDefault(ConsumerConfig.FETCH_MIN_BYTES_CONFIG, 1) // get even smallest message
                .withDefault(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false)
                .withDefault(ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG, 10000) // readjusted since 0.10.1.0
                .withDefault(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG,
                        OffsetResetStrategy.EARLIEST.toString().toLowerCase())
                .withDefault(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class)
                .withDefault(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class)
                .build();
        this.producerConfig = config.subset(PRODUCER_PREFIX, true).edit()
                .withDefault(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers)
                .withDefault(ProducerConfig.CLIENT_ID_CONFIG, dbHistoryName)
                .withDefault(ProducerConfig.ACKS_CONFIG, 1)
                .withDefault(ProducerConfig.RETRIES_CONFIG, 1) // may result in duplicate messages, but that's
                                                               // okay
                .withDefault(ProducerConfig.COMPRESSION_TYPE_CONFIG,compressionType)
                .withDefault(ProducerConfig.BATCH_SIZE_CONFIG, 1024 * 32) // 32KB
                .withDefault(ProducerConfig.LINGER_MS_CONFIG, 0)
                .withDefault(ProducerConfig.BUFFER_MEMORY_CONFIG, 1024 * 1024) // 1MB
                .withDefault(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class)
                .withDefault(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class)
                .withDefault(ProducerConfig.MAX_BLOCK_MS_CONFIG, 10_000) // wait at most this if we can't reach Kafka
                .build();
        if (LOGGER.isInfoEnabled()) {
            LOGGER.info("KafkaDatabaseHistory Consumer config: {}", consumerConfig.withMaskedPasswords());
            LOGGER.info("KafkaDatabaseHistory Producer config: {}", producerConfig.withMaskedPasswords());
        }

        try {
            final String connectorClassname = config.getString(INTERNAL_CONNECTOR_CLASS);
            if (connectorClassname != null) {
                checkTopicSettingsExecutor = Threads.newSingleThreadExecutor((Class<? extends SourceConnector>) Class.forName(connectorClassname),
                        config.getString(INTERNAL_CONNECTOR_ID), "db-history-config-check", true);
            }
        }
        catch (ClassNotFoundException e) {
            throw new DebeziumException(e);
        }
    }
```

* `MySqlConnectorConfig`添加新添加的参数配置

```java
protected static Field.Set EXPOSED_FIELDS = ALL_FIELDS.with(KafkaDatabaseHistory.BOOTSTRAP_SERVERS,
            KafkaDatabaseHistory.TOPIC,
            KafkaDatabaseHistory.COMPRESSION_TYPE,
            KafkaDatabaseHistory.RECOVERY_POLL_ATTEMPTS,
            KafkaDatabaseHistory.RECOVERY_POLL_INTERVAL_MS,
            DatabaseHistory.SKIP_UNPARSEABLE_DDL_STATEMENTS,
            DatabaseHistory.STORE_ONLY_MONITORED_TABLES_DDL,
            DatabaseHistory.DDL_FILTER);


  protected static ConfigDef configDef() {
        ConfigDef config = new ConfigDef();
        Field.group(config, "MySQL", HOSTNAME, PORT, USER, PASSWORD, ON_CONNECT_STATEMENTS, SERVER_NAME, SERVER_ID, SERVER_ID_OFFSET,
                SSL_MODE, SSL_KEYSTORE, SSL_KEYSTORE_PASSWORD, SSL_TRUSTSTORE, SSL_TRUSTSTORE_PASSWORD, JDBC_DRIVER, CommonConnectorConfig.SKIPPED_OPERATIONS);
        Field.group(config, "History Storage", KafkaDatabaseHistory.BOOTSTRAP_SERVERS,
                KafkaDatabaseHistory.COMPRESSION_TYPE,
                KafkaDatabaseHistory.TOPIC, KafkaDatabaseHistory.RECOVERY_POLL_ATTEMPTS,
                KafkaDatabaseHistory.RECOVERY_POLL_INTERVAL_MS, DATABASE_HISTORY,
                DatabaseHistory.SKIP_UNPARSEABLE_DDL_STATEMENTS, DatabaseHistory.DDL_FILTER,
                DatabaseHistory.STORE_ONLY_MONITORED_TABLES_DDL);
        Field.group(config, "Events", INCLUDE_SCHEMA_CHANGES, INCLUDE_SQL_QUERY, TABLES_IGNORE_BUILTIN,
                DATABASE_WHITELIST, DATABASE_INCLUDE_LIST, TABLE_WHITELIST, TABLE_INCLUDE_LIST,
                COLUMN_BLACKLIST, COLUMN_EXCLUDE_LIST, COLUMN_INCLUDE_LIST, TABLE_BLACKLIST, TABLE_EXCLUDE_LIST,
                DATABASE_BLACKLIST, DATABASE_EXCLUDE_LIST, MSG_KEY_COLUMNS,
                RelationalDatabaseConnectorConfig.MASK_COLUMN_WITH_HASH,
                RelationalDatabaseConnectorConfig.MASK_COLUMN,
                RelationalDatabaseConnectorConfig.TRUNCATE_COLUMN,
                RelationalDatabaseConnectorConfig.SNAPSHOT_SELECT_STATEMENT_OVERRIDES_BY_TABLE,
                GTID_SOURCE_INCLUDES, GTID_SOURCE_EXCLUDES, GTID_SOURCE_FILTER_DML_EVENTS, GTID_NEW_CHANNEL_POSITION, BUFFER_SIZE_FOR_BINLOG_READER,
                Heartbeat.HEARTBEAT_INTERVAL, Heartbeat.HEARTBEAT_TOPICS_PREFIX, EVENT_DESERIALIZATION_FAILURE_HANDLING_MODE,
                CommonConnectorConfig.EVENT_PROCESSING_FAILURE_HANDLING_MODE, INCONSISTENT_SCHEMA_HANDLING_MODE,
                CommonConnectorConfig.TOMBSTONES_ON_DELETE, CommonConnectorConfig.SOURCE_STRUCT_MAKER_VERSION);
        Field.group(config, "Connector", CONNECTION_TIMEOUT_MS, KEEP_ALIVE, KEEP_ALIVE_INTERVAL_MS, CommonConnectorConfig.MAX_QUEUE_SIZE,
                CommonConnectorConfig.MAX_BATCH_SIZE, CommonConnectorConfig.POLL_INTERVAL_MS,
                SNAPSHOT_MODE, SNAPSHOT_LOCKING_MODE, SNAPSHOT_NEW_TABLES, TIME_PRECISION_MODE, DECIMAL_HANDLING_MODE,
                BIGINT_UNSIGNED_HANDLING_MODE, SNAPSHOT_DELAY_MS, SNAPSHOT_FETCH_SIZE, ENABLE_TIME_ADJUSTER, BINARY_HANDLING_MODE);
        return config;
    }
```

* `HistorizedRelationalDatabaseConnectorConfig`添加新添加配置

```java
protected static final ConfigDefinition CONFIG_DEFINITION = RelationalDatabaseConnectorConfig.CONFIG_DEFINITION.edit()
            .history(
                    DATABASE_HISTORY,
                    KafkaDatabaseHistory.BOOTSTRAP_SERVERS,
                    KafkaDatabaseHistory.COMPRESSION_TYPE,
                    KafkaDatabaseHistory.TOPIC,
                    KafkaDatabaseHistory.RECOVERY_POLL_ATTEMPTS,
                    KafkaDatabaseHistory.RECOVERY_POLL_INTERVAL_MS)
            .create();
```

# Kafka Connect相关

* debezium强依赖于kafka connect，因此想要高性能、稳定的采集binlog数据需要配配置合适的kafka connect参数

## kafka参数优化调整

* heartbeat.interval.ms:默认为3秒，用于控制group coordinator和group内成员的心跳机制。
* rebalance.time.ms:rebelance开始的时候允许每个worker加入group的最大时间
* connections.max.idle.ms:默认为9分钟，在此配置指定的毫秒数之后关闭空闲连接。



