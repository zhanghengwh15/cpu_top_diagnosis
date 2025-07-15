# Java CPU诊断脚本使用说明

## 概述

这是一套专门用于定位Java进程CPU突然飙升问题的诊断脚本，支持macOS和Linux操作系统。

## 文件结构

```
cpu_top/
├── cpu_diagnosis.sh                    # 智能启动器（主脚本）
├── cpu_diagnosis_macos.sh              # macOS专用脚本
├── cpu_diagnosis_linux.sh              # Linux专用脚本
├── cpu_diagnosis_arthas.sh             # Arthas基础版脚本
├── cpu_diagnosis_arthas_advanced.sh    # Arthas智能增强版脚本
├── arthas_commands.conf                # Arthas命令配置文件
└── README_CPU_DIAGNOSIS.md             # 使用说明
```

## 功能特性

### 核心功能
- **系统信息收集**: 获取操作系统、CPU、内存等基本信息
- **Java进程监控**: 查找和分析Java进程
- **高CPU进程分析**: 识别CPU使用率超过阈值的Java进程
- **线程转储分析**: 使用jstack获取线程信息，分析线程状态
- **死锁检测**: 自动检测Java进程中的死锁情况
- **实时监控**: 实时监控Java进程的CPU使用情况
- **诊断报告**: 生成详细的诊断报告
- **Arthas集成**: 利用Arthas进行深度Java诊断
- **智能分析**: 根据CPU使用率自动选择分析策略
- **配置文件支持**: 支持自定义Arthas命令配置

### 操作系统支持
- **macOS**: 专门针对macOS系统优化，支持macOS特有的Java安装路径
- **Linux**: 针对Linux系统优化，支持常见的Linux发行版

## 使用方法

### 1. 智能启动器（推荐）

使用主脚本，它会自动检测操作系统并选择合适的专用脚本：

```bash
# 给脚本添加执行权限
chmod +x cpu_diagnosis.sh

# 完整诊断
./cpu_diagnosis.sh

# 实时监控
./cpu_diagnosis.sh -r

# 分析指定进程
./cpu_diagnosis.sh -p <PID>

# 分析高CPU进程
./cpu_diagnosis.sh -a

# 诊断Java环境
./cpu_diagnosis.sh -d

# 生成报告
./cpu_diagnosis.sh -g
```

### 2. 直接使用专用脚本

#### macOS用户
```bash
chmod +x cpu_diagnosis_macos.sh
./cpu_diagnosis_macos.sh [选项]
```

#### Linux用户
```bash
chmod +x cpu_diagnosis_linux.sh
./cpu_diagnosis_linux.sh [选项]
```

### 3. 使用Arthas增强版（推荐用于生产环境）

#### Arthas基础版
```bash
chmod +x cpu_diagnosis_arthas.sh
./cpu_diagnosis_arthas.sh [选项]
```

#### Arthas智能增强版
```bash
chmod +x cpu_diagnosis_arthas_advanced.sh
./cpu_diagnosis_arthas_advanced.sh [选项]
```

## 命令行选项

| 选项 | 长选项 | 描述 |
|------|--------|------|
| `-h` | `--help` | 显示帮助信息 |
| `-r` | `--realtime` | 实时监控Java进程 |
| `-a` | `--analyze` | 分析高CPU Java进程 |
| `-p` | `--pid` | 分析指定Java进程ID |
| `-s` | `--system` | 系统基本信息 |
| `-g` | `--generate` | 生成诊断报告 |
| `-d` | `--diagnose` | 诊断Java环境 |

## 使用示例

### 示例1: 完整诊断
```bash
./cpu_diagnosis.sh
```
执行完整的诊断流程，包括系统信息、Java进程分析、高CPU进程分析等。

### 示例2: 实时监控
```bash
./cpu_diagnosis.sh -r
```
实时监控Java进程的CPU使用情况，按Ctrl+C停止。

### 示例3: 分析特定进程
```bash
./cpu_diagnosis.sh -p 1234
```
分析进程ID为1234的Java进程，获取详细的线程信息和JVM状态。

### 示例4: 诊断Java环境
```bash
./cpu_diagnosis.sh -d
```
检查Java环境配置，包括JAVA_HOME、JVM工具可用性等。

### 示例5: Arthas基础诊断
```bash
# 分析高CPU Java进程
./cpu_diagnosis_arthas.sh -a

# 分析指定Java进程
./cpu_diagnosis_arthas.sh -p 1234

# 检查Arthas可用性
./cpu_diagnosis_arthas.sh -c
```

### 示例6: Arthas智能诊断（推荐）
```bash
# 智能分析高CPU Java进程
./cpu_diagnosis_arthas_advanced.sh -a

# 智能分析指定Java进程
./cpu_diagnosis_arthas_advanced.sh -p 1234

# 使用自定义配置文件
./cpu_diagnosis_arthas_advanced.sh -f custom.conf -p 1234
```

## 输出说明

### 1. 系统信息
- 操作系统版本
- CPU核心数
- 内存使用情况
- 系统负载

### 2. Java进程信息
- 进程ID和基本信息
- CPU和内存使用率
- 启动命令

### 3. 线程分析
- 线程状态统计
- 死锁检测
- CPU密集型线程识别

### 4. JVM信息
- 内存使用情况
- GC状态
- 线程转储文件位置

### 5. Arthas分析结果（增强版）
- 线程分析：识别高CPU线程和线程状态
- CPU热点：分析方法CPU使用情况
- 调用栈：分析方法调用链
- 方法跟踪：实时跟踪方法执行
- 系统仪表板：获取JVM整体状态
- 智能诊断建议：根据CPU使用率提供优化建议

## 故障排除

