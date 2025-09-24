#!/bin/bash

# Option Learner Guide - 监控脚本
# 监控应用状态、性能和健康状况

set -e

# 配置
PROJECT_DIR="/home/kunkka/projects/option-learner-guide"
PORT="3000"
DOMAIN="172.93.186.229"
LOG_FILE="/home/kunkka/projects/option-learner-guide/logs/monitor.log"
ALERT_EMAIL=""  # 设置邮件地址以接收告警

# 阈值配置
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=85
RESPONSE_TIME_THRESHOLD=3000

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_message "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR" "$1"
}

# 发送告警
send_alert() {
    local subject=$1
    local message=$2

    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi

    # 可以在这里添加其他告警方式，如 Slack、钉钉等
}

# 检查应用进程
check_process() {
    log_info "检查应用进程..."

    # 检查端口是否被监听
    if ! lsof -i:$PORT &> /dev/null; then
        log_error "应用未在端口 $PORT 运行"
        return 1
    fi

    # 获取进程信息
    local pid=$(lsof -ti:$PORT)
    local process_info=$(ps -p $pid -o pid,pcpu,pmem,etime,cmd --no-headers 2>/dev/null || echo "")

    if [[ -n "$process_info" ]]; then
        log_success "应用进程正常运行 (PID: $pid)"
        echo "  $process_info"
    else
        log_error "无法获取进程信息"
        return 1
    fi
}

# 检查HTTP响应
check_http_response() {
    log_info "检查HTTP响应..."

    # 检查主页
    local response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" http://127.0.0.1:$PORT/ --connect-timeout 10 --max-time 30)
    local http_code=$(echo $response | cut -d, -f1)
    local response_time=$(echo $response | cut -d, -f2)
    local response_time_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)

    if [[ "$http_code" == "200" ]]; then
        log_success "HTTP响应正常 (状态码: $http_code, 响应时间: ${response_time_ms}ms)"

        if [[ $response_time_ms -gt $RESPONSE_TIME_THRESHOLD ]]; then
            log_warning "响应时间过长: ${response_time_ms}ms (阈值: ${RESPONSE_TIME_THRESHOLD}ms)"
        fi
    else
        log_error "HTTP响应异常 (状态码: $http_code)"
        return 1
    fi
}

# 检查SSE接口
check_sse_endpoint() {
    log_info "检查SSE接口..."

    # 测试SSE接口（3秒超时）
    local sse_response=$(timeout 3 curl -s -N http://127.0.0.1:$PORT/api/stream 2>&1 || echo "TIMEOUT")

    if [[ "$sse_response" == "TIMEOUT" ]]; then
        log_success "SSE接口响应正常（超时属于正常行为）"
    elif [[ -n "$sse_response" ]]; then
        log_success "SSE接口响应正常"
    else
        log_warning "SSE接口可能异常"
    fi
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源..."

    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    cpu_usage=${cpu_usage%.*}  # 去除小数部分

    if [[ $cpu_usage -gt $CPU_THRESHOLD ]]; then
        log_warning "CPU使用率过高: ${cpu_usage}% (阈值: ${CPU_THRESHOLD}%)"
        send_alert "CPU告警" "CPU使用率: ${cpu_usage}%，超过阈值 ${CPU_THRESHOLD}%"
    else
        log_success "CPU使用率正常: ${cpu_usage}%"
    fi

    # 内存使用率
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))

    if [[ $memory_usage -gt $MEMORY_THRESHOLD ]]; then
        log_warning "内存使用率过高: ${memory_usage}% (阈值: ${MEMORY_THRESHOLD}%)"
        send_alert "内存告警" "内存使用率: ${memory_usage}%，超过阈值 ${MEMORY_THRESHOLD}%"
    else
        log_success "内存使用率正常: ${memory_usage}%"
    fi

    # 磁盘使用率
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | cut -d% -f1)

    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        log_warning "磁盘使用率过高: ${disk_usage}% (阈值: ${DISK_THRESHOLD}%)"
        send_alert "磁盘告警" "磁盘使用率: ${disk_usage}%，超过阈值 ${DISK_THRESHOLD}%"
    else
        log_success "磁盘使用率正常: ${disk_usage}%"
    fi
}

