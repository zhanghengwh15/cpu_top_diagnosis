package com.example.cputopdemo.controller;

import com.example.cputopdemo.model.ApiResponse;
import com.example.cputopdemo.service.CpuIntensiveService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 健康检查控制器
 * 
 * @author 开发者
 * @since 1.0.0
 */
@Slf4j
@RestController
@RequestMapping("/health")
public class HealthController {
    
    @Autowired
    private CpuIntensiveService cpuIntensiveService;
    
    /**
     * 健康检查接口
     * 
     * @return 健康状态
     */
    @GetMapping
    public ApiResponse<Map<String, Object>> health() {
        try {
            CpuIntensiveService.TaskStatus status = cpuIntensiveService.getTaskStatus();
            
            Map<String, Object> healthInfo = new HashMap<>();
            healthInfo.put("status", status.isRunning() ? "DOWN" : "UP");
            healthInfo.put("cpuTask", status.isRunning() ? "running" : "stopped");
            healthInfo.put("activeThreads", status.getActiveThreads());
            healthInfo.put("message", status.isRunning() ? 
                "CPU密集型任务正在运行，服务可能无响应" : "服务正常运行");
            healthInfo.put("timestamp", System.currentTimeMillis());
            
            if (status.isRunning()) {
                log.warn("健康检查返回DOWN状态 - CPU任务正在运行");
                return ApiResponse.error(503, "服务不可用");
            } else {
                return ApiResponse.success(healthInfo);
            }
            
        } catch (Exception e) {
            log.error("健康检查异常", e);
            Map<String, Object> errorInfo = new HashMap<>();
            errorInfo.put("status", "DOWN");
            errorInfo.put("error", e.getMessage());
            errorInfo.put("message", "健康检查失败");
            errorInfo.put("timestamp", System.currentTimeMillis());
            
            return ApiResponse.error(500, "健康检查失败");
        }
    }
    
    /**
     * 简单心跳检查
     * 
     * @return 心跳状态
     */
    @GetMapping("/ping")
    public ApiResponse<String> ping() {
        return ApiResponse.success("pong");
    }
} 