#!/bin/bash

# Java CPU诊断脚本 - Linux专用版本
# 专门用于定位Java进程CPU突然飙升问题
# 作者: 开发者
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取Java进程信息 (Linux专用)
get_java_processes() {
    ps aux | grep java | grep -v grep
}

# 获取进程详细信息 (Linux专用)
get_process_info() {
    local pid=$1
    ps -p $pid -o pid,ppid,user,%cpu,%mem,comm,args --no-headers 2>/dev/null || echo "进程不存在"
}

# 获取线程信息 (Linux专用)
get_thread_info() {
    local pid=$1
    echo "线程信息 (Linux):"
    ps -T -p $pid --no-headers 2>/dev/null || echo "无法获取线程信息"
}

# 诊断Linux Java环境
diagnose_linux_java() {
    log_info "=== Linux Java环境诊断 ==="
    
    echo "1. 系统Java信息:"
    echo "   Linux发行版: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo '未知')"
    echo "   Java命令: $(which java 2>/dev/null || echo '未找到')"
    
    if command -v java &> /dev/null; then
        echo "   Java版本: $(java -version 2>&1 | head -1)"
        echo "   Java Home: $(java -XshowSettings:properties -version 2>&1 | grep "java.home" | awk '{print $3}' || echo '无法获取')"
    fi
    
    echo ""
    echo "2. 环境变量:"
    echo "   JAVA_HOME: ${JAVA_HOME:-'未设置'}"
    echo "   PATH中的Java: $(echo $PATH | tr ':' '\n' | grep -i java | head -3 | tr '\n' ' ' || echo '未找到')"
    
    echo ""
    echo "3. 系统Java安装:"
    if [[ -d "/usr/lib/jvm" ]]; then
        echo "   系统JDK目录:"
        ls -la /usr/lib/jvm/ 2>/dev/null | head -5 || echo "   无法访问"
    else
        echo "   系统JDK目录不存在"
    fi
    
    echo ""
    echo "4. 用户Java安装:"
    if [[ -d "$HOME/.jvm" ]]; then
        echo "   用户JDK目录:"
        ls -la "$HOME/.jvm/" 2>/dev/null | head -5 || echo "   无法访问"
    else
        echo "   用户JDK目录不存在"
    fi
    
    echo ""
    echo "5. JVM工具可用性:"
    local tools=("jstack" "jstat" "jmap" "jps")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo "   $tool: $(which $tool)"
        else
            echo "   $tool: 不可用"
        fi
    done
    
    echo ""
    echo "6. 权限检查:"
    echo "   当前用户: $(whoami)"
    echo "   用户组: $(groups)"
    echo "   sudo权限: $(sudo -n true 2>/dev/null && echo '可用' || echo '需要密码')"
    
    echo ""
}

# 获取系统基本信息 (Linux专用)
get_system_info() {
    log_info "=== 系统基本信息 ==="
    echo "系统版本: $(uname -a)"
    echo "操作系统: Linux"
    echo "CPU核心数: $(nproc 2>/dev/null || echo '未知')"
    echo "内存信息: $(free -h 2>/dev/null | grep Mem || echo '未知')"
    echo "负载情况: $(uptime)"
    echo "当前时间: $(date)"
    echo ""
    
    # Linux Java环境诊断
    diagnose_linux_java
}

# 查找Java进程
find_java_processes() {
    log_info "=== Java进程信息 ==="
    
    local java_processes=$(get_java_processes)
    
    if [[ -z "$java_processes" ]]; then
        log_warn "未找到Java进程"
        return
    fi
    
    echo "找到的Java进程:"
    echo "$java_processes"
    echo ""
    
    # 提取进程ID并显示详细信息
    local java_pids=$(echo "$java_processes" | awk '{print $2}')
    
    for pid in $java_pids; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
            log_info "进程 $pid 详细信息:"
            get_process_info $pid
            echo ""
        fi
    done
}

# 分析高CPU Java进程 (Linux专用)
analyze_high_cpu_java() {
    log_info "=== 高CPU Java进程分析 ==="
    
    local high_cpu_java=$(ps aux | grep java | grep -v grep | awk '$3 > 50.0 {print $0}')
    
    if [[ -z "$high_cpu_java" ]]; then
        log_info "当前没有CPU使用率超过50%的Java进程"
        return
    fi
    
    echo "CPU使用率超过50%的Java进程:"
    echo "$high_cpu_java"
    echo ""
    
    # 分析每个高CPU Java进程
    local high_cpu_pids=$(echo "$high_cpu_java" | awk '{print $2}')
    
    for pid in $high_cpu_pids; do
        if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
            analyze_java_process $pid
        fi
    done
}

# 分析Java进程
analyze_java_process() {
    local pid=$1
    
    log_info "=== 分析Java进程 $pid ==="
    
    # 进程基本信息
    echo "进程详细信息:"
    get_process_info $pid
    echo ""
    
    # 线程信息
    log_info "线程信息:"
    get_thread_info $pid
    echo ""
    
    # JVM工具分析
    analyze_java_tools $pid
}

