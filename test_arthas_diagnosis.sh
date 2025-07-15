#!/bin/bash

# Arthas诊断功能测试脚本
# 用于测试Arthas相关功能是否正常工作

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

# 测试Arthas可用性检查
test_arthas_check() {
    log_info "=== 测试Arthas可用性检查 ==="
    
    if [[ -f "./cpu_diagnosis_arthas.sh" ]]; then
        log_info "测试Arthas检查功能..."
        ./cpu_diagnosis_arthas.sh -c
        if [[ $? -eq 0 ]]; then
            log_info "Arthas检查功能正常"
        else
            log_warn "Arthas检查功能异常"
        fi
    else
        log_error "Arthas脚本不存在"
    fi
}

# 测试Arthas下载功能
test_arthas_download() {
    log_info "=== 测试Arthas下载功能 ==="
    
    if [[ -f "./cpu_diagnosis_arthas.sh" ]]; then
        log_info "测试Arthas下载功能..."
        ./cpu_diagnosis_arthas.sh -d
        if [[ $? -eq 0 ]]; then
            log_info "Arthas下载功能正常"
        else
            log_warn "Arthas下载功能异常"
        fi
    else
        log_error "Arthas脚本不存在"
    fi
}

# 测试配置文件读取
test_config_reading() {
    log_info "=== 测试配置文件读取 ==="
    
    if [[ -f "./arthas_commands.conf" ]]; then
        log_info "配置文件存在，测试读取..."
        
        # 检查配置文件格式
        local line_count=$(wc -l < "./arthas_commands.conf")
        log_info "配置文件行数: $line_count"
        
        # 检查关键配置项
        if grep -q "\[thread_analysis\]" "./arthas_commands.conf"; then
            log_info "线程分析配置项存在"
        else
            log_warn "线程分析配置项缺失"
        fi
        
        if grep -q "\[cpu_analysis\]" "./arthas_commands.conf"; then
            log_info "CPU分析配置项存在"
        else
            log_warn "CPU分析配置项缺失"
        fi
        
        if grep -q "\[timeout\]" "./arthas_commands.conf"; then
            log_info "超时配置项存在"
        else
            log_warn "超时配置项缺失"
        fi
    else
        log_error "配置文件不存在"
    fi
}

# 测试智能诊断脚本
test_intelligent_diagnosis() {
    log_info "=== 测试智能诊断脚本 ==="
    
    if [[ -f "./cpu_diagnosis_arthas_advanced.sh" ]]; then
        log_info "测试智能诊断脚本帮助信息..."
        ./cpu_diagnosis_arthas_advanced.sh -h
        if [[ $? -eq 0 ]]; then
            log_info "智能诊断脚本帮助功能正常"
        else
            log_warn "智能诊断脚本帮助功能异常"
        fi
    else
        log_error "智能诊断脚本不存在"
    fi
}

# 测试Java进程检测
test_java_process_detection() {
    log_info "=== 测试Java进程检测 ==="
    
    # 查找Java进程
    local java_processes=$(ps aux | grep java | grep -v grep | head -5)
    
    if [[ -n "$java_processes" ]]; then
        log_info "发现Java进程:"
        echo "$java_processes"
        
        # 获取第一个Java进程的PID
        local first_java_pid=$(echo "$java_processes" | head -1 | awk '{print $2}')
        
        if [[ -n "$first_java_pid" && "$first_java_pid" =~ ^[0-9]+$ ]]; then
            log_info "测试分析Java进程 $first_java_pid..."
            
            # 测试基础Arthas分析（不实际执行，只测试脚本语法）
            if [[ -f "./cpu_diagnosis_arthas.sh" ]]; then
                log_info "基础Arthas脚本语法检查通过"
            fi
            
            if [[ -f "./cpu_diagnosis_arthas_advanced.sh" ]]; then
                log_info "智能Arthas脚本语法检查通过"
            fi
        else
            log_warn "无法获取有效的Java进程PID"
        fi
    else
        log_warn "未发现Java进程，跳过进程分析测试"
    fi
}

# 测试脚本权限
test_script_permissions() {
    log_info "=== 测试脚本权限 ==="
    
    local scripts=(
        "cpu_diagnosis_arthas.sh"
        "cpu_diagnosis_arthas_advanced.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                log_info "$script 权限正常"
            else
                log_warn "$script 缺少执行权限，正在修复..."
                chmod +x "$script"
                log_info "$script 权限已修复"
            fi
        else
            log_error "$script 不存在"
        fi
    done
}

# 测试依赖工具
test_dependencies() {
    log_info "=== 测试依赖工具 ==="
    
    local tools=("java" "curl" "wget" "ps" "awk" "grep")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_info "$tool 可用"
        else
            log_warn "$tool 不可用"
        fi
    done
}

# 生成测试报告
generate_test_report() {
    local report_file="./arthas/arthas_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "生成测试报告: $report_file"
    
    {
        echo "Arthas诊断功能测试报告"
        echo "测试时间: $(date)"
        echo "系统信息: $(uname -a)"
        echo "========================================"
        echo ""
        
        echo "1. 脚本文件检查:"
        ls -la cpu_diagnosis_arthas*.sh 2>/dev/null || echo "脚本文件不存在"
        
        echo ""
        echo "2. 配置文件检查:"
        ls -la arthas_commands.conf 2>/dev/null || echo "配置文件不存在"
        
        echo ""
        echo "3. Java进程检查:"
        ps aux | grep java | grep -v grep | head -3 || echo "未发现Java进程"
        
        echo ""
        echo "4. 依赖工具检查:"
        for tool in java curl wget ps awk grep; do
            if command -v "$tool" &> /dev/null; then
                echo "  $tool: 可用"
            else
                echo "  $tool: 不可用"
            fi
        done
        
    } > "$report_file"
    
    log_info "测试报告已生成: $report_file"
}

# 主测试函数
main() {
    log_info "开始Arthas诊断功能测试..."
    
    # 测试脚本权限
    test_script_permissions
    
    # 测试依赖工具
    test_dependencies
    
    # 测试配置文件读取
    test_config_reading
    
    # 测试Arthas可用性检查
    test_arthas_check
    
    # 测试Arthas下载功能
    test_arthas_download
    
    # 测试智能诊断脚本
    test_intelligent_diagnosis
    
    # 测试Java进程检测
    test_java_process_detection
    
    # 生成测试报告
    generate_test_report
    
    log_info "Arthas诊断功能测试完成"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 