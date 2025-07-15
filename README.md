# CPU Top Demo - SpringBoot学习项目

## 项目简介

这是一个SpringBoot学习项目，主要用于模拟Java CPU突然飙升导致服务无响应的情况。项目包含CPU密集型任务模拟、健康检查接口，以及JVM参数限制来保护主机。

## 项目特性

- 🚀 **CPU密集型任务模拟**: 可控制CPU使用率和持续时间
- 🔍 **健康检查接口**: 当CPU任务运行时自动将健康状态设置为DOWN
- 🛡️ **JVM参数限制**: 防止CPU任务影响主机性能
- 📊 **实时监控**: 提供多种监控和诊断工具
- 🔧 **阿里云Maven镜像**: 快速依赖下载

## 快速开始

### 1. 环境要求

- JDK 8+
- Maven 3.6+
- 操作系统: Linux/macOS/Windows

### 2. 编译运行

```bash
# 克隆项目
git clone <repository-url>
cd cpu_top

# 编译项目
mvn clean package

# 运行项目 (推荐使用JVM参数限制)
java -Xmx512m -Xms256m -XX:ActiveProcessorCount=1 -jar target/cpu-top-demo-1.0.0.jar
```

### 3. 测试CPU飙升

```bash
# 启动CPU密集型任务 (80% CPU使用率，持续60秒，4个线程)
curl -X POST http://localhost:8080/api/cpu/start \
  -H "Content-Type: application/json" \
  -d '{
    "duration": 60,
    "cpuUsage": 80,
    "threadCount": 4
  }'

# 检查任务状态
curl http://localhost:8080/api/cpu/status

# 停止任务
curl -X POST http://localhost:8080/api/cpu/stop
```

## API接口

### 问题描述
在macOS上，`jstack`命令可能无法正常工作，导致无法获取Java线程转储。

### 解决方案

### 健康检查

| 接口 | 方法 | 描述 |
|------|------|------|
| `/health` | GET | 详细健康检查 |
| `/health/ping` | GET | 简单心跳检查 |
| `/actuator/health` | GET | Spring Boot Actuator健康检查 |

## 诊断脚本

项目包含两个诊断脚本，用于定位CPU飙升问题：

### 1. 完整诊断脚本 (`cpu_diagnosis.sh`)

功能全面的CPU诊断工具，支持多种分析模式：

```bash
# 完整诊断
./cpu_diagnosis.sh

# 实时监控
./cpu_diagnosis.sh -r

# 只分析Java进程
./cpu_diagnosis.sh -j

# 分析指定进程
./cpu_diagnosis.sh -p 1234

# 系统资源分析
./cpu_diagnosis.sh -s

# 网络连接分析
./cpu_diagnosis.sh -n
```

### 2. 快速检查脚本 (`quick_cpu_check.sh`)

紧急情况下的快速诊断工具：

```bash
# 快速检查
./quick_cpu_check.sh
```

## 诊断脚本功能

### 系统信息收集
- 系统版本和CPU核心数
- 内存使用情况
- 系统负载
- 当前时间

### 进程分析
- CPU使用率最高的进程
- Java进程详细信息
- 进程线程信息
- JVM参数分析

### Java进程深度分析
- 线程转储生成
- 线程状态统计
- 死锁检测
- CPU密集型线程识别
- JVM内存使用情况

### 网络和资源分析
- 网络连接数统计
- 活跃连接分析
- 监听端口检查
- 磁盘I/O监控
- 文件描述符使用情况

### 实时监控
- 实时CPU使用率
- 进程状态变化
- 内存使用趋势
- 系统负载监控

## JVM参数建议

为了防止CPU任务影响主机性能，建议使用以下JVM参数：

```bash
# 内存限制
-Xmx512m -Xms256m

# CPU限制 (只使用1个CPU核心)
-XX:ActiveProcessorCount=1

# GC优化
-XX:+UseG1GC -XX:MaxGCPauseMillis=200

# 其他优化
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/tmp/
```

## 使用场景

### 1. 学习目的
- 了解CPU密集型任务对系统的影响
- 学习Spring Boot Actuator的使用
- 掌握JVM参数调优
- 学习系统诊断方法

### 2. 测试目的
- 测试监控系统的告警机制
- 验证健康检查的准确性
- 测试自动重启功能
- 验证JVM资源限制

### 3. 开发目的
- 开发CPU监控工具
- 实现自动故障恢复
- 构建性能测试框架
- 开发诊断脚本

## 注意事项

⚠️ **重要提醒**:

1. **生产环境谨慎使用**: 此项目主要用于学习和测试，生产环境请谨慎使用
2. **资源限制**: 务必使用JVM参数限制资源使用，避免影响主机
3. **监控告警**: 建议配合监控系统使用，及时发现问题
4. **权限控制**: 诊断脚本可能需要root权限才能获取完整信息
5. **工具依赖**: 某些诊断功能需要安装额外的系统工具

## 故障排查

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口占用
   lsof -i :8080
   # 杀死进程
   kill -9 <PID>
   ```

2. **内存不足**
   ```bash
   # 调整JVM内存参数
   java -Xmx1g -Xms512m -jar target/cpu-top-demo-1.0.0.jar
   ```

3. **权限问题**
   ```bash
   # 给脚本执行权限
   chmod +x *.sh
   ```

### 日志查看

```bash
# 查看应用日志
tail -f logs/application.log

# 查看系统日志
tail -f /var/log/syslog

# 查看JVM日志
jstack <PID> > thread_dump.txt
```

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目。

## 许可证

MIT License

## 联系方式

如有问题，请通过以下方式联系：
- 邮箱: [your-email@example.com]
- GitHub: [your-github-username] 