# 查找Java Home路径 (Linux专用)
find_java_home() {
    echo "$JAVA_HOME"
}

# 获取JVM工具路径 (Linux专用)
get_jvm_tool_path() {
    local tool_name=$1
    
    # 首先尝试直接使用命令
    if command -v "$tool_name" &> /dev/null; then
        echo "$tool_name"
        return
    fi
    
    # 查找Java Home
    local java_home=$(find_java_home)
    if [[ -n "$java_home" ]]; then
        local tool_path="$java_home/bin/$tool_name"
        if [[ -f "$tool_path" ]]; then
            echo "$tool_path"
            return
        fi
    fi
    
    # 查找系统安装的JDK
    local system_tool=$(find /usr/lib/jvm -name "$tool_name" -type f 2>/dev/null | head -1)
    if [[ -n "$system_tool" ]]; then
        echo "$system_tool"
        return
    fi
    
    # 查找用户安装的JDK
    local user_tool=$(find ~/.jvm -name "$tool_name" -type f 2>/dev/null | head -1)
    if [[ -n "$user_tool" ]]; then
        echo "$user_tool"
        return
    fi
    
    echo ""
}

# 使用JVM工具分析
analyze_java_tools() {
    local pid=$1
    
    log_info "=== JVM工具分析 ==="
    
    # 获取jstack路径
    local jstack_path=$(get_jvm_tool_path "jstack")
    if [[ -z "$jstack_path" ]]; then
        log_warn "jstack工具不可用，尝试查找Java安装..."
        
        # 显示Java相关信息
        log_info "Java环境信息:"
        echo "JAVA_HOME: ${JAVA_HOME:-'未设置'}"
        echo "java命令: $(which java 2>/dev/null || echo '未找到')"
        
        if command -v java &> /dev/null; then
            echo "Java版本: $(java -version 2>&1 | head -1)"
        fi
        
        log_info "查找Linux上的Java安装:"
        if [[ -d "/usr/lib/jvm" ]]; then
            echo "系统JDK:"
            ls -la /usr/lib/jvm/ 2>/dev/null || echo "无法访问系统JDK目录"
        fi
        
        if [[ -d "$HOME/.jvm" ]]; then
            echo "用户JDK:"
            ls -la "$HOME/.jvm/" 2>/dev/null || echo "无法访问用户JDK目录"
        fi
        
        log_warn "跳过Java线程分析"
        return
    fi
    
    log_info "使用jstack路径: $jstack_path"
    
    # 检查进程是否存在
    if ! ps -p $pid > /dev/null 2>&1; then
        log_error "进程 $pid 不存在"
        return
    fi
    
    # 获取线程转储
    log_info "获取线程转储..."
    
    # 创建thread目录（如果不存在）
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local thread_dir="${script_dir}/thread"
    mkdir -p "$thread_dir"
    
    local thread_dump_file="${thread_dir}/thread_dump_${pid}_$(date +%Y%m%d_%H%M%S).txt"
    
    # 尝试多种方式获取线程转储
    local dump_success=false
    
    # 方式1: 直接使用jstack
    log_info "尝试方式1: 直接使用jstack..."
    local cmd1="timeout 30 \"$jstack_path\" $pid > \"$thread_dump_file\" 2>/dev/null"
    log_info "执行命令: $cmd1"
    if timeout 30 "$jstack_path" $pid > "$thread_dump_file" 2>/dev/null; then
        if [[ -s "$thread_dump_file" ]]; then
            dump_success=true
            log_info "线程转储成功 (方式1)"
        fi
    fi
    
    if [[ "$dump_success" == "true" ]]; then
        log_info "线程转储已保存到: $thread_dump_file"
        
        # 分析线程状态
        log_info "线程状态统计:"
        grep -E "java\.lang\.Thread\.State:" "$thread_dump_file" | sort | uniq -c | sort -nr 2>/dev/null || echo "无法分析线程状态"
        
        # 查找可能的死锁
        log_info "检查死锁:"
        if grep -q "Found deadlock" "$thread_dump_file"; then
            log_error "发现死锁!"
            grep -A 20 "Found deadlock" "$thread_dump_file"
        else
            log_info "未发现死锁"
        fi
        
        # 查找CPU密集型线程
        log_info "CPU密集型线程 (RUNNABLE状态):"
        grep -B 5 -A 5 "java\.lang\.Thread\.State: RUNNABLE" "$thread_dump_file" | head -20 2>/dev/null || echo "无法获取RUNNABLE线程"
        
        # 显示线程转储文件大小
        log_info "线程转储文件大小: $(ls -lh "$thread_dump_file" | awk '{print $5}')"
        
    else
        log_error "无法获取线程转储，已尝试4种方式"
        log_error "可能的原因:"
        log_error "1. 进程不存在或已终止"
        log_error "2. 权限不足 (尝试使用sudo运行脚本)"
        log_error "3. Java版本不兼容"
        log_error "4. 进程不是Java进程"
        
        # 显示进程详细信息
        log_info "进程详细信息:"
        ps -p $pid -o pid,ppid,user,%cpu,%mem,comm,args --no-headers 2>/dev/null || echo "无法获取进程信息"
    fi
    
    echo ""
    
    # JVM内存信息
    local jstat_path=$(get_jvm_tool_path "jstat")
    if [[ -n "$jstat_path" ]]; then
        log_info "JVM内存使用情况:"
        "$jstat_path" -gc $pid 2>/dev/null || log_warn "无法获取JVM内存信息"
        echo ""
    else
        log_warn "jstat工具不可用，跳过内存分析"
    fi
}