# 检查日志错误
check_logs() {
    log_info "检查应用日志..."

    local log_files=(
        "$PROJECT_DIR/logs/pm2-error.log"
        "$PROJECT_DIR/logs/pm2-out.log"
        "/var/log/nginx/option-learner-guide.error.log"
    )

    local error_count=0

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            # 检查最近1小时的错误
            local recent_errors=$(find "$log_file" -newermt "1 hour ago" -exec grep -i "error\|exception\|fatal" {} \; 2>/dev/null | wc -l)

            if [[ $recent_errors -gt 0 ]]; then
                log_warning "发现 $recent_errors 个错误在 $log_file"
                error_count=$((error_count + recent_errors))
            fi
        fi
    done

    if [[ $error_count -eq 0 ]]; then
        log_success "未发现近期错误日志"
    else
        log_warning "总计发现 $error_count 个错误"
        if [[ $error_count -gt 10 ]]; then
            send_alert "日志告警" "发现大量错误日志: $error_count 个"
        fi
    fi
}

# 检查服务管理器状态
check_service_manager() {
    log_info "检查服务管理器状态..."

    # 检查PM2状态
    if command -v pm2 &> /dev/null; then
        local pm2_status=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="option-learner-guide") | .pm2_env.status' 2>/dev/null || echo "")

        if [[ "$pm2_status" == "online" ]]; then
            log_success "PM2服务状态正常"
        elif [[ -n "$pm2_status" ]]; then
            log_warning "PM2服务状态: $pm2_status"
        fi
    fi

    # 检查Systemd状态
    if systemctl is-active --quiet option-learner-guide 2>/dev/null; then
        log_success "Systemd服务状态正常"
    elif systemctl list-units --full -all | grep -Fq "option-learner-guide.service"; then
        local systemd_status=$(systemctl is-active option-learner-guide 2>/dev/null || echo "unknown")
        log_warning "Systemd服务状态: $systemd_status"
    fi

    # 检查Nginx状态
    if systemctl is-active --quiet nginx 2>/dev/null; then
        log_success "Nginx服务状态正常"
    else
        log_error "Nginx服务异常"
    fi
}

# 性能统计
performance_stats() {
    log_info "生成性能统计..."

    # 应用进程资源使用
    local pid=$(lsof -ti:$PORT 2>/dev/null || echo "")
    if [[ -n "$pid" ]]; then
        local process_stats=$(ps -p $pid -o pid,pcpu,pmem,vsz,rss --no-headers 2>/dev/null || echo "")
        echo "应用进程统计: $process_stats"
    fi

    # 网络连接统计
    local connections=$(ss -tn | grep ":$PORT" | wc -l)
    echo "当前连接数: $connections"

    # 文件描述符使用
    if [[ -n "$pid" ]]; then
        local fd_count=$(lsof -p $pid 2>/dev/null | wc -l)
        echo "文件描述符使用: $fd_count"
    fi
}

# 生成监控报告
generate_report() {
    local report_file="/tmp/option-learner-guide-monitor-$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "Option Learner Guide 监控报告"
        echo "=============================="
        echo "报告时间: $(date)"
        echo "域名: $DOMAIN"
        echo "端口: $PORT"
        echo ""

        echo "系统信息:"
        echo "- 负载均衡: $(uptime | awk -F'load average:' '{print $2}')"
        echo "- 内存使用: $(free -h | grep Mem | awk '{print $3"/"$2}')"
        echo "- 磁盘使用: $(df -h "$PROJECT_DIR" | tail -1 | awk '{print $5}')"
        echo ""

        performance_stats

    } > "$report_file"

    log_info "监控报告生成: $report_file"
}

# 主函数
main() {
    local mode=${1:-"check"}

    case $mode in
        "check")
            log_info "开始健康检查..."
            check_process && \
            check_http_response && \
            check_sse_endpoint && \
            check_system_resources && \
            check_logs && \
            check_service_manager

            if [[ $? -eq 0 ]]; then
                log_success "健康检查通过"
            else
                log_error "健康检查发现问题"
                exit 1
            fi
            ;;
        "report")
            log_info "生成监控报告..."
            generate_report
            ;;
        "watch")
            log_info "启动监控模式（每30秒检查一次）..."
            while true; do
                main check
                sleep 30
            done
            ;;
        *)
            echo "用法: $0 [check|report|watch]"
            echo "  check  - 执行一次健康检查（默认）"
            echo "  report - 生成监控报告"
            echo "  watch  - 持续监控模式"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"