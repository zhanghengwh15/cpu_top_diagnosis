#!/bin/bash

# 快速Java CPU检查脚本 - 紧急情况使用
# 作者: 开发者
# 版本: 1.0.0

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

echo "=== 快速Java CPU检查 - $(date) ==="
echo ""

# 1. 系统负载
echo "1. 系统负载:"
uptime
echo ""

# 2. Java进程CPU使用率
echo "2. Java进程CPU使用率:"
java_processes=$(ps aux | grep java | grep -v grep)
if [[ -n "$java_processes" ]]; then
    echo "$java_processes"
else
    echo "未找到Java进程"
fi
echo ""

# 3. 高CPU Java进程 (>30%)
echo "3. 高CPU Java进程 (>30%):"
high_cpu_java=$(ps aux | grep java | grep -v grep | awk '$3 > 30.0 {print $0}')
if [[ -n "$high_cpu_java" ]]; then
    echo "$high_cpu_java"
else
    echo "没有高CPU Java进程"
fi
echo ""

# 4. 内存使用情况
echo "4. 内存使用情况:"
os=$(detect_os)
if [[ "$os" == "macos" ]]; then
    vm_stat | head -5
else
    free -h
fi
echo ""

# 5. Java进程数量
echo "5. Java进程统计:"
java_count=$(ps aux | grep java | grep -v grep | wc -l)
echo "Java进程数量: $java_count"
echo ""

# 6. 系统信息
echo "6. 系统信息:"
echo "操作系统: $(detect_os)"
echo "CPU核心数: $(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo '未知')"
echo ""

echo "=== 检查完成 ===" 