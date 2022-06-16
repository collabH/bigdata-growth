# ProcessingTimeService

* ProcessingTime时间服务，提供获取当前processing时间，注册timer等操作

```java
public interface ProcessingTimeService {

	/**
	 * 获取当前Processing时间
	 * Returns the current processing time.
	 */
	long getCurrentProcessingTime();

	/**
	 * 注册一个timer异步
	 */
	ScheduledFuture<?> registerTimer(long timestamp, ProcessingTimeCallback target);

	/**
	 * Registers a task to be executed repeatedly at a fixed rate.
	 */
	ScheduledFuture<?> scheduleAtFixedRate(ProcessingTimeCallback callback, long initialDelay, long period);

	/**
	 * Registers a task to be executed repeatedly with a fixed delay.
	 *
	 */
	ScheduledFuture<?> scheduleWithFixedDelay(ProcessingTimeCallback callback, long initialDelay, long period);

	CompletableFuture<Void> quiesce();
}
```

## ProcessingTimeCallback

* 用于执行timer触发的动作

```java
public interface ProcessingTimeCallback {

	/**
	 * timer触发方法
	 */
	void onProcessingTime(long timestamp) throws Exception;
}
```

## TimeService

* 提供检测timeservice状态接口以及关闭方法

```java
public interface TimerService extends ProcessingTimeService {

	/**
	 * timerService是否终止状态
	 */
	boolean isTerminated();

	/**
	 * 关闭TimerService
	 */
	void shutdownService();

	/**优雅关闭
	 */
	boolean shutdownServiceUninterruptible(long timeoutMs);
}
```

## SystemProcessingTimeService

* 系统ProcessTime服务，根据System#currentTimeMillis()指定ProcessingTime