### 常见问题

#### 1. 无法获取线程转储
**症状**: 脚本提示"无法获取线程转储"
**解决方案**:
```bash
# 先诊断Java环境
./cpu_diagnosis.sh -d

# 使用sudo权限运行
sudo ./cpu_diagnosis.sh -p <PID>
```

#### 2. JVM工具不可用
**症状**: 提示"jstack工具不可用"
**解决方案**:
- 确保安装了JDK（不仅仅是JRE）
- 设置JAVA_HOME环境变量
- 检查PATH中是否包含JDK的bin目录

#### 3. 权限不足
**症状**: 提示"权限不足"
**解决方案**:
```bash
# 使用sudo运行
sudo ./cpu_diagnosis.sh -p <PID>
```

### macOS特定问题

#### 1. Java安装路径问题
macOS上Java可能安装在多个位置：
- `/Library/Java/JavaVirtualMachines/` (系统级)
- `~/Library/Java/JavaVirtualMachines/` (用户级)
- `/System/Library/Frameworks/JavaVM.framework/` (系统框架)

#### 2. 权限问题
macOS的安全机制可能阻止某些操作：
```bash
# 检查权限
./cpu_diagnosis.sh -d

# 使用sudo
sudo ./cpu_diagnosis.sh -p <PID>
```

#### 3. 超时处理
macOS默认不支持`timeout`命令，脚本使用自定义的超时函数：
- 自动检测并处理长时间运行的jstack命令
- 30秒超时保护，防止脚本卡死
- 支持优雅终止和强制终止
- 进程清理机制，确保不会有僵尸进程残留

### Linux特定问题

#### 1. 系统工具缺失
某些Linux发行版可能缺少必要工具：
```bash
# Ubuntu/Debian
sudo apt-get install procps

# CentOS/RHEL
sudo yum install procps-ng
```

#### 2. Java路径问题
Linux上Java通常安装在：
- `/usr/lib/jvm/`
- `/usr/java/`
- `~/.jvm/`

## 最佳实践

### 1. 定期监控
```bash
# 设置定时任务，定期检查
crontab -e
# 添加：*/5 * * * * /path/to/cpu_diagnosis.sh -a >> /var/log/java_cpu.log
```

### 2. Arthas最佳实践
```bash
# 生产环境推荐使用Arthas智能诊断
./cpu_diagnosis_arthas_advanced.sh -a

# 自定义Arthas命令配置
cp arthas_commands.conf custom.conf
# 编辑custom.conf，添加业务特定的分析方法
./cpu_diagnosis_arthas_advanced.sh -f custom.conf -p <PID>

# 定期清理Arthas分析文件
find /tmp -name "arthas_*" -mtime +7 -delete
```

### 3. 问题排查流程
1. 运行完整诊断：`./cpu_diagnosis.sh`
2. 识别高CPU进程
3. 分析特定进程：`./cpu_diagnosis.sh -p <PID>`
4. 查看线程转储文件
5. 根据分析结果优化代码

### 4. Arthas问题排查流程（推荐）
1. 使用Arthas智能诊断：`./cpu_diagnosis_arthas_advanced.sh -a`
2. 查看智能诊断报告，获取优化建议
3. 根据CPU使用率选择分析策略：
   - 紧急情况（≥80%）：快速获取关键信息
   - 高CPU（≥50%）：详细分析方法性能
   - 中等CPU（≥30%）：标准分析
   - 低CPU（<30%）：基础监控
4. 针对性优化：根据Arthas分析结果优化代码

### 5. 报告生成
```bash
# 生成诊断报告
./cpu_diagnosis.sh -g

# 报告位置
/tmp/java_cpu_diagnosis_report_YYYYMMDD_HHMMSS.txt

# Arthas智能诊断报告
# 报告位置：/tmp/arthas_intelligent_analysis_<PID>_YYYYMMDD_HHMMSS/
# 包含文件：
# - intelligent_diagnosis_report.txt  # 智能诊断报告
# - cpu_analysis.txt                  # CPU热点分析
# - thread_analysis.txt               # 线程分析
# - deadlock_detection.txt            # 死锁检测
# - stack_analysis.txt                # 调用栈分析
# - jvm_info.txt                      # JVM信息
```

## 注意事项

1. **权限要求**: 某些操作需要sudo权限
2. **Java版本**: 建议使用JDK 8或更高版本
3. **系统资源**: 脚本本身会消耗少量系统资源
4. **文件清理**: 线程转储文件会保存在/tmp目录，注意清理
5. **网络环境**: 某些功能可能需要网络连接
6. **超时保护**: macOS版本使用自定义超时函数，Linux版本使用系统timeout命令
7. **Arthas要求**: Arthas需要Java进程运行，且进程用户有足够权限
8. **配置文件**: Arthas命令配置文件支持自定义，可根据业务需求调整
9. **分析策略**: 智能诊断会根据CPU使用率自动选择分析策略，避免过度分析

## 版本历史

- **v3.0.0**: 集成Arthas支持，增加智能诊断功能
  - 新增Arthas基础版和智能增强版脚本
  - 支持配置文件自定义Arthas命令
  - 根据CPU使用率自动选择分析策略
  - 智能生成诊断建议
- **v2.0.0**: 拆分为macOS和Linux专用脚本，增加智能启动器
- **v1.0.0**: 初始版本，支持跨平台诊断

## 技术支持

如果遇到问题，请：
1. 先运行 `./cpu_diagnosis.sh -d` 诊断环境
2. 检查错误日志
3. 确认操作系统和Java版本兼容性
4. 尝试使用sudo权限运行

## 许可证

本脚本仅供学习和诊断使用，请遵守相关法律法规。 