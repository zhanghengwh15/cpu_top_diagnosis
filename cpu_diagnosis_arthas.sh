#!/bin/bash

# Java CPU诊断脚本 - Arthas增强版
# 利用Arthas工具进行深度Java进程诊断
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

# macOS兼容的超时函数
timeout_macos() {
    local timeout_seconds=$1
    shift
    
    # 启动后台进程
    "$@" &
    local pid=$!
    
    # 等待指定时间
    sleep $timeout_seconds
    
    # 检查进程是否还在运行
    if kill -0 $pid 2>/dev/null; then
        # 进程还在运行，终止它
        kill -TERM $pid 2>/dev/null
        sleep 1
        # 如果还在运行，强制终止
        if kill -0 $pid 2>/dev/null; then
            kill -KILL $pid 2>/dev/null
        fi
        return 1
    else
        # 进程已经结束
        wait $pid
        return $?
    fi
}

# 获取超时函数（根据操作系统选择）
get_timeout_cmd() {
    local os=$(detect_os)
    if [[ "$os" == "macos" ]]; then
        echo "timeout_macos"
    else
        echo "timeout"
    fi
}

# 检查Arthas是否可用
check_arthas() {
    log_info "=== 检查Arthas可用性 ==="
    # 检查arthas-boot.jar是否存在
    local arthas_paths=(
           "./arthas-boot.jar"
        "/opt/arthas/arthas-boot.jar"
        "/usr/local/arthas/arthas-boot.jar"
        "$HOME/.arthas/arthas-boot.jar"
        "/tmp/arthas/arthas-boot.jar"
    )
    
    local arthas_found=""
    for path in "${arthas_paths[@]}"; do
        if [[ -f "$path" ]]; then
            arthas_found="$path"
            log_info "找到Arthas: $path"
            break
        fi
    done
    
    if [[ -z "$arthas_found" ]]; then
        log_warn "未找到Arthas，尝试下载..."
        download_arthas
        if [[ -f "./arthas-boot.jar" ]]; then
            arthas_found="./arthas-boot.jar"
            log_info "Arthas下载成功"
        else
            log_error "Arthas下载失败"
            return 1
        fi
    fi
    
    echo "$arthas_found"
}

# 下载Arthas
download_arthas() {
    log_info "下载Arthas..."
    
    # 创建临时目录
    mkdir -p /tmp/arthas_download
    
    # 下载Arthas
    local download_url="https://arthas.aliyun.com/arthas-boot.jar"
    
    if command -v curl &> /dev/null; then
        curl -L -o /tmp/arthas_download/arthas-boot.jar "$download_url" 2>/dev/null
    elif command -v wget &> /dev/null; then
        wget -O /tmp/arthas_download/arthas-boot.jar "$download_url" 2>/dev/null
    else
        log_error "未找到curl或wget，无法下载Arthas"
        return 1
    fi
    
    if [[ -f "/tmp/arthas_download/arthas-boot.jar" ]]; then
        cp /tmp/arthas_download/arthas-boot.jar ./arthas-boot.jar
        rm -rf /tmp/arthas_download
        log_info "Arthas下载完成"
    else
        log_error "Arthas下载失败"
        return 1
    fi
}

# 使用Arthas分析Java进程
analyze_with_arthas() {
    local pid=$1
    local arthas_path=$2
    
    log_info "=== 使用Arthas分析Java进程 $pid ==="
    
    # 检查进程是否存在
    if ! ps -p $pid > /dev/null 2>&1; then
        log_error "进程 $pid 不存在"
        return 1
    fi
    
    # 创建Arthas输出目录
    local output_dir="../logs/arthas_analysis_${pid}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    
    log_info "Arthas分析结果将保存到: $output_dir"
    
    # 1. 使用thread命令分析线程
    analyze_threads_with_arthas "$pid" "$arthas_path" "$output_dir"
    
    # 2. 使用cpu命令分析CPU使用情况
    analyze_cpu_with_arthas "$pid" "$arthas_path" "$output_dir"
    
    # 3. 使用stack命令分析方法调用栈
    analyze_stack_with_arthas "$pid" "$arthas_path" "$output_dir"
    
    # 4. 使用trace命令跟踪方法执行
    analyze_trace_with_arthas "$pid" "$arthas_path" "$output_dir"
    
    # 5. 使用dashboard命令获取整体概览
    analyze_dashboard_with_arthas "$pid" "$arthas_path" "$output_dir"
    
    log_info "Arthas分析完成，结果保存在: $output_dir"
    echo "$output_dir"
}