```java
public class SystemProcessingTimeService implements TimerService {

	private static final Logger LOG = LoggerFactory.getLogger(SystemProcessingTimeService.class);
	/**
	 * 定义TimeService状态
	 */
	private static final int STATUS_ALIVE = 0;
	private static final int STATUS_QUIESCED = 1;
	private static final int STATUS_SHUTDOWN = 2;

	// ------------------------------------------------------------------------

	/** The executor service that schedules and calls the triggers of this task. */
	// 调度线程池，线程数为1
	private final ScheduledThreadPoolExecutor timerService;
	// 异常处理器
	private final ExceptionHandler exceptionHandler;
	// timeService状态
	private final AtomicInteger status;
	// 未完成的定时器
	private final CompletableFuture<Void> quiesceCompletedFuture;

	@VisibleForTesting
	SystemProcessingTimeService(ExceptionHandler exceptionHandler) {
		this(exceptionHandler, null);
	}

	SystemProcessingTimeService(ExceptionHandler exceptionHandler, ThreadFactory threadFactory) {

		this.exceptionHandler = checkNotNull(exceptionHandler);
		// 默认状态 alive
		this.status = new AtomicInteger(STATUS_ALIVE);
		this.quiesceCompletedFuture = new CompletableFuture<>();

		if (threadFactory == null) {
			this.timerService = new ScheduledTaskExecutor(1);
		} else {
			this.timerService = new ScheduledTaskExecutor(1, threadFactory);
		}

		// tasks should be removed if the future is canceled，如果futrue被取消，task应该被移除
		this.timerService.setRemoveOnCancelPolicy(true);

		// make sure shutdown removes all pending tasks 确保关机删除所有未完成的任务
		// timeService关闭后，任务被终止和移除，相当于shutdownNow
		this.timerService.setContinueExistingPeriodicTasksAfterShutdownPolicy(false);
		// 设置为true，标示关闭后执行，false标示不执行
		this.timerService.setExecuteExistingDelayedTasksAfterShutdownPolicy(false);
	}

	@Override
	public long getCurrentProcessingTime() {
		// 系统时间
		return System.currentTimeMillis();
	}

	/**
	 * Registers a task to be executed no sooner than time {@code timestamp}, but without strong
	 * guarantees of order.
	 *
	 * @param timestamp Time when the task is to be enabled (in processing time)
	 * @param callback    The task to be executed
	 * @return The future that represents the scheduled task. This always returns some future,
	 *         even if the timer was shut down
	 */
	@Override
	public ScheduledFuture<?> registerTimer(long timestamp, ProcessingTimeCallback callback) {

		// 计算timestamp和getCurrentProcessingTime的延迟，在timestamp和当前时间的差值上再延迟1ms，为了watermark的判断，防止出现边界清空，小于watermakr的数据都会被丢弃
		long delay = ProcessingTimeServiceUtil.getProcessingTimeDelay(timestamp, getCurrentProcessingTime());

		// we directly try to register the timer and only react to the status on exception
		// that way we save unnecessary volatile accesses for each timer
		try {
			// 在delay ms后执行wrapOnTimerCallback
			return timerService.schedule(wrapOnTimerCallback(callback, timestamp), delay, TimeUnit.MILLISECONDS);
		}
		catch (RejectedExecutionException e) {
			final int status = this.status.get();
			// 停止状态，没有timer
			if (status == STATUS_QUIESCED) {
				return new NeverCompleteFuture(delay);
			}
			else if (status == STATUS_SHUTDOWN) {
				throw new IllegalStateException("Timer service is shut down");
			}
			else {
				// something else happened, so propagate the exception
				throw e;
			}
		}
	}

	@Override
	public ScheduledFuture<?> scheduleAtFixedRate(ProcessingTimeCallback callback, long initialDelay, long period) {
		return scheduleRepeatedly(callback, initialDelay, period, false);
	}

	@Override
	public ScheduledFuture<?> scheduleWithFixedDelay(ProcessingTimeCallback callback, long initialDelay, long period) {
		return scheduleRepeatedly(callback, initialDelay, period, true);
	}

	private ScheduledFuture<?> scheduleRepeatedly(ProcessingTimeCallback callback, long initialDelay, long period, boolean fixedDelay) {
		// 下次执行的时间
		final long nextTimestamp = getCurrentProcessingTime() + initialDelay;
		// 获取调度任务
		final Runnable task = wrapOnTimerCallback(callback, nextTimestamp, period);

		// we directly try to register the timer and only react to the status on exception
		// that way we save unnecessary volatile accesses for each timer
		try {
			return fixedDelay
					? timerService.scheduleWithFixedDelay(task, initialDelay, period, TimeUnit.MILLISECONDS)
					: timerService.scheduleAtFixedRate(task, initialDelay, period, TimeUnit.MILLISECONDS);
		} catch (RejectedExecutionException e) {
			final int status = this.status.get();
			if (status == STATUS_QUIESCED) {
				return new NeverCompleteFuture(initialDelay);
			}
			else if (status == STATUS_SHUTDOWN) {
				throw new IllegalStateException("Timer service is shut down");
			}
			else {
				// something else happened, so propagate the exception
				throw e;
			}
		}
	}

	/**
	 * @return {@code true} is the status of the service
	 * is {@link #STATUS_ALIVE}, {@code false} otherwise.
	 */
	@VisibleForTesting
	boolean isAlive() {
		return status.get() == STATUS_ALIVE;
	}

	@Override
	public boolean isTerminated() {
		return status.get() == STATUS_SHUTDOWN;
	}

	@Override
	public CompletableFuture<Void> quiesce() {
		if (status.compareAndSet(STATUS_ALIVE, STATUS_QUIESCED)) {
			timerService.shutdown();
		}

		return quiesceCompletedFuture;
	}

	@Override
	public void shutdownService() {
		if (status.compareAndSet(STATUS_ALIVE, STATUS_SHUTDOWN) ||
				status.compareAndSet(STATUS_QUIESCED, STATUS_SHUTDOWN)) {
			timerService.shutdownNow();
		}
	}

	/**
	 * Shuts down and clean up the timer service provider hard and immediately. This does wait
	 * for all timers to complete or until the time limit is exceeded. Any call to
	 * {@link #registerTimer(long, ProcessingTimeCallback)} will result in a hard exception after calling this method.
	 * @param time time to wait for termination.
	 * @param timeUnit time unit of parameter time.
	 * @return {@code true} if this timer service and all pending timers are terminated and
	 *         {@code false} if the timeout elapsed before this happened.
	 */
	@VisibleForTesting
	boolean shutdownAndAwaitPending(long time, TimeUnit timeUnit) throws InterruptedException {
		shutdownService();
		return timerService.awaitTermination(time, timeUnit);
	}

	@Override
	public boolean shutdownServiceUninterruptible(long timeoutMs) {

		final Deadline deadline = Deadline.fromNow(Duration.ofMillis(timeoutMs));

		boolean shutdownComplete = false;
		boolean receivedInterrupt = false;

		do {
			try {
				// wait for a reasonable time for all pending timer threads to finish
				shutdownComplete = shutdownAndAwaitPending(deadline.timeLeft().toMillis(), TimeUnit.MILLISECONDS);
			} catch (InterruptedException iex) {
				// 强制终端
				receivedInterrupt = true;
				LOG.trace("Intercepted attempt to interrupt timer service shutdown.", iex);
			}
		} while (deadline.hasTimeLeft() && !shutdownComplete);

		if (receivedInterrupt) {
			Thread.currentThread().interrupt();
		}

		return shutdownComplete;
	}

	// safety net to destroy the thread pool
	// 垃圾回收的时候触发，强制关闭timerService
	@Override
	protected void finalize() throws Throwable {
		super.finalize();
		timerService.shutdownNow();
	}

	@VisibleForTesting
	int getNumTasksScheduled() {
		// 获取调度任务个数
		BlockingQueue<?> queue = timerService.getQueue();
		if (queue == null) {
			return 0;
		} else {
			return queue.size();
		}
	}

	// ------------------------------------------------------------------------

	private class ScheduledTaskExecutor extends ScheduledThreadPoolExecutor {

		public ScheduledTaskExecutor(int corePoolSize) {
			super(corePoolSize);
		}

		public ScheduledTaskExecutor(int corePoolSize, ThreadFactory threadFactory) {
			super(corePoolSize, threadFactory);
		}

		@Override
		protected void terminated() {
			super.terminated();
			quiesceCompletedFuture.complete(null);
		}
	}

	/**
	 * An exception handler, called when {@link ProcessingTimeCallback} throws an exception.
	 */
	interface ExceptionHandler {
		void handleException(Exception ex);
	}

	/**
	 * 将ProcessingTimeCallback包装成Runnable
	 * @param callback
	 * @param timestamp
	 * @return
	 */
	private Runnable wrapOnTimerCallback(ProcessingTimeCallback callback, long timestamp) {
		return new ScheduledTask(status, exceptionHandler, callback, timestamp, 0);
	}

	private Runnable wrapOnTimerCallback(ProcessingTimeCallback callback, long nextTimestamp, long period) {
		return new ScheduledTask(status, exceptionHandler, callback, nextTimestamp, period);
	}

	/**
	 * Timer调度Task
	 */
	private static final class ScheduledTask implements Runnable {
		// 服务状态
		private final AtomicInteger serviceStatus;
		// 异常处理器
		private final ExceptionHandler exceptionHandler;
		// Processing回调函数
		private final ProcessingTimeCallback callback;
		// 下次触发的时间
		private long nextTimestamp;
		// 间隔的周期
		private final long period;

		ScheduledTask(
				AtomicInteger serviceStatus,
				ExceptionHandler exceptionHandler,
				ProcessingTimeCallback callback,
				long timestamp,
				long period) {
			this.serviceStatus = serviceStatus;
			this.exceptionHandler = exceptionHandler;
			this.callback = callback;
			this.nextTimestamp = timestamp;
			this.period = period;
		}

		@Override
		public void run() {
			// 判断服务状态
			if (serviceStatus.get() != STATUS_ALIVE) {
				return;
			}
			try {
				// 触发onProcessingTime
				callback.onProcessingTime(nextTimestamp);
			} catch (Exception ex) {
				exceptionHandler.handleException(ex);
			}
			// 周期调用，每隔period执行一次
			nextTimestamp += period;
		}
	}
}
```

