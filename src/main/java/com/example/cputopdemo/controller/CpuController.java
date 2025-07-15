package com.example.cputopdemo.controller;

import com.example.cputopdemo.model.ApiResponse;
import com.example.cputopdemo.model.CpuTaskRequest;
import com.example.cputopdemo.service.CpuIntensiveService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

/**
 * CPU任务控制器
 * 
 * @author 开发者
 * @since 1.0.0
 */
@Slf4j
@RestController
@RequestMapping("/api/cpu")
@Validated
public class CpuController {
    
    @Autowired
    private CpuIntensiveService cpuIntensiveService;
    
    /**
     * 启动CPU密集型任务
     * 
     * @param request 任务请求参数
     * @return 任务ID
     */
    @PostMapping("/start")
    public ApiResponse<String> startCpuTask(@Valid @RequestBody CpuTaskRequest request) {
        try {
            log.info("收到启动CPU任务请求 - 参数: {}", request);
            
            String taskId = cpuIntensiveService.startCpuTask(
                request.getDuration(),
                request.getCpuUsage(),
                request.getThreadCount()
            );
            
            log.info("CPU任务启动成功 - 任务ID: {}", taskId);
            return ApiResponse.success(taskId);
            
        } catch (IllegalStateException e) {
            log.warn("启动CPU任务失败 - 已有任务正在运行");
            return ApiResponse.error(400, e.getMessage());
        } catch (Exception e) {
            log.error("启动CPU任务异常", e);
            return ApiResponse.error(500, "启动CPU任务失败: " + e.getMessage());
        }
    }
    
    /**
     * 停止CPU密集型任务
     * 
     * @return 操作结果
     */
    @PostMapping("/stop")
    public ApiResponse<String> stopCpuTask() {
        try {
            log.info("收到停止CPU任务请求");
            
            cpuIntensiveService.stopCpuTask();
            
            log.info("CPU任务停止成功");
            return ApiResponse.success("CPU任务已停止");
            
        } catch (Exception e) {
            log.error("停止CPU任务异常", e);
            return ApiResponse.error(500, "停止CPU任务失败: " + e.getMessage());
        }
    }
    
    /**
     * 获取CPU任务状态
     * 
     * @return 任务状态
     */
    @GetMapping("/status")
    public ApiResponse<CpuIntensiveService.TaskStatus> getCpuTaskStatus() {
        try {
            CpuIntensiveService.TaskStatus status = cpuIntensiveService.getTaskStatus();
            return ApiResponse.success(status);
        } catch (Exception e) {
            log.error("获取CPU任务状态异常", e);
            return ApiResponse.error(500, "获取任务状态失败: " + e.getMessage());
        }
    }
    
    /**
     * 健康检查接口
     * 
     * @return 健康状态
     */
    @GetMapping("/health")
    public ApiResponse<String> health() {
        return ApiResponse.success("服务正常运行");
    }
} 