# 使用Arthas分析线程
analyze_threads_with_arthas() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "分析线程信息..."
    
    local timeout_cmd=$(get_timeout_cmd)
    local thread_file="$output_dir/thread_analysis.txt"
    
    # 使用thread命令获取线程信息
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos 30 java -jar "$arthas_path" "$pid" -c "thread -n 20" > "$thread_file" 2>/dev/null
    else
        timeout 30 java -jar "$arthas_path" "$pid" -c "thread -n 20" > "$thread_file" 2>/dev/null
    fi
    
    if [[ -s "$thread_file" ]]; then
        log_info "线程分析完成: $thread_file"
        
        # 显示高CPU线程
        log_info "高CPU线程 (前10个):"
        grep -A 5 "cpu-usage" "$thread_file" | head -20 2>/dev/null || echo "无法获取CPU使用信息"
    else
        log_warn "线程分析失败"
    fi
}

# 使用Arthas分析CPU
analyze_cpu_with_arthas() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "分析CPU使用情况..."
    
    local timeout_cmd=$(get_timeout_cmd)
    local cpu_file="$output_dir/cpu_analysis.txt"
    
    # 使用cpu命令分析CPU使用情况
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos 30 java -jar "$arthas_path" "$pid" -c "cpu -i 10000 -n 10" > "$cpu_file" 2>/dev/null
    else
        timeout 30 java -jar "$arthas_path" "$pid" -c "cpu -i 10000 -n 10" > "$cpu_file" 2>/dev/null
    fi
    
    if [[ -s "$cpu_file" ]]; then
        log_info "CPU分析完成: $cpu_file"
        
        # 显示CPU热点方法
        log_info "CPU热点方法:"
        grep -A 10 "cpu-usage" "$cpu_file" | head -15 2>/dev/null || echo "无法获取CPU热点信息"
    else
        log_warn "CPU分析失败"
    fi
}

# 使用Arthas分析方法调用栈
analyze_stack_with_arthas() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "分析方法调用栈..."
    
    local timeout_cmd=$(get_timeout_cmd)
    local stack_file="$output_dir/stack_analysis.txt"
    
    # 使用stack命令分析方法调用栈
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos 30 java -jar "$arthas_path" "$pid" -c "stack java.lang.Thread run" > "$stack_file" 2>/dev/null
    else
        timeout 30 java -jar "$arthas_path" "$pid" -c "stack java.lang.Thread run" > "$stack_file" 2>/dev/null
    fi
    
    if [[ -s "$stack_file" ]]; then
        log_info "调用栈分析完成: $stack_file"
    else
        log_warn "调用栈分析失败"
    fi
}

# 使用Arthas跟踪方法执行
analyze_trace_with_arthas() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "跟踪方法执行..."
    
    local timeout_cmd=$(get_timeout_cmd)
    local trace_file="$output_dir/trace_analysis.txt"
    
    # 使用trace命令跟踪方法执行（这里以常见的CPU密集型方法为例）
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos 20 java -jar "$arthas_path" "$pid" -c "trace java.lang.String * -E" > "$trace_file" 2>/dev/null
    else
        timeout 20 java -jar "$arthas_path" "$pid" -c "trace java.lang.String * -E" > "$trace_file" 2>/dev/null
    fi
    
    if [[ -s "$trace_file" ]]; then
        log_info "方法跟踪完成: $trace_file"
    else
        log_warn "方法跟踪失败"
    fi
}

# 使用Arthas获取仪表板信息
analyze_dashboard_with_arthas() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "获取系统仪表板信息..."
    
    local timeout_cmd=$(get_timeout_cmd)
    local dashboard_file="$output_dir/dashboard.txt"
    
    # 使用dashboard命令获取系统概览
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos 15 java -jar "$arthas_path" "$pid" -c "dashboard" > "$dashboard_file" 2>/dev/null
    else
        timeout 15 java -jar "$arthas_path" "$pid" -c "dashboard" > "$dashboard_file" 2>/dev/null
    fi
    
    if [[ -s "$dashboard_file" ]]; then
        log_info "仪表板信息获取完成: $dashboard_file"
        
        # 显示关键信息
        log_info "系统概览:"
        head -20 "$dashboard_file" 2>/dev/null || echo "无法获取系统概览"
    else
        log_warn "仪表板信息获取失败"
    fi
}

