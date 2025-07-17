# CPU监控定时任务脚本使用说明

## 概述

`cpu_monitor_cron.sh` 是一个智能的CPU监控脚本，能够：
- 每30秒检查一次系统负载
- 当系统负载超过240时自动触发CPU诊断
- 支持多种运行模式（前台、后台、crontab）
- 提供完整的日志记录和状态监控

## 功能特性

### 1. 智能监控
- **实时监控**：每30秒检查系统负载
- **阈值触发**：当 `top -n1 -b | grep "  1 root" | awk '{print $(NF - 3)}'` 结果 > 240 时触发诊断
- **防重复执行**：使用锁文件机制避免重复诊断

### 2. 多种运行模式
- **前台模式**：直接运行，实时显示日志
- **后台模式**：后台运行，日志写入文件
- **容器模式**：适合K8s容器环境运行

### 3. 完整日志系统
- 彩色日志输出
- 时间戳记录
- 日志文件自动轮转
- 错误处理和异常记录

## 使用方法

### 1. 基本命令

```bash
# 显示帮助信息
./cpu_monitor_cron.sh --help

# 启动监控（前台模式）
./cpu_monitor_cron.sh --start

# 停止监控
./cpu_monitor_cron.sh --stop

# 查看状态
./cpu_monitor_cron.sh --status

# 后台运行模式
./cpu_monitor_cron.sh --daemon
```

### 2. 配置参数

脚本开头的配置参数可以根据需要调整：

```bash
# 系统负载阈值（超过此值触发诊断）
CPU_THRESHOLD=240

# 检查间隔（秒）
CHECK_INTERVAL=30

# 日志文件路径
LOG_FILE="./cpu_monitor.log"

# CPU诊断脚本路径
DIAGNOSIS_SCRIPT="./cpu_diagnosis_arthas.sh"

# 锁文件路径
LOCK_FILE="./cpu_monitor.lock"
```

## 运行模式详解

### 1. 前台监控模式

```bash
./cpu_monitor_cron.sh --start
```

**特点：**
- 实时显示监控日志
- 适合调试和测试
- 按Ctrl+C可停止监控

**输出示例：**
```
[INFO] [2024-01-15 10:30:00] 开始CPU监控，检查间隔: 30秒，阈值: 240
[INFO] [2024-01-15 10:30:00] 当前系统负载: 150.5
[INFO] [2024-01-15 10:30:30] 当前系统负载: 180.2
[WARN] [2024-01-15 10:31:00] 系统负载过高: 250.8 (阈值: 240)，开始执行CPU诊断...
[INFO] [2024-01-15 10:31:30] CPU诊断执行成功
```

### 2. 后台监控模式

```bash
./cpu_monitor_cron.sh --daemon
```

**特点：**
- 后台运行，不占用终端
- 所有日志写入文件
- 适合生产环境

### 3. 容器运行模式

```bash
# 在K8s容器中后台运行
./cpu_monitor_cron.sh --daemon

# 在Docker容器中运行
docker exec -it <container_name> /path/to/cpu_monitor_cron.sh --daemon
```

**K8s Deployment示例：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-monitor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-monitor
  template:
    metadata:
      labels:
        app: cpu-monitor
    spec:
      containers:
      - name: cpu-monitor
        image: your-image
        command: ["/path/to/cpu_monitor_cron.sh"]
        args: ["--daemon"]
        volumeMounts:
        - name: logs
          mountPath: /logs
      volumes:
      - name: logs
        emptyDir: {}
```

## 监控逻辑

### 1. 系统负载检测

脚本使用以下命令获取系统负载：
```bash
top -n1 -b | grep "  1 root" | awk '{print $(NF - 3)}'
```

### 2. 触发条件

当检测到的负载值 > 240 时，脚本会：
1. 记录警告日志
2. 检查是否有其他诊断在运行
3. 创建锁文件防止重复执行
4. 调用 `cpu_diagnosis_arthas.sh -a` 执行诊断
5. 清理锁文件

### 3. 防重复机制

- 使用锁文件 `cpu_monitor.lock` 防止重复诊断
- 检查锁文件中的PID是否有效
- 自动清理无效的锁文件

## 日志文件

### 1. 日志格式

```
[级别] [时间戳] 消息内容
```

**日志级别：**
- `[INFO]`：信息日志（绿色）
- `[WARN]`：警告日志（黄色）
- `[ERROR]`：错误日志（红色）

### 2. 日志内容

- 监控启动/停止信息
- 系统负载检测结果
- 诊断触发和执行状态
- 错误和异常信息

### 3. 日志管理

```bash
# 查看日志文件
tail -f cpu_monitor.log

# 查看日志文件大小
du -h cpu_monitor.log

# 清空日志文件
> cpu_monitor.log
```

## 故障排除

### 1. 常见问题

**问题：脚本无法启动**
```bash
# 检查执行权限
ls -la cpu_monitor_cron.sh

# 添加执行权限
chmod +x cpu_monitor_cron.sh
```

**问题：无法获取系统负载**
```bash
# 手动测试负载检测命令
top -n1 -b | grep "  1 root" | awk '{print $(NF - 3)}'

# 检查top命令是否可用
which top
```

**问题：诊断脚本不存在**
```bash
# 检查诊断脚本是否存在
ls -la cpu_diagnosis_arthas.sh

# 确保诊断脚本有执行权限
chmod +x cpu_diagnosis_arthas.sh
```

### 2. 调试模式

```bash
# 启用调试输出
bash -x cpu_monitor_cron.sh --start
```

### 3. 状态检查

```bash
# 检查监控进程状态
./cpu_monitor_cron.sh --status

# 检查系统负载
top -n1 -b | grep "  1 root" | awk '{print $(NF - 3)}'

# 检查锁文件
ls -la cpu_monitor.lock
```

## 最佳实践

### 1. 生产环境部署

1. **在K8s容器中运行**：
   ```bash
   ./cpu_monitor_cron.sh --daemon
   ```

2. **监控日志文件**：
   ```bash
   tail -f cpu_monitor.log
   ```

3. **定期检查状态**：
   ```bash
   ./cpu_monitor_cron.sh --status
   ```

### 2. 阈值调优

根据系统性能调整阈值：
- **高配置服务器**：可设置更高阈值（如300-500）
- **低配置服务器**：可设置更低阈值（如100-200）
- **测试环境**：可设置较低阈值进行测试

### 3. 日志轮转

建议配置日志轮转避免文件过大：
```bash
# 添加到 /etc/logrotate.d/
/path/to/cpu_monitor.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## 依赖要求

### 1. 系统要求
- Linux/macOS系统
- Bash shell
- `top` 命令
- `bc` 命令（用于浮点数计算）

### 2. 脚本依赖
- `cpu_diagnosis_arthas.sh`：CPU诊断脚本
- `arthas-boot.jar`：Arthas工具（诊断脚本会自动下载）

### 3. 权限要求
- 脚本执行权限
- 进程查看权限
- 文件读写权限
- 容器内运行权限

## 版本信息

- **版本**：1.0.0
- **作者**：开发者
- **更新日期**：2024-01-15
- **兼容性**：Linux, macOS 