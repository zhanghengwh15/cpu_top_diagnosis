#!/bin/bash

# CPU监控定时任务脚本
# 每30秒检查一次系统负载，当超过阈值时触发CPU诊断
# 作者: 开发者
# 版本: 1.0.0

set -e

# 配置参数
CPU_THRESHOLD=240
CHECK_INTERVAL=30
LOG_FILE="./cpu_monitor.log"
DIAGNOSIS_SCRIPT="./cpu_diagnosis_arthas.sh"
LOCK_FILE="./cpu_monitor.lock"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检测操作系统
# 返回 macos 或 linux
# 用于top命令兼容判断
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# 日志函数
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[INFO]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARN]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

# 检查系统负载
check_system_load() {
    local os=$(detect_os)
    local load_value=""
    
    if [[ "$os" == "macos" ]]; then
        # macOS使用不同的top命令格式
        load_value=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null)
        if [[ -z "$load_value" ]]; then
            # 备用方法：使用vm_stat获取负载信息
            load_value=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//' 2>/dev/null)
        fi
    else
        # Linux使用原始命令
        load_value=$(top -n1 -b | grep "  1 root" | awk '{print $(NF - 3)}' 2>/dev/null)
    fi
    
    if [[ -z "$load_value" ]]; then
        log_error "无法获取系统负载值"
        return 1
    fi
    
    # 检查是否为数字
    if ! [[ "$load_value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "系统负载值格式错误: $load_value"
        return 1
    fi
    
    echo "$load_value"
}

# 检查诊断脚本是否存在
check_diagnosis_script() {
    if [[ ! -f "$DIAGNOSIS_SCRIPT" ]]; then
        log_error "CPU诊断脚本不存在: $DIAGNOSIS_SCRIPT"
        return 1
    fi
    
    if [[ ! -x "$DIAGNOSIS_SCRIPT" ]]; then
        log_warn "CPU诊断脚本没有执行权限，正在添加..."
        chmod +x "$DIAGNOSIS_SCRIPT"
    fi
    
    return 0
}

# 执行CPU诊断
run_cpu_diagnosis() {
    local load_value=$1
    
    log_warn "系统负载过高: $load_value (阈值: $CPU_THRESHOLD)，开始执行CPU诊断..."
    
    # 检查是否已有诊断在运行
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            log_warn "CPU诊断已在运行 (PID: $lock_pid)，跳过本次诊断"
            return 0
        else
            # 清理无效的锁文件
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # 创建锁文件
    echo $$ > "$LOCK_FILE"
    
    # 执行诊断脚本
    if "$DIAGNOSIS_SCRIPT" -a; then
        log_info "CPU诊断执行成功"
    else
        log_error "CPU诊断执行失败"
    fi
    
    # 清理锁文件
    rm -f "$LOCK_FILE"
}

# 监控循环
monitor_loop() {
    log_info "开始CPU监控，检查间隔: ${CHECK_INTERVAL}秒，阈值: $CPU_THRESHOLD"
    
    while true; do
        # 检查诊断脚本
        if ! check_diagnosis_script; then
            log_error "诊断脚本检查失败，退出监控"
            exit 1
        fi
        
        # 获取系统负载
        local load_value=$(check_system_load)
        if [[ $? -eq 0 ]]; then
            log_info "当前系统负载: $load_value"
            
            # 检查是否超过阈值
            if (( $(echo "$load_value > $CPU_THRESHOLD" | bc -l) )); then
                run_cpu_diagnosis "$load_value"
            fi
        fi
        
        # 等待下次检查
        sleep "$CHECK_INTERVAL"
    done
}

# 停止监控
stop_monitor() {
    log_info "正在停止CPU监控..."
    
    # 查找监控进程
    local monitor_pid=$(pgrep -f "cpu_monitor_cron.sh" | grep -v $$)
    
    if [[ -n "$monitor_pid" ]]; then
        log_info "找到监控进程 PID: $monitor_pid，正在终止..."
        kill -TERM "$monitor_pid" 2>/dev/null
        
        # 等待进程结束
        local count=0
        while kill -0 "$monitor_pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        # 强制终止
        if kill -0 "$monitor_pid" 2>/dev/null; then
            log_warn "强制终止监控进程"
            kill -KILL "$monitor_pid" 2>/dev/null
        fi
        
        log_info "监控进程已停止"
    else
        log_info "未找到运行中的监控进程"
    fi
    
    # 清理锁文件
    rm -f "$LOCK_FILE"
}

# 显示状态
show_status() {
    log_info "=== CPU监控状态 ==="
    
    # 检查监控进程
    local monitor_pid=$(pgrep -f "cpu_monitor_cron.sh" | grep -v $$)
    if [[ -n "$monitor_pid" ]]; then
        log_info "监控进程正在运行，PID: $monitor_pid"
    else
        log_info "监控进程未运行"
    fi
    
    # 显示当前系统负载
    local load_value=$(check_system_load)
    if [[ $? -eq 0 ]]; then
        log_info "当前系统负载: $load_value (阈值: $CPU_THRESHOLD)"
    fi
    
    # 显示日志文件大小
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(du -h "$LOG_FILE" | cut -f1)
        log_info "日志文件大小: $log_size"
    fi
}



# 后台运行模式
daemon_mode() {
    log_info "启动后台监控模式..."
    
    # 重定向输出到日志文件
    exec 1>>"$LOG_FILE" 2>&1
    
    # 监控循环
    monitor_loop
}

# 帮助信息
show_help() {
    echo "CPU监控定时任务脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示帮助信息"
    echo "  -s, --start         启动监控"
    echo "  -S, --stop          停止监控"
    echo "  -t, --status        显示状态"
    echo "  -d, --daemon        后台运行模式"
    echo ""
    echo "配置参数:"
    echo "  CPU_THRESHOLD: $CPU_THRESHOLD (系统负载阈值)"
    echo "  CHECK_INTERVAL: $CHECK_INTERVAL (检查间隔秒数)"
    echo "  LOG_FILE: $LOG_FILE (日志文件)"
    echo ""
    echo "示例:"
    echo "  $0 --start           # 启动监控"
    echo "  $0 --stop            # 停止监控"
    echo "  $0 --status          # 查看状态"
    echo ""
}

# 主函数
main() {
    local mode="start"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--start)
                mode="start"
                shift
                ;;
            -S|--stop)
                mode="stop"
                shift
                ;;
            -t|--status)
                mode="status"
                shift
                ;;
            -d|--daemon)
                mode="daemon"
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
        "start")
            # 检查是否已在运行
            local monitor_pid=$(pgrep -f "cpu_monitor_cron.sh" | grep -v $$)
            if [[ -n "$monitor_pid" ]]; then
                log_warn "监控进程已在运行，PID: $monitor_pid"
                exit 0
            fi
            
            # 启动监控
            monitor_loop &
            local monitor_pid=$!
            log_info "监控进程已启动，PID: $monitor_pid"
            ;;
        "stop")
            stop_monitor
            ;;
        "status")
            show_status
            ;;
        "daemon")
            daemon_mode
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 