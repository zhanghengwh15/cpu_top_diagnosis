#!/bin/bash

# Java CPU诊断脚本 - Arthas增强版（支持配置文件）
# 利用Arthas工具进行深度Java进程诊断
# 作者: 开发者
# 版本: 2.0.0

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

# 配置文件路径
CONFIG_FILE="arthas_commands.conf"

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

# 读取配置文件
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 使用临时文件存储配置
    local temp_file="/tmp/arthas_config_$$"
    
    # 解析配置文件并存储到临时文件
    local current_section=""
    
    while IFS= read -r line; do
        # 跳过注释和空行
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # 检查是否是节标题
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # 解析键值对
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            if [[ "$current_section" == "timeout" ]]; then
                echo "TIMEOUT_${key}=${value}" >> "$temp_file"
            else
                echo "CMD_${current_section}_${key}=${value}" >> "$temp_file"
            fi
        fi
    done < "$CONFIG_FILE"
    
    # 导出配置变量
    if [[ -f "$temp_file" ]]; then
        source "$temp_file"
        rm -f "$temp_file"
    fi
}

# 获取配置的命令
get_config_command() {
    local section=$1
    local key=$2
    local var_name="CMD_${section}_${key}"
    eval "echo \$$var_name"
}

# 获取配置的超时时间
get_config_timeout() {
    local section=$1
    local var_name="TIMEOUT_${section}"
    local timeout=$(eval "echo \$$var_name")
    echo "${timeout:-30}"
}