## NeverFireProcessingTimeService

* 处理时间服务，其计时器永不触发，因此所有计时器都包含在savepoint中，可以获取当前系统的processing time

# TimerService

* timer服务包含获取processing时间、watermakr、注册timer等。

```java
public interface TimerService {

	// 设置timer只支持keyed stream 
	/** Error string for {@link UnsupportedOperationException} on registering timers. */
	String UNSUPPORTED_REGISTER_TIMER_MSG = "Setting timers is only supported on a keyed streams.";
	// 删除timer只支持keyed stream
	/** Error string for {@link UnsupportedOperationException} on deleting timers. */
	String UNSUPPORTED_DELETE_TIMER_MSG = "Deleting timers is only supported on a keyed streams.";

	/** Returns the current processing time. */
	long currentProcessingTime();

	/** Returns the current event-time watermark. */
	long currentWatermark();

	/**
	 * Registers a timer to be fired when processing time passes the given time.
	 *
	 * <p>Timers can internally be scoped to keys and/or windows. When you set a timer
	 * in a keyed context, such as in an operation on
	 * {@link org.apache.flink.streaming.api.datastream.KeyedStream} then that context
	 * will also be active when you receive the timer notification.
	 */
	void registerProcessingTimeTimer(long time);

	/**
	 * Registers a timer to be fired when the event time watermark passes the given time.
	 *
	 * <p>Timers can internally be scoped to keys and/or windows. When you set a timer
	 * in a keyed context, such as in an operation on
	 * {@link org.apache.flink.streaming.api.datastream.KeyedStream} then that context
	 * will also be active when you receive the timer notification.
	 */
	void registerEventTimeTimer(long time);

	/**
	 * Deletes the processing-time timer with the given trigger time. This method has only an effect if such a timer
	 * was previously registered and did not already expire.
	 *
	 * <p>Timers can internally be scoped to keys and/or windows. When you delete a timer,
	 * it is removed from the current keyed context.
	 */
	void deleteProcessingTimeTimer(long time);

	/**
	 * Deletes the event-time timer with the given trigger time. This method has only an effect if such a timer
	 * was previously registered and did not already expire.
	 *
	 * <p>Timers can internally be scoped to keys and/or windows. When you delete a timer,
	 * it is removed from the current keyed context.
	 */
	void deleteEventTimeTimer(long time);
}
```