# 实时监控Java进程 (Linux专用)
realtime_monitor() {
    log_info "=== Java进程实时监控 ==="
    log_info "按Ctrl+C停止监控"
    echo ""
    
    while true; do
        clear
        echo "=== Java进程实时监控 - $(date) ==="
        echo ""
        
        # 系统负载
        echo "系统负载: $(uptime)"
        echo ""
        
        # Java进程CPU使用率
        echo "Java进程CPU使用率:"
        get_java_processes | head -10
        echo ""
        
        # 高CPU Java进程
        echo "高CPU Java进程 (>30%):"
        ps aux | grep java | grep -v grep | awk '$3 > 30.0 {print $0}' | head -5
        echo ""
        
        sleep 3
    done
}

# 生成诊断报告 (Linux专用)
generate_report() {
    # 创建报告目录（如果不存在）
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local report_dir="${script_dir}/reports"
    mkdir -p "$report_dir"
    
    local report_file="${report_dir}/java_cpu_diagnosis_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "=== 生成Java CPU诊断报告 ==="
    log_info "报告文件: $report_file"
    
    {
        echo "Java CPU诊断报告 (Linux)"
        echo "生成时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "========================================"
        echo ""
        
        echo "1. 系统基本信息:"
        get_system_info
        
        echo "2. Java进程信息:"
        get_java_processes
        
        echo ""
        echo "3. 高CPU Java进程:"
        ps aux | grep java | grep -v grep | awk '$3 > 30.0 {print $0}'
        
        echo ""
        echo "4. 系统负载:"
        uptime
        
    } > "$report_file"
    
    log_info "诊断报告已生成: $report_file"
}

# 帮助信息
show_help() {
    echo "Java CPU诊断脚本使用方法 (Linux专用):"
    echo ""
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -r, --realtime      实时监控Java进程"
    echo "  -a, --analyze       分析高CPU Java进程"
    echo "  -p, --pid PID       分析指定Java进程ID"
    echo "  -s, --system        系统基本信息"
    echo "  -g, --generate      生成诊断报告"
    echo "  -d, --diagnose      诊断Java环境"
    echo ""
    echo "示例:"
    echo "  $0                    # 完整诊断"
    echo "  $0 -r                 # 实时监控"
    echo "  $0 -p 1234            # 分析Java进程1234"
    echo "  $0 -a                 # 分析高CPU Java进程"
    echo "  $0 -d                 # 诊断Java环境"
    echo ""
    echo "Linux使用建议:"
    echo "  1. 如果无法获取线程转储，请先运行: $0 -d"
    echo "  2. 确保已安装JDK (不仅仅是JRE)"
    echo "  3. 设置JAVA_HOME环境变量"
    echo "  4. 使用sudo运行脚本: sudo $0 -p PID"
    echo ""
}

# 主函数
main() {
    local mode="all"
    local target_pid=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--realtime)
                mode="realtime"
                shift
                ;;
            -a|--analyze)
                mode="analyze"
                shift
                ;;
            -p|--pid)
                target_pid="$2"
                mode="process"
                shift 2
                ;;
            -s|--system)
                mode="system"
                shift
                ;;
            -g|--generate)
                mode="generate"
                shift
                ;;
            -d|--diagnose)
                mode="diagnose"
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 根据模式执行相应操作
    case $mode in
        "realtime")
            realtime_monitor
            ;;
        "analyze")
            get_system_info
            find_java_processes
            analyze_high_cpu_java
            ;;
        "process")
            if [[ -n "$target_pid" ]]; then
                get_system_info
                analyze_java_process $target_pid
            else
                log_error "请指定Java进程ID"
                exit 1
            fi
            ;;
        "system")
            get_system_info
            ;;
        "generate")
            get_system_info
            find_java_processes
            analyze_high_cpu_java
            generate_report
            ;;
        "diagnose")
            diagnose_linux_java
            ;;
        "all")
            get_system_info
            find_java_processes
            analyze_high_cpu_java
            generate_report
            ;;
    esac
    
    log_info "诊断完成"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 