# 生成Arthas诊断报告
generate_arthas_report() {
    local output_dir=$1
    local report_file="$output_dir/arthas_diagnosis_report.txt"
    
    log_info "生成Arthas诊断报告..."
    
    {
        echo "Arthas Java CPU诊断报告"
        echo "生成时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "========================================"
        echo ""
        
        echo "1. 线程分析结果:"
        if [[ -f "$output_dir/thread_analysis.txt" ]]; then
            cat "$output_dir/thread_analysis.txt"
        else
            echo "线程分析文件不存在"
        fi
        
        echo ""
        echo "2. CPU热点分析结果:"
        if [[ -f "$output_dir/cpu_analysis.txt" ]]; then
            cat "$output_dir/cpu_analysis.txt"
        else
            echo "CPU分析文件不存在"
        fi
        
        echo ""
        echo "3. 方法调用栈分析:"
        if [[ -f "$output_dir/stack_analysis.txt" ]]; then
            cat "$output_dir/stack_analysis.txt"
        else
            echo "调用栈分析文件不存在"
        fi
        
        echo ""
        echo "4. 系统仪表板信息:"
        if [[ -f "$output_dir/dashboard.txt" ]]; then
            cat "$output_dir/dashboard.txt"
        else
            echo "仪表板信息文件不存在"
        fi
        
    } > "$report_file"
    
    log_info "Arthas诊断报告已生成: $report_file"
}

# 获取Java进程信息
get_java_processes() {
    ps aux | grep java | grep -v grep
}

# 分析高CPU Java进程
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
            analyze_java_process_with_arthas $pid
        fi
    done
}

# 分析Java进程（使用Arthas）
analyze_java_process_with_arthas() {
    local pid=$1
    
    log_info "=== 使用Arthas分析Java进程 $pid ==="
    
    # 检查Arthas可用性
    local arthas_path=$(check_arthas)
    if [[ -z "$arthas_path" ]]; then
        log_error "Arthas不可用，跳过分析"
        return 1
    fi
    
    # 使用Arthas分析
    local output_dir=$(analyze_with_arthas "$pid" "$arthas_path")
    
    if [[ -n "$output_dir" ]]; then
        # 生成报告
        generate_arthas_report "$output_dir"
        
        log_info "分析完成，请查看以下文件:"
        echo "  - 线程分析: $output_dir/thread_analysis.txt"
        echo "  - CPU分析: $output_dir/cpu_analysis.txt"
        echo "  - 调用栈分析: $output_dir/stack_analysis.txt"
        echo "  - 方法跟踪: $output_dir/trace_analysis.txt"
        echo "  - 仪表板信息: $output_dir/dashboard.txt"
        echo "  - 诊断报告: $output_dir/arthas_diagnosis_report.txt"
    fi
}

# 帮助信息
show_help() {
    echo "Java CPU诊断脚本 - Arthas增强版"
    echo ""
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -a, --analyze       分析高CPU Java进程"
    echo "  -p, --pid PID       分析指定Java进程ID"
    echo "  -c, --check         检查Arthas可用性"
    echo "  -d, --download      下载Arthas"
    echo ""
    echo "示例:"
    echo "  $0 -a                 # 分析高CPU Java进程"
    echo "  $0 -p 1234            # 分析Java进程1234"
    echo "  $0 -c                 # 检查Arthas"
    echo "  $0 -d                 # 下载Arthas"
    echo ""
    echo "Arthas功能:"
    echo "  - 线程分析: 识别高CPU线程"
    echo "  - CPU热点: 分析方法CPU使用情况"
    echo "  - 调用栈: 分析方法调用链"
    echo "  - 方法跟踪: 实时跟踪方法执行"
    echo "  - 系统仪表板: 获取JVM整体状态"
    echo ""
}

# 主函数
main() {
    local mode="analyze"
    local target_pid=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
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
            -c|--check)
                mode="check"
                shift
                ;;
            -d|--download)
                mode="download"
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
        "analyze")
            analyze_high_cpu_java
            ;;
        "process")
            if [[ -n "$target_pid" ]]; then
                analyze_java_process_with_arthas $target_pid
            else
                log_error "请指定Java进程ID"
                exit 1
            fi
            ;;
        "check")
            check_arthas
            ;;
        "download")
            download_arthas
            ;;
    esac
    
    log_info "诊断完成"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 