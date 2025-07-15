#!/bin/bash

# Java CPU诊断脚本 - 智能启动器
# 根据操作系统自动选择合适的专用脚本
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

# 获取脚本目录
get_script_dir() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir=""
    
    # 如果是符号链接，获取真实路径
    if [[ -L "$script_path" ]]; then
        script_path=$(readlink -f "$script_path")
    fi
    
    script_dir=$(dirname "$script_path")
    echo "$script_dir"
}

# 主函数
main() {
    local os=$(detect_os)
    local script_dir=$(get_script_dir)
    
    log_info "检测到操作系统: $os"
    
    case $os in
        "macos")
            local macos_script="$script_dir/cpu_diagnosis_macos.sh"
            if [[ -f "$macos_script" ]]; then
                log_info "启动macOS专用脚本: $macos_script"
                exec "$macos_script" "$@"
            else
                log_error "未找到macOS专用脚本: $macos_script"
                log_error "请确保 cpu_diagnosis_macos.sh 文件存在"
                exit 1
            fi
            ;;
        "linux")
            local linux_script="$script_dir/cpu_diagnosis_linux.sh"
            if [[ -f "$linux_script" ]]; then
                log_info "启动Linux专用脚本: $linux_script"
                exec "$linux_script" "$@"
            else
                log_error "未找到Linux专用脚本: $linux_script"
                log_error "请确保 cpu_diagnosis_linux.sh 文件存在"
                exit 1
            fi
            ;;
        *)
            log_error "不支持的操作系统: $os"
            log_error "当前仅支持 macOS 和 Linux"
            exit 1
            ;;
    esac
}

# 显示帮助信息
show_help() {
    echo "Java CPU诊断脚本 - 智能启动器"
    echo ""
    echo "使用方法:"
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
    echo "脚本说明:"
    echo "  此脚本会根据操作系统自动选择合适的专用脚本:"
    echo "  - macOS: 使用 cpu_diagnosis_macos.sh"
    echo "  - Linux: 使用 cpu_diagnosis_linux.sh"
    echo ""
    echo "文件要求:"
    echo "  请确保以下文件存在于同一目录:"
    echo "  - cpu_diagnosis_macos.sh (macOS专用)"
    echo "  - cpu_diagnosis_linux.sh (Linux专用)"
    echo ""
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 检查是否请求帮助
    if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
        show_help
        exit 0
    fi
    
    main "$@"
fi 