## SimpleTimerService

* 使用`InternalTimerService`实现的SimpleTimerService

# InternalTimerService

* Timer是维护在JVM堆内存中的，如果频繁注册大量Timer，或者同时触发大量Timer，也是一笔不小的开销。时间窗口风暴问题

```java
public interface InternalTimerService<N> {

	long currentProcessingTime();

	long currentWatermark();

	void registerProcessingTimeTimer(N namespace, long time);

	void deleteProcessingTimeTimer(N namespace, long time);

	void registerEventTimeTimer(N namespace, long time);

	void deleteEventTimeTimer(N namespace, long time);

	/**
	 * 遍历全部eventTimer
	 */
	void forEachEventTimeTimer(BiConsumerWithException<N, Long, Exception> consumer) throws Exception;
	void forEachProcessingTimeTimer(BiConsumerWithException<N, Long, Exception> consumer) throws Exception;
}
```

- TimerService接口的实现类为SimpleTimerService，它实际上又是InternalTimerService的代理。
- InternalTimerService的实例由getInternalTimerService()方法取得，该方法定义在所有算子的基类AbstractStreamOperator中.
- KeyedProcessOperator.processElement()方法调用用户自定义函数的processElement()方法，顺便将上下文实例ContextImpl传了进去，所以用户可以由它获得TimerService来注册Timer。
- Timer在代码中叫做InternalTimer。
- 当Timer触发时，实际上是根据时间特征调用onProcessingTime()/onEventTime()方法（这两个方法来自Triggerable接口），进而触发用户函数的onTimer()回调逻辑。后面还会见到它们。