# yarn-per-job提交流程

* Flink run -t yarn-per-job -c xxxx xxx.jar

## 提交脚本分析

* `flink run`入口类`org.apache.flink.client.cli.CliFrontend `，通过`config.sh`读取Flink相关环境信息；
* 核心逻辑main方法，具体代码分析可以跟进`CliFrontend#run`方法

```java
public static void main(final String[] args) {
		EnvironmentInformation.logEnvironmentInfo(LOG, "Command Line Client", args);

		// 1. find the configuration directory
		// 获取flink-conf.yaml路径
		final String configurationDirectory = getConfigurationDirectoryFromEnv();

		// 2. load the global configuration
		// 根据路径加载配置
		final Configuration configuration = GlobalConfiguration.loadConfiguration(configurationDirectory);

		// 3. load the custom command lines
		// 加载自定义命令行，依次添加generic、yarn、default三种命令行客户端
		final List<CustomCommandLine> customCommandLines = loadCustomCommandLines(
			configuration,
			configurationDirectory);

		try {
			// 创建CliFrontend
			final CliFrontend cli = new CliFrontend(
				configuration,
				customCommandLines);

			SecurityUtils.install(new SecurityConfiguration(cli.configuration));
			int retCode = SecurityUtils.getInstalledContext()
					.runSecured(() -> cli.parseParameters(args));
			System.exit(retCode);
		}
		catch (Throwable t) {
			final Throwable strippedThrowable = ExceptionUtils.stripException(t, UndeclaredThrowableException.class);
			LOG.error("Fatal error while running command line interface.", strippedThrowable);
			strippedThrowable.printStackTrace();
			System.exit(31);
		}
	}
```