# 检查Arthas是否可用
check_arthas() {
    log_info "=== 检查Arthas可用性 ==="
    
    # 检查arthas-boot.jar是否存在
    local arthas_paths=(
        "/opt/arthas/arthas-boot.jar"
        "/usr/local/arthas/arthas-boot.jar"
        "$HOME/.arthas/arthas-boot.jar"
        "./arthas-boot.jar"
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

# 执行Arthas命令
execute_arthas_command() {
    local pid=$1
    local arthas_path=$2
    local command=$3
    local output_file=$4
    local timeout_seconds=${5:-30}
    
    log_info "执行Arthas命令: $command"
    
    local timeout_cmd=$(get_timeout_cmd)
    
    if [[ "$timeout_cmd" == "timeout_macos" ]]; then
        timeout_macos "$timeout_seconds" java -jar "$arthas_path" "$pid" -c "$command" > "$output_file" 2>/dev/null
    else
        timeout "$timeout_seconds" java -jar "$arthas_path" "$pid" -c "$command" > "$output_file" 2>/dev/null
    fi
    
    if [[ -s "$output_file" ]]; then
        log_info "命令执行成功: $output_file"
        return 0
    else
        log_warn "命令执行失败或无输出"
        return 1
    fi
}

# 智能分析CPU问题
analyze_cpu_problem_intelligently() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    
    log_info "=== 智能分析CPU问题 ==="
    
    # 1. 基础系统信息
    log_info "1. 获取系统基础信息..."
    local dashboard_cmd=$(get_config_command "system_monitor" "dashboard")
    local dashboard_timeout=$(get_config_timeout "system_monitor")
    if [[ -n "$dashboard_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$dashboard_cmd" "$output_dir/dashboard.txt" "$dashboard_timeout"
    else
        log_warn "未找到dashboard命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "dashboard" "$output_dir/dashboard.txt" "$dashboard_timeout"
    fi
    
    # 2. 线程分析
    log_info "2. 分析线程状态..."
    local thread_cmd=$(get_config_command "thread_analysis" "thread_all")
    local thread_timeout=$(get_config_timeout "thread_analysis")
    if [[ -n "$thread_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$thread_cmd" "$output_dir/thread_analysis.txt" "$thread_timeout"
    else
        log_warn "未找到thread命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "thread -n 20" "$output_dir/thread_analysis.txt" "$thread_timeout"
    fi
    
    # 3. CPU热点分析
    log_info "3. 分析CPU热点..."
    local cpu_cmd=$(get_config_command "cpu_analysis" "cpu_hotspot")
    local cpu_timeout=$(get_config_timeout "cpu_analysis")
    if [[ -n "$cpu_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$cpu_cmd" "$output_dir/cpu_analysis.txt" "$cpu_timeout"
    else
        log_warn "未找到cpu命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "cpu -i 10000 -n 10" "$output_dir/cpu_analysis.txt" "$cpu_timeout"
    fi
    
    # 4. 死锁检测
    log_info "4. 检测死锁..."
    local deadlock_cmd=$(get_config_command "deadlock_detection" "deadlock")
    local deadlock_timeout=$(get_config_timeout "deadlock_detection")
    if [[ -n "$deadlock_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$deadlock_cmd" "$output_dir/deadlock_detection.txt" "$deadlock_timeout"
    else
        log_warn "未找到deadlock命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "thread -b" "$output_dir/deadlock_detection.txt" "$deadlock_timeout"
    fi
    
    # 5. 方法调用栈分析
    log_info "5. 分析方法调用栈..."
    local stack_cmd=$(get_config_command "stack_analysis" "stack_thread")
    local stack_timeout=$(get_config_timeout "stack_analysis")
    if [[ -n "$stack_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$stack_cmd" "$output_dir/stack_analysis.txt" "$stack_timeout"
    else
        log_warn "未找到stack命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "stack java.lang.Thread run" "$output_dir/stack_analysis.txt" "$stack_timeout"
    fi
    
    # 6. JVM信息
    log_info "6. 获取JVM信息..."
    local jvm_cmd=$(get_config_command "system_monitor" "jvm")
    local jvm_timeout=$(get_config_timeout "system_monitor")
    if [[ -n "$jvm_cmd" ]]; then
        execute_arthas_command "$pid" "$arthas_path" "$jvm_cmd" "$output_dir/jvm_info.txt" "$jvm_timeout"
    else
        log_warn "未找到jvm命令配置，使用默认命令"
        execute_arthas_command "$pid" "$arthas_path" "jvm" "$output_dir/jvm_info.txt" "$jvm_timeout"
    fi
}

# 根据CPU使用率选择分析策略
select_analysis_strategy() {
    local cpu_usage=$1
    
    if [[ $(echo "$cpu_usage >= 80" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
        echo "critical"
    elif [[ $(echo "$cpu_usage >= 50" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
        echo "high"
    elif [[ $(echo "$cpu_usage >= 30" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
        echo "medium"
    else
        echo "low"
    fi
}

# 执行针对性分析
execute_targeted_analysis() {
    local pid=$1
    local arthas_path=$2
    local output_dir=$3
    local strategy=$4
    
    log_info "=== 执行针对性分析 (策略: $strategy) ==="
    
    case $strategy in
        "critical")
            # 紧急情况：快速获取关键信息
            log_info "执行紧急分析..."
            
            # 快速CPU分析
            local cpu_cmd=$(get_config_command "cpu_analysis" "cpu_hotspot")
            execute_arthas_command "$pid" "$arthas_path" "$cpu_cmd" "$output_dir/cpu_critical.txt" 30
            
            # 死锁检测
            local deadlock_cmd=$(get_config_command "deadlock_detection" "deadlock")
            execute_arthas_command "$pid" "$arthas_path" "$deadlock_cmd" "$output_dir/deadlock_critical.txt" 20
            
            # 线程状态
            local thread_cmd=$(get_config_command "thread_analysis" "thread_stat")
            execute_arthas_command "$pid" "$arthas_path" "$thread_cmd" "$output_dir/thread_critical.txt" 15
            ;;
            
        "high")
            # 高CPU：详细分析
            log_info "执行详细分析..."
            
            # 完整CPU分析
            local cpu_cmd=$(get_config_command "cpu_analysis" "cpu_hotspot_extended")
            execute_arthas_command "$pid" "$arthas_path" "$cpu_cmd" "$output_dir/cpu_detailed.txt" 60
            
            # 方法跟踪
            local trace_cmd=$(get_config_command "trace_analysis" "trace_method_with_exception")
            execute_arthas_command "$pid" "$arthas_path" "$trace_cmd" "$output_dir/trace_analysis.txt" 30
            
            # 性能监控
            local monitor_cmd=$(get_config_command "performance_analysis" "monitor")
            execute_arthas_command "$pid" "$arthas_path" "$monitor_cmd" "$output_dir/performance_monitor.txt" 45
            ;;
            
        "medium")
            # 中等CPU：标准分析
            log_info "执行标准分析..."
            
            # 标准CPU分析
            local cpu_cmd=$(get_config_command "cpu_analysis" "cpu_hotspot")
            execute_arthas_command "$pid" "$arthas_path" "$cpu_cmd" "$output_dir/cpu_standard.txt" 30
            
            # 调用栈分析
            local stack_cmd=$(get_config_command "stack_analysis" "stack_method")
            execute_arthas_command "$pid" "$arthas_path" "$stack_cmd" "$output_dir/stack_standard.txt" 30
            ;;
            
        "low")
            # 低CPU：基础分析
            log_info "执行基础分析..."
            
            # 基础信息收集
            local dashboard_cmd=$(get_config_command "system_monitor" "dashboard")
            execute_arthas_command "$pid" "$arthas_path" "$dashboard_cmd" "$output_dir/dashboard_basic.txt" 15
            
            # 线程概览
            local thread_cmd=$(get_config_command "thread_analysis" "thread_all")
            execute_arthas_command "$pid" "$arthas_path" "$thread_cmd" "$output_dir/thread_basic.txt" 20
            ;;
    esac
}

# 生成智能诊断报告
generate_intelligent_report() {
    local output_dir=$1
    local pid=$2
    local strategy=$3
    local report_file="$output_dir/intelligent_diagnosis_report.txt"
    
    log_info "生成智能诊断报告..."
    
    {
        echo "Arthas智能Java CPU诊断报告"
        echo "生成时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "分析策略: $strategy"
        echo "目标进程: $pid"
        echo "========================================"
        echo ""
        
        echo "1. 系统概览:"
        if [[ -f "$output_dir/dashboard.txt" ]]; then
            head -30 "$output_dir/dashboard.txt"
        else
            echo "系统概览信息不可用"
        fi
        
        echo ""
        echo "2. CPU热点分析:"
        if [[ -f "$output_dir/cpu_analysis.txt" ]]; then
            head -20 "$output_dir/cpu_analysis.txt"
        else
            echo "CPU分析信息不可用"
        fi
        
        echo ""
        echo "3. 线程状态分析:"
        if [[ -f "$output_dir/thread_analysis.txt" ]]; then
            head -20 "$output_dir/thread_analysis.txt"
        else
            echo "线程分析信息不可用"
        fi
        
        echo ""
        echo "4. 死锁检测结果:"
        if [[ -f "$output_dir/deadlock_detection.txt" ]]; then
            head -15 "$output_dir/deadlock_detection.txt"
        else
            echo "死锁检测信息不可用"
        fi
        
        echo ""
        echo "5. 方法调用栈:"
        if [[ -f "$output_dir/stack_analysis.txt" ]]; then
            head -15 "$output_dir/stack_analysis.txt"
        else
            echo "调用栈信息不可用"
        fi
        
        echo ""
        echo "6. JVM信息:"
        if [[ -f "$output_dir/jvm_info.txt" ]]; then
            head -20 "$output_dir/jvm_info.txt"
        else
            echo "JVM信息不可用"
        fi
        
        echo ""
        echo "7. 问题诊断建议:"
        generate_diagnosis_suggestions "$output_dir" "$strategy"
        
    } > "$report_file"
    
    log_info "智能诊断报告已生成: $report_file"
}

# 生成诊断建议
generate_diagnosis_suggestions() {
    local output_dir=$1
    local strategy=$2
    
    case $strategy in
        "critical")
            echo "⚠️  紧急情况诊断建议:"
            echo "1. 立即检查死锁情况"
            echo "2. 查看CPU热点方法，优先优化"
            echo "3. 检查线程状态，是否存在大量阻塞线程"
            echo "4. 考虑重启应用或增加资源"
            ;;
        "high")
            echo "🔴 高CPU使用率诊断建议:"
            echo "1. 分析CPU热点方法，进行代码优化"
            echo "2. 检查是否存在内存泄漏"
            echo "3. 优化数据库查询和缓存策略"
            echo "4. 考虑调整JVM参数"
            ;;
        "medium")
            echo "🟡 中等CPU使用率诊断建议:"
            echo "1. 监控CPU使用趋势"
            echo "2. 检查是否存在性能瓶颈"
            echo "3. 优化关键业务方法"
            echo "4. 考虑代码重构"
            ;;
        "low")
            echo "🟢 低CPU使用率诊断建议:"
            echo "1. 系统运行正常"
            echo "2. 定期监控系统状态"
            echo "3. 关注内存使用情况"
            echo "4. 保持现有优化"
            ;;
    esac
}

# 主分析函数
analyze_java_process_intelligently() {
    local pid=$1
    
    log_info "=== 智能分析Java进程 $pid ==="
    
    # 读取配置文件
    if ! read_config; then
        log_error "无法读取配置文件，使用默认配置"
    fi
    
    # 检查Arthas可用性
    local arthas_path=$(check_arthas)
    if [[ -z "$arthas_path" ]]; then
        log_error "Arthas不可用，跳过分析"
        return 1
    fi
    
    # 检查进程是否存在
    if ! ps -p $pid > /dev/null 2>&1; then
        log_error "进程 $pid 不存在"
        return 1
    fi
    
    # 获取进程CPU使用率
    local cpu_usage=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    if [[ -z "$cpu_usage" ]]; then
        cpu_usage="0"
    fi
    
    log_info "进程 $pid CPU使用率: ${cpu_usage}%"
    
    # 选择分析策略
    local strategy=$(select_analysis_strategy "$cpu_usage")
    log_info "选择分析策略: $strategy"
    
    # 创建输出目录
    local output_dir="/tmp/arthas_intelligent_analysis_${pid}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    
    log_info "分析结果将保存到: $output_dir"
    
    # 执行智能分析
    analyze_cpu_problem_intelligently "$pid" "$arthas_path" "$output_dir"
    
    # 执行针对性分析
    execute_targeted_analysis "$pid" "$arthas_path" "$output_dir" "$strategy"
    
    # 生成智能报告
    generate_intelligent_report "$output_dir" "$pid" "$strategy"
    
    log_info "智能分析完成，请查看以下文件:"
    echo "  - 智能诊断报告: $output_dir/intelligent_diagnosis_report.txt"
    echo "  - CPU分析: $output_dir/cpu_analysis.txt"
    echo "  - 线程分析: $output_dir/thread_analysis.txt"
    echo "  - 死锁检测: $output_dir/deadlock_detection.txt"
    echo "  - 调用栈分析: $output_dir/stack_analysis.txt"
    echo "  - JVM信息: $output_dir/jvm_info.txt"
    
    echo "$output_dir"
}

# 帮助信息
show_help() {
    echo "Java CPU诊断脚本 - Arthas智能增强版"
    echo ""
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -a, --analyze       智能分析高CPU Java进程"
    echo "  -p, --pid PID       智能分析指定Java进程ID"
    echo "  -c, --check         检查Arthas可用性"
    echo "  -d, --download      下载Arthas"
    echo "  -f, --config FILE   指定配置文件路径"
    echo ""
    echo "示例:"
    echo "  $0 -a                 # 智能分析高CPU Java进程"
    echo "  $0 -p 1234            # 智能分析Java进程1234"
    echo "  $0 -c                 # 检查Arthas"
    echo "  $0 -d                 # 下载Arthas"
    echo "  $0 -f custom.conf     # 使用自定义配置文件"
    echo ""
    echo "智能分析特性:"
    echo "  - 根据CPU使用率自动选择分析策略"
    echo "  - 支持配置文件自定义Arthas命令"
    echo "  - 自动生成诊断建议"
    echo "  - 多维度问题分析"
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
            -f|--config)
                CONFIG_FILE="$2"
                shift 2
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
            # 分析高CPU Java进程
            local high_cpu_java=$(ps aux | grep java | grep -v grep | awk '$3 > 30.0 {print $0}')
            if [[ -n "$high_cpu_java" ]]; then
                echo "发现高CPU Java进程:"
                echo "$high_cpu_java"
                echo ""
                
                local high_cpu_pids=$(echo "$high_cpu_java" | awk '{print $2}')
                for pid in $high_cpu_pids; do
                    if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
                        analyze_java_process_intelligently $pid
                    fi
                done
            else
                log_info "当前没有CPU使用率超过30%的Java进程"
            fi
            ;;
        "process")
            if [[ -n "$target_pid" ]]; then
                analyze_java_process_intelligently $target_pid
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
    
    log_info "智能诊断完成"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 