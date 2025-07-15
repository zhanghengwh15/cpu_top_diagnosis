package com.example.cputopdemo.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * CPU密集型任务服务
 * 用于模拟CPU飙升导致服务无响应
 * 
 * @author 开发者
 * @since 1.0.0
 */
@Slf4j
@Service
public class CpuIntensiveService {
    
    private final ExecutorService executorService;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicInteger activeThreads = new AtomicInteger(0);
    
    public CpuIntensiveService() {
        // 创建线程池，限制最大线程数为10，防止影响主机
        this.executorService = new ThreadPoolExecutor(
            1, 10, 60L, TimeUnit.SECONDS,
            new LinkedBlockingQueue<>(100),
            new ThreadPoolExecutor.CallerRunsPolicy()
        );
    }
    
    /**
     * 启动CPU密集型任务
     * 
     * @param duration 持续时间（秒）
     * @param cpuUsage CPU使用率百分比
     * @param threadCount 线程数量
     * @return 任务ID
     */
    public String startCpuTask(int duration, int cpuUsage, int threadCount) {
        if (isRunning.get()) {
            throw new IllegalStateException("已有CPU任务正在运行");
        }
        
        log.info("启动CPU密集型任务 - 持续时间: {}秒, CPU使用率: {}%, 线程数: {}", 
                duration, cpuUsage, threadCount);
        
        isRunning.set(true);
        activeThreads.set(threadCount);
        
        // 为每个线程启动CPU密集型任务
        for (int i = 0; i < threadCount; i++) {
            final int threadIndex = i;
            executorService.submit(() -> {
                try {
                    runCpuIntensiveTask(duration, cpuUsage, threadIndex);
                } catch (Exception e) {
                    log.error("CPU任务执行异常 - 线程: {}", threadIndex, e);
                } finally {
                    activeThreads.decrementAndGet();
                    if (activeThreads.get() == 0) {
                        isRunning.set(false);
                        log.info("所有CPU任务已完成");
                    }
                }
            });
        }
        
        return "cpu-task-" + System.currentTimeMillis();
    }
    
    /**
     * 执行CPU密集型任务
     * 
     * @param duration 持续时间（秒）
     * @param cpuUsage CPU使用率百分比
     * @param threadIndex 线程索引
     */
    private void runCpuIntensiveTask(int duration, int cpuUsage, int threadIndex) {
        long startTime = System.currentTimeMillis();
        long endTime = startTime + (duration * 1000L);
        
        log.info("线程 {} 开始执行CPU密集型任务", threadIndex);
        
        while (System.currentTimeMillis() < endTime) {
            // 计算工作时间和睡眠时间来控制CPU使用率
            long workTime = (long) (100 * cpuUsage / 100.0); // 毫秒
            long sleepTime = 100 - workTime;
            
            // CPU密集型计算
            long workStart = System.nanoTime();
            while (System.nanoTime() - workStart < workTime * 1_000_000) {
                // 执行数学计算来消耗CPU
                Math.sqrt(Math.random() * 1000000);
                Math.sin(Math.random() * Math.PI);
                Math.cos(Math.random() * Math.PI);
            }
            
            // 睡眠来控制CPU使用率
            if (sleepTime > 0) {
                try {
                    Thread.sleep(sleepTime);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        
        log.info("线程 {} 完成CPU密集型任务", threadIndex);
    }
    
    /**
     * 停止所有CPU任务
     */
    public void stopCpuTask() {
        if (isRunning.get()) {
            log.info("正在停止CPU密集型任务");
            isRunning.set(false);
            // 关闭线程池
            executorService.shutdown();
            try {
                if (!executorService.awaitTermination(10, TimeUnit.SECONDS)) {
                    executorService.shutdownNow();
                }
            } catch (InterruptedException e) {
                executorService.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
    }
    
    /**
     * 获取任务状态
     * 
     * @return 任务状态信息
     */
    public TaskStatus getTaskStatus() {
        return new TaskStatus(
            isRunning.get(),
            activeThreads.get(),
            executorService.isShutdown(),
            executorService.isTerminated()
        );
    }
    
    /**
     * 任务状态信息
     */
    public static class TaskStatus {
        private final boolean running;
        private final int activeThreads;
        private final boolean shutdown;
        private final boolean terminated;
        
        public TaskStatus(boolean running, int activeThreads, boolean shutdown, boolean terminated) {
            this.running = running;
            this.activeThreads = activeThreads;
            this.shutdown = shutdown;
            this.terminated = terminated;
        }
        
        // Getters
        public boolean isRunning() { return running; }
        public int getActiveThreads() { return activeThreads; }
        public boolean isShutdown() { return shutdown; }
        public boolean isTerminated() { return terminated; }
    }
} 