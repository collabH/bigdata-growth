# TableConnector模块

* 自定义Connector相关模块，包含Catalog，Source/Sink，时态表(LookupTableSource)等

![Translation of table connectors](https://ci.apache.org/projects/flink/flink-docs-release-1.12/fig/table_connectors.svg)

## Metadata

* 表API和SQL都是声明性API。 这包括表的声明。 因此，执行CREATE TABLE语句会导致目标目录中的元数据更新。
* 对于大多数catalog实现，不会为此类操作修改外部系统中的物理数据。 特定于连接器的依赖项还不必存在于类路径中。 在WITH子句中声明的选项既未经验证也未经其他解释。
* 动态表的元数据（通过DDL创建或由目录提供）表示为CatalogTable的实例。 必要时，表名称将在内部解析为CatalogTable。

## Planning

* 当涉及到需要执行和优化的表程序时，一个CatalogTable需要被解析至DynamicTableSource和DynamicTableSink中。
* DynamicTableSourceFactory和DynamicTableSinkFactory提供了特定于连接器的逻辑，用于将CatalogTable的元数据转换为DynamicTableSource和DynamicTableSink的实例。 在大多数情况下，工厂的目的是验证选项（例如示例中的'port'='5022'），配置编码/解码格式（如果需要）并创建表连接器的参数化实例。
* 默认情况下，DynamicTableSourceFactory和DynamicTableSinkFactory的实例是使用Java的服务提供者接口(SPI)发现的。连接器选项(例如示例中的'connector' = 'custom')必须对应于有效的工厂标识符。

## Runtime

* 一旦逻辑执行计划完成，这个执行器将会获取来自运行器实现的表连接器。运行时逻辑在Flink的核心连接器接口中实现，如InputFormat或SourceFunction。
* 这些接口通过另一个抽象级别分组为ScanRuntimeProvider，LookupRuntimeProvider和SinkRuntimeProvider的子类。
* 例如，OutputFormatProvider（提供org.apache.flink.api.common.io.OutputFormat）和SinkFunctionProvider（提供org.apache.flink.streaming.api.functions.sink.SinkFunction）都是planner可以使用的SinkRuntimeProvider的具体实例处理。

# 使用方式

## Dynamic Table Factories

* 实现`org.apache.flink.table.factories.DynamicTableSourceFactory`和`org.apache.flink.table.factories.DynamicTableSinkFactory`
* 配置Java SPI`META-INF/services/org.apache.flink.table.factories.Factory`

## Dynamic Table Source

* 通过定义一个动态表可以在任何时间变化，当读取一个动态表的时候，内容可以视为：
  * 一个更新日志(有限的或无限的)，所有的更改都会被连续地消费，直到更新日志消费完毕为止。这由ScanTableSource接口表示。
  * 一个不断变化的或非常大的外部表，它的内容通常不会全部读取，但在必要时查询单个值。这由LookupTableSource接口表示。时态表

### Scan Table Source

* 扫描的行不必只包含插入，也可以包含更新和删除。因此，表源可以用来读取(有限的或无限的)变更日志。返回的changelog模式指示规划器在运行时可以预期的更改集。
* 对于常规的批处理场景，源可以发出一个只包含插入行的有界流。
* 对于常规流场景，源可以发出一个无限制的只包含插入行的流。
* 对于更改数据捕获（CDC）方案，源可以发出带有插入，更新和删除行的有界或无界流。
* 一个table source可以实现的能力[source abilities table](https://ci.apache.org/projects/flink/flink-docs-release-1.12/zh/dev/table/sourceSinks.html#source-abilities). 记录必须输出格式为`org.apache.flink.table.data.RowData`

### Lookup Table Source

* 与ScanTableSource相比，源不需要读取整个表，并且可以在必要时从外部表(可能是不断变化的)中惰性地获取单个值。
* 与ScanTableSource相比，LookupTableSource目前只支持发出仅用于插入的更改。

## Dynamic Table Sink

* 根据定义，动态表可以随时间变化。编写动态表时，内容始终可以被视为变更日志（有限或无限），所有变更都将连续写出，直到耗尽变更日志为止。 返回的变更日志模式指示接收器在运行时接受的变更集。
* 对于常规的批处理方案，接收器只能接受仅插入的行并写出有界流。
* 对于常规流方案，接收器只能接受仅插入的行，并且可以写出无限制的流。
* 对于更改数据捕获（CDC）方案，接收器可以写出具有插入，更新和删除行的有界或无界流。
* 表接收器可以实现其他功能接口，例如SupportsOverwrite，这些接口可能会在计划期间使实例变异。 所有功能都可以在`org.apache.flink.table.connector.sink.abilities`包中找到，并在接收器功能表中列出。 [sink abilities table](https://ci.apache.org/projects/flink/flink-docs-release-1.12/zh/dev/table/sourceSinks.html#sink-abilities).
* DynamicTableSink的运行时实现必须使用内部数据结构。 因此，必须将记录作为`org.apache.flink.table.data.RowData`接受。 该框架提供了运行时转换器，因此接收器仍可以在通用数据结构上工作并在开始时执行转换。

## Encoding / Decoding Formats

* 某些表连接器接受编码和解码键和/或值的不同格式。例如`cancl-json`/`json`等格式

* 格式的工作方式类似于模式`DynamicTableSourceFactory-> DynamicTableSource-> ScanRuntimeProvider`，其中工厂负责翻译选项，而source负责创建运行时逻辑。

* 例如，Kafka表源需要DeserializationSchema作为解码格式的运行时接口。 因此，Kafka表源工厂使用`value.format`选项的值来发现DeserializationFormatFactory。

* 当前支持的格式工厂:

  ```java
  org.apache.flink.table.factories.DeserializationFormatFactory
  org.apache.flink.table.factories.SerializationFormatFactory
  ```

  

* 格式工厂将选项转换为EncodingFormat或DecodingFormat。 这些接口是另一种针对给定数据类型生成专用格式运行时逻辑的工厂。

* 例如，对于Kafka表源工厂，DeserializationFormatFactory将返回一个EncodingFormat <DeserializationSchema>，可以将其传递到Kafka表源中。

# 实现案例

## 定义DynamicTableSourceFactory

* 实现接口`DynamicTableSourceFactory`
* 添加至在`META-INF/services/org.apache.flink.table.factories.Factory`

```java
package dev.learn.flink.tablesql.httpConnector.source;

import com.google.common.collect.Sets;
import dev.learn.flink.tablesql.httpConnector.options.ConnectionOptions;
import dev.learn.flink.tablesql.httpConnector.options.HttpClientOptions;
import dev.learn.flink.tablesql.httpConnector.options.RequestParamOptions;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.configuration.ConfigOption;
import org.apache.flink.configuration.ConfigOptions;
import org.apache.flink.configuration.ReadableConfig;
import org.apache.flink.table.connector.format.DecodingFormat;
import org.apache.flink.table.connector.source.DynamicTableSource;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.factories.DeserializationFormatFactory;
import org.apache.flink.table.factories.DynamicTableSourceFactory;
import org.apache.flink.table.factories.FactoryUtil;
import org.apache.flink.table.types.DataType;

import java.util.Set;

/**
 * @fileName: UDFTableSourceFactory.java
 * @description: UDFTableSourceFactory.java类说明
 * @author: by echo huang
 * @date: 2021/1/16 11:34 下午
 */
public class HttpTableSourceFactory implements DynamicTableSourceFactory {

    /**
     * Request Config
     */
    private static final ConfigOption<String> HTTP_CLIENT_HEADERS =
            ConfigOptions.key("http.client.headers")
                    .stringType()
                    .noDefaultValue();
    private static final ConfigOption<String> HTTP_CLIENT_REQUEST_URL =
            ConfigOptions.key("http.client.request-url")
                    .stringType()
                    .noDefaultValue();
    private static final ConfigOption<String> HTTP_CLIENT_REQUEST_TYPE =
            ConfigOptions.key("http.client.request-type")
                    .stringType()
                    .defaultValue(RequestParamOptions.RequestType.GET.name());
    /**
     * Http Client Params
     */
    private static final ConfigOption<Long> HTTP_CLIENT_HEART_INTERVAL = ConfigOptions
            .key("http.client.heart-interval")
            .longType()
            .defaultValue(30 * 1000L);
    private static final ConfigOption<Long> HTTP_CLIENT_READ_TIMEOUT = ConfigOptions
            .key("http.client.read-timeout")
            .longType()
            .defaultValue(60 * 1000L);

    private static final ConfigOption<Long> HTTP_CLIENT_WRITE_TIMEOUT = ConfigOptions
            .key("http.client.write-timeout")
            .longType()
            .defaultValue(60 * 1000L);

    /**
     * Http Client Connection Pool Params
     */
    private static final ConfigOption<Integer> CONNECTION_POOL_MAX_IDLES = ConfigOptions
            .key("http.client.connection-pool.max.idles")
            .intType()
            .defaultValue(5);

    private static final ConfigOption<Long> CONNECTION_POOL_KEEP_ALIVE = ConfigOptions
            .key("http.client.connection-pool.keep-alive")
            .longType()
            .defaultValue(5 * 60 * 1000L);

    private static final ConfigOption<Long> CONNECTION_TIMEOUT = ConfigOptions
            .key("http.client.connection.timeout")
            .longType()
            .defaultValue(60 * 1000L);

    @Override
    public DynamicTableSource createDynamicTableSource(Context context) {
        FactoryUtil.TableFactoryHelper helper = FactoryUtil.createTableFactoryHelper(this, context);
        // 发现实现的DeserializationFormatFactory
        DecodingFormat<DeserializationSchema<RowData>> decodingFormat =
                helper.discoverDecodingFormat(DeserializationFormatFactory.class, FactoryUtil.FORMAT);
        // 校验table参数
        helper.validate();
        // 获取table option
        ReadableConfig options = helper.getOptions();
        String requestUrl = options.get(HTTP_CLIENT_REQUEST_URL);
        String headers = options.get(HTTP_CLIENT_HEADERS);
        String requestType = options.get(HTTP_CLIENT_REQUEST_TYPE);
        Long heartInterval = options.get(HTTP_CLIENT_HEART_INTERVAL);
        Long writeTimeout = options.get(HTTP_CLIENT_WRITE_TIMEOUT);
        Long readTimeout = options.get(HTTP_CLIENT_READ_TIMEOUT);
        Long keepAlive = options.get(CONNECTION_POOL_KEEP_ALIVE);
        Integer maxIdes = options.get(CONNECTION_POOL_MAX_IDLES);
        Long connectionTimeout = options.get(CONNECTION_TIMEOUT);
        RequestParamOptions requestParamOptions = RequestParamOptions.builder().requestUrl(requestUrl)
                .headers(headers)
                .requestType(requestType)
                .build();
        ConnectionOptions connectionOptions = ConnectionOptions.builder().connectionTimeout(connectionTimeout)
                .keepAliveDuration(keepAlive)
                .maxIdleConnections(maxIdes).build();
        HttpClientOptions httpClientOptions = HttpClientOptions.builder()
                .heartInterval(heartInterval)
                .readTimeout(readTimeout)
                .writeTimeout(writeTimeout).build();

        final DataType producedDataType = context.getCatalogTable().getSchema().toPhysicalRowDataType();
        return new HttpTableSource(decodingFormat, requestParamOptions, connectionOptions, httpClientOptions,
                producedDataType);
    }

    @Override
    public String factoryIdentifier() {
        return "http";
    }

    @Override
    public Set<ConfigOption<?>> requiredOptions() {
        return Sets.newHashSet(FactoryUtil.FORMAT,
                HTTP_CLIENT_REQUEST_URL);
    }

    @Override
    public Set<ConfigOption<?>> optionalOptions() {
        return Sets.newHashSet(HTTP_CLIENT_HEADERS, HTTP_CLIENT_WRITE_TIMEOUT, HTTP_CLIENT_READ_TIMEOUT, HTTP_CLIENT_HEART_INTERVAL,
                CONNECTION_POOL_KEEP_ALIVE, CONNECTION_POOL_MAX_IDLES, CONNECTION_TIMEOUT, HTTP_CLIENT_REQUEST_TYPE);
    }
}

```

## 定义DeserializationFormatFactory

* 实现接口`DeserializationFormatFactory`
* 添加至在`META-INF/services/org.apache.flink.table.factories.Factory`

```java
package dev.learn.flink.tablesql.httpConnector.deserializer;

import com.google.common.collect.Sets;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.configuration.ConfigOption;
import org.apache.flink.configuration.ConfigOptions;
import org.apache.flink.configuration.ReadableConfig;
import org.apache.flink.table.connector.format.DecodingFormat;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.factories.DeserializationFormatFactory;
import org.apache.flink.table.factories.DynamicTableFactory;
import org.apache.flink.table.factories.FactoryUtil;

import java.util.Set;

/**
 * @fileName: HttpRequestFormatFactory.java
 * @description: HttpRequestFormatFactory.java类说明
 * @author: by echo huang
 * @date: 2021/1/17 7:02 下午
 */
public class HttpRequestFormatFactory implements DeserializationFormatFactory {
    private static final ConfigOption<String> HTTP_CLIENT_FORMAT_CLASSNAME =
            ConfigOptions.key("http.client.format.classname")
                    .stringType()
                    .noDefaultValue();

    private static final ConfigOption<Boolean> HTTP_CLIENT_IS_ARRAY =
            ConfigOptions.key("http.client.is.array")
                    .booleanType()
                    .defaultValue(true);

    @Override
    public DecodingFormat<DeserializationSchema<RowData>> createDecodingFormat(DynamicTableFactory.Context context, ReadableConfig readableConfig) {
        FactoryUtil.validateFactoryOptions(this, readableConfig);
        String formatClassName = readableConfig.get(HTTP_CLIENT_FORMAT_CLASSNAME);
        Boolean isArray = readableConfig.get(HTTP_CLIENT_IS_ARRAY);
        return new HttpJsonBeanFormat(formatClassName, isArray);
    }

    @Override
    public String factoryIdentifier() {
        return "http-json-bean";
    }

    @Override
    public Set<ConfigOption<?>> requiredOptions() {
        return Sets.newHashSet(HTTP_CLIENT_FORMAT_CLASSNAME);
    }

    @Override
    public Set<ConfigOption<?>> optionalOptions() {
        return Sets.newHashSet(HTTP_CLIENT_IS_ARRAY);
    }
}
```

## 定义DecodingFormat

* 实现接口`DecodingFormat`

```java
package dev.learn.flink.tablesql.httpConnector.deserializer;

import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.table.connector.ChangelogMode;
import org.apache.flink.table.connector.format.DecodingFormat;
import org.apache.flink.table.connector.source.DynamicTableSource;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.types.DataType;
import org.apache.flink.table.types.logical.LogicalType;
import org.apache.flink.types.RowKind;

import java.util.List;

/**
 * @fileName: HttpJsonBeanFormat.java
 * @description: HttpJsonBeanFormat.java类说明
 * @author: by echo huang
 * @date: 2021/1/17 7:11 下午
 */
public class HttpJsonBeanFormat implements DecodingFormat<DeserializationSchema<RowData>> {
    private final String formatClassName;
    private final Boolean isArray;

    public HttpJsonBeanFormat(String formatClassName, Boolean isArray) {
        this.formatClassName = formatClassName;
        this.isArray = isArray;
    }

    @Override
    public DeserializationSchema<RowData> createRuntimeDecoder(DynamicTableSource.Context context, DataType producedDataType) {
        // create type information for the DeserializationSchema
        final TypeInformation<RowData> producedTypeInfo = context.createTypeInformation(
                producedDataType);

        // most of the code in DeserializationSchema will not work on internal data structures
        // create a converter for conversion at the end
        final DynamicTableSource.DataStructureConverter converter = context.createDataStructureConverter(producedDataType);

        // use logical types during runtime for parsing
        List<LogicalType> parsingTypes = producedDataType.getLogicalType().getChildren();

        // create runtime class
        return new HttpJsonBeanDeserializer(parsingTypes, converter, producedTypeInfo, formatClassName, isArray);
    }

    @Override
    public ChangelogMode getChangelogMode() {
        return ChangelogMode.newBuilder()
                .addContainedKind(RowKind.INSERT)
                .build();
    }
}

```

## 定义DeserializationSchema

* 实现接口`DeserializationSchema`

```java
package dev.learn.flink.tablesql.httpConnector.deserializer;

import com.alibaba.fastjson.JSON;
import com.google.common.base.Charsets;
import org.apache.commons.lang3.ClassUtils;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.table.connector.source.DynamicTableSource;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.types.logical.LogicalType;
import org.apache.flink.table.types.logical.LogicalTypeRoot;
import org.apache.flink.types.Row;
import org.apache.flink.types.RowKind;

import java.io.IOException;
import java.lang.reflect.Field;
import java.util.List;
import java.util.Objects;

/**
 * @fileName: HttpJsonBeanDeserializer.java
 * @description: HttpJsonBeanDeserializer.java类说明
 * @author: by echo huang
 * @date: 2021/1/17 7:16 下午
 */
public class HttpJsonBeanDeserializer implements DeserializationSchema<RowData> {
    private final List<LogicalType> parsingTypes;
    private final DynamicTableSource.DataStructureConverter converter;
    private final TypeInformation<RowData> producedTypeInfo;
    private final Boolean isArray;
    private final String formatClassName;

    public HttpJsonBeanDeserializer(List<LogicalType> parsingTypes, DynamicTableSource.DataStructureConverter converter, TypeInformation<RowData> producedTypeInfo, String formatClassNam, Boolean isArray) {
        this.parsingTypes = parsingTypes;
        this.formatClassName = formatClassNam;
        this.converter = converter;
        this.producedTypeInfo = producedTypeInfo;
        this.isArray = isArray;
    }

    @Override
    public RowData deserialize(byte[] bytes) throws IOException {
        String dataStr = new String(bytes, Charsets.UTF_8);
        Row row = new Row(RowKind.INSERT, parsingTypes.size());
        try {
            Class<?> formatClazz = ClassUtils.getClass(this.formatClassName);
            if (this.isArray) {
                List<?> arrayData = JSON.parseArray(dataStr, formatClazz);
                for (Object subData : arrayData) {
                    extracted(subData, row);
                }
            } else {
                Object data = JSON.parseObject(dataStr, formatClazz);
                extracted(data, row);
            }
        } catch (ClassNotFoundException | IllegalAccessException e) {
            throw new RuntimeException(formatClassName + "类不能存在!", e);
        }
        return (RowData) converter.toInternal(row);
    }

    private void extracted(Object data, Row row) throws IllegalAccessException {
        Class<?> subClazz = data.getClass();
        Field[] fields = subClazz.getFields();
        for (int i = 0; i < this.parsingTypes.size(); i++) {
            Field field = fields[i];
            field.setAccessible(true);
            row.setField(i, parse(this.parsingTypes.get(i).getTypeRoot(), String.valueOf(field.get(i))));
        }
    }

    private Object parse(LogicalTypeRoot root, String value) {
        switch (root) {
            case INTEGER:
                return Integer.parseInt(value);
            case VARCHAR:
                return value;
            case BOOLEAN:
                return Boolean.parseBoolean(value);
            case BIGINT:
                return Long.parseLong(value);
            default:
                throw new IllegalArgumentException();
        }
    }

    @Override
    public boolean isEndOfStream(RowData rowData) {
        return Objects.isNull(rowData);
    }

    @Override
    public TypeInformation<RowData> getProducedType() {
        return producedTypeInfo;
    }
}
```

## 定义TableSource

* 根据所需功能实现对应接口，如`LookupTableSource/ScanTableSource`等

```java
package dev.learn.flink.tablesql.httpConnector.source;

import dev.learn.flink.tablesql.httpConnector.options.ConnectionOptions;
import dev.learn.flink.tablesql.httpConnector.options.HttpClientOptions;
import dev.learn.flink.tablesql.httpConnector.options.RequestParamOptions;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.table.connector.ChangelogMode;
import org.apache.flink.table.connector.format.DecodingFormat;
import org.apache.flink.table.connector.source.DynamicTableSource;
import org.apache.flink.table.connector.source.ScanTableSource;
import org.apache.flink.table.connector.source.SourceFunctionProvider;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.types.DataType;

/**
 * @fileName: UDFTableSource.java
 * @description: UDFTableSource.java类说明
 * @author: by echo huang
 * @date: 2021/1/16 4:12 下午
 */
public class HttpTableSource implements ScanTableSource {
    private final RequestParamOptions requestParamOptions;
    private final ConnectionOptions connectionOptions;
    private final HttpClientOptions httpClientOptions;
    private final DataType producedDataType;
    private final DecodingFormat<DeserializationSchema<RowData>> decodingFormat;

    public HttpTableSource(DecodingFormat<DeserializationSchema<RowData>> decodingFormat, RequestParamOptions requestParamOptions, ConnectionOptions connectionOptions, HttpClientOptions httpClientOptions, DataType producedDataType) {
        this.decodingFormat = decodingFormat;
        this.requestParamOptions = requestParamOptions;
        this.connectionOptions = connectionOptions;
        this.httpClientOptions = httpClientOptions;
        this.producedDataType = producedDataType;
    }

    @Override
    public DynamicTableSource copy() {
        return new HttpTableSource(decodingFormat, requestParamOptions, connectionOptions, httpClientOptions, producedDataType);
    }

    @Override
    public String asSummaryString() {
        return "Http Table Source";
    }

    @Override
    public ChangelogMode getChangelogMode() {
        return decodingFormat.getChangelogMode();
    }

    @Override
    public ScanRuntimeProvider getScanRuntimeProvider(ScanContext scanContext) {
        // 获取序列化的schema
        DeserializationSchema<RowData> deserializer = decodingFormat.createRuntimeDecoder(scanContext, producedDataType);

        HttpSourceFunction sourceFunction = new HttpSourceFunction(requestParamOptions, connectionOptions, httpClientOptions, deserializer);

        return SourceFunctionProvider.of(sourceFunction, false);
    }
}
```

## 定义SourceFunction

* 实现`RichSourceFunction`/`ResultTypeQueryable`接口

```java
package dev.learn.flink.tablesql.httpConnector.source;

import com.google.common.base.Preconditions;
import dev.learn.flink.tablesql.httpConnector.options.ConnectionOptions;
import dev.learn.flink.tablesql.httpConnector.options.HttpClientOptions;
import dev.learn.flink.tablesql.httpConnector.options.RequestParamOptions;
import dev.learn.utils.http.OkHttpClientUtils;
import okhttp3.Call;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import org.apache.commons.lang3.ArrayUtils;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.typeutils.ResultTypeQueryable;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.functions.source.RichSourceFunction;
import org.apache.flink.table.data.RowData;

import java.util.Objects;

/**
 * @fileName: HttpSourceFunction.java
 * @description: HttpSourceFunction.java类说明
 * @author: by echo huang
 * @date: 2021/1/17 11:44 下午
 */
public class HttpSourceFunction extends RichSourceFunction<RowData> implements ResultTypeQueryable<RowData> {
    private final RequestParamOptions requestParamOptions;
    private final ConnectionOptions connectionOptions;
    private final HttpClientOptions httpClientOptions;
    private final DeserializationSchema<RowData> deserializer;
    private transient OkHttpClient httpClient;
    private boolean isRunning = true;

    public HttpSourceFunction(RequestParamOptions requestParamOptions, ConnectionOptions connectionOptions, HttpClientOptions httpClientOptions, DeserializationSchema<RowData> deserializer) {
        this.requestParamOptions = requestParamOptions;
        this.connectionOptions = connectionOptions;
        this.httpClientOptions = httpClientOptions;
        this.deserializer = deserializer;
    }

    @Override
    public void open(Configuration parameters) throws Exception {
        OkHttpClientUtils okHttpClientUtils = new OkHttpClientUtils();
        this.httpClient = okHttpClientUtils.initialHttpClient(httpClientOptions, connectionOptions, false);
    }

    @Override
    public void run(SourceContext<RowData> ctx) throws Exception {
        while (isRunning) {
            String headers = requestParamOptions.getHeaders();
            String requestType = requestParamOptions.getRequestType();
            String[] headersArr = headers.split(",");
            Call request = null;
            if (ArrayUtils.isNotEmpty(headersArr)) {
                for (String headerKv : headersArr) {
                    String[] headerKvArr = headerKv.split(":");
                    Preconditions.checkArgument(ArrayUtils.isNotEmpty(headerKvArr) && headerKv.length() == 2, "header参数异常");

                    switch (RequestParamOptions.RequestType.valueOf(requestType)) {
                        case GET:
                            request = httpClient.newCall(new Request.Builder().get().url(requestParamOptions.getRequestUrl()).addHeader(headerKvArr[0], headerKvArr[1]).build());
                            break;
                        case PATCH:
                            break;
                        case POST:
                            break;
                        case DELETE:
                            break;
                        default:
                            throw new RuntimeException("请求类型不支持");
                    }
                }
                if (null != request) {
                    byte[] result = Objects.requireNonNull(request.execute().body()).bytes();
                    ctx.collect(deserializer.deserialize(result));
                }
            }
        }
    }


    @Override
    public void cancel() {
        isRunning = false;
        httpClient = null;
    }

    @Override
    public TypeInformation<RowData> getProducedType() {
        return deserializer.getProducedType();
    }
}
```

