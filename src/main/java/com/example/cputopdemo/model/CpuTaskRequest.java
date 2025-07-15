package com.example.cputopdemo.model;

import lombok.Data;
import javax.validation.constraints.Min;
import javax.validation.constraints.Max;
import javax.validation.constraints.NotNull;

/**
 * CPU任务请求参数
 * 
 * @author 开发者
 * @since 1.0.0
 */
@Data
public class CpuTaskRequest {
    
    /**
     * 任务持续时间（秒）
     */
    @NotNull(message = "任务持续时间不能为空")
    @Min(value = 1, message = "任务持续时间最小为1秒")
    @Max(value = 300, message = "任务持续时间最大为300秒")
    private Integer duration;
    
    /**
     * CPU使用率百分比（1-100）
     */
    @NotNull(message = "CPU使用率不能为空")
    @Min(value = 1, message = "CPU使用率最小为1%")
    @Max(value = 100, message = "CPU使用率最大为100%")
    private Integer cpuUsage;
    
    /**
     * 线程数量
     */
    @NotNull(message = "线程数量不能为空")
    @Min(value = 1, message = "线程数量最小为1")
    @Max(value = 10, message = "线程数量最大为10")
    private Integer threadCount;
} 