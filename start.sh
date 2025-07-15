#!/bin/bash

# CPU Top Demo 启动脚本
# 作者: 开发者
# 版本: 1.0.0

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# 检查Java环境
check_java() {
    if ! command -v java &> /dev/null; then
        log_error "Java未安装或不在PATH中"
        exit 1
    fi
    
    local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    log_info "Java版本: $java_version"
}

# 检查Maven环境
check_maven() {
    if ! command -v mvn &> /dev/null; then
        log_error "Maven未安装或不在PATH中"
        exit 1
    fi
    
    local maven_version=$(mvn -version 2>&1 | head -n 1)
    log_info "Maven版本: $maven_version"
}

# 编译项目
build_project() {
    log_info "开始编译项目..."
    
    if mvn clean package -DskipTests; then
        log_info "项目编译成功"
    else
        log_error "项目编译失败"
        exit 1
    fi
}

# 启动应用
start_application() {
    local jar_file="target/cpu-top-demo-1.0.0.jar"
    
    if [[ ! -f "$jar_file" ]]; then
        log_error "JAR文件不存在: $jar_file"
        log_info "请先运行: ./start.sh build"
        exit 1
    fi
    
    log_info "启动应用..."
    log_info "JVM参数: -Xmx512m -Xms256m -XX:ActiveProcessorCount=1"
    log_info "应用端口: 8080"
    log_info "健康检查: http://localhost:8080/health"
    log_info "API文档: http://localhost:8080/api/cpu/status"
    echo ""
    
    # 启动应用，使用JVM参数限制资源
    java \
        -Xmx512m \
        -Xms256m \
        -XX:ActiveProcessorCount=1 \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=200 \
        -XX:+HeapDumpOnOutOfMemoryError \
        -XX:HeapDumpPath=/tmp/ \
        -Dspring.profiles.active=dev \
        -jar "$jar_file"
}

# 显示帮助信息
show_help() {
    echo "CPU Top Demo 启动脚本使用方法:"
    echo ""
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  build    编译项目"
    echo "  start    启动应用 (默认)"
    echo "  run      编译并启动应用"
    echo "  stop     停止应用"
    echo "  status   查看应用状态"
    echo "  help     显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build    # 只编译项目"
    echo "  $0 start    # 启动应用"
    echo "  $0 run      # 编译并启动"
    echo ""
}

# 停止应用
stop_application() {
    local pid=$(pgrep -f "cpu-top-demo")
    
    if [[ -n "$pid" ]]; then
        log_info "停止应用 (PID: $pid)..."
        kill $pid
        sleep 2
        
        # 检查是否成功停止
        if pgrep -f "cpu-top-demo" > /dev/null; then
            log_warn "应用未正常停止，强制杀死..."
            kill -9 $pid
        fi
        
        log_info "应用已停止"
    else
        log_info "应用未运行"
    fi
}

# 查看应用状态
check_status() {
    local pid=$(pgrep -f "cpu-top-demo")
    
    if [[ -n "$pid" ]]; then
        log_info "应用正在运行 (PID: $pid)"
        ps -p $pid -o pid,ppid,user,%cpu,%mem,vsz,rss,comm,args --no-headers
        
        # 检查端口
        if netstat -tlnp 2>/dev/null | grep -q ":8080 "; then
            log_info "端口8080正在监听"
        else
            log_warn "端口8080未监听"
        fi
    else
        log_info "应用未运行"
    fi
}

# 主函数
main() {
    local action=${1:-start}
    
    case $action in
        "build")
            check_java
            check_maven
            build_project
            ;;
        "start")
            check_java
            start_application
            ;;
        "run")
            check_java
            check_maven
            build_project
            start_application
            ;;
        "stop")
            stop_application
            ;;
        "status")
            check_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 