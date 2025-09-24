#!/bin/bash

# Option Learner Guide - 备份脚本
# 用于备份应用数据、配置和日志

set -e

# 配置
PROJECT_DIR="/home/kunkka/projects/option-learner-guide"
BACKUP_DIR="/home/kunkka/backups/option-learner-guide"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="option-learner-guide_${DATE}"
RETENTION_DAYS=7

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建备份目录
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "创建备份目录: $BACKUP_DIR"
    fi
}

# 备份应用代码
backup_code() {
    log_info "备份应用代码..."
    cd "$PROJECT_DIR"
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_code.tar.gz" \
        --exclude=node_modules \
        --exclude=.next \
        --exclude=.git \
        --exclude=logs \
        --exclude=*.log \
        .
    log_info "代码备份完成: ${BACKUP_NAME}_code.tar.gz"
}

# 备份配置文件
backup_config() {
    log_info "备份配置文件..."
    local config_backup="$BACKUP_DIR/${BACKUP_NAME}_config"
    mkdir -p "$config_backup"

    # 备份环境配置
    if [[ -f "$PROJECT_DIR/.env.production" ]]; then
        cp "$PROJECT_DIR/.env.production" "$config_backup/"
    fi

    # 备份 PM2 配置
    if [[ -f "$PROJECT_DIR/ops/ecosystem.config.js" ]]; then
        cp -r "$PROJECT_DIR/ops" "$config_backup/"
    fi

    # 备份 Nginx 配置
    if [[ -f "/etc/nginx/sites-available/option-learner-guide" ]]; then
        mkdir -p "$config_backup/nginx"
        sudo cp "/etc/nginx/sites-available/option-learner-guide" "$config_backup/nginx/"
    fi

    # 备份 Systemd 配置
    if [[ -f "/etc/systemd/system/option-learner-guide.service" ]]; then
        mkdir -p "$config_backup/systemd"
        sudo cp "/etc/systemd/system/option-learner-guide.service" "$config_backup/systemd/"
    fi

    # 打包配置
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}_config.tar.gz" "${BACKUP_NAME}_config"
    rm -rf "${BACKUP_NAME}_config"

    log_info "配置备份完成: ${BACKUP_NAME}_config.tar.gz"
}

# 备份日志
backup_logs() {
    log_info "备份日志文件..."
    local log_dirs=(
        "$PROJECT_DIR/logs"
        "/var/log/nginx"
        "/var/log/pm2"
    )

    local log_backup="$BACKUP_DIR/${BACKUP_NAME}_logs"
    mkdir -p "$log_backup"

    for dir in "${log_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_name=$(basename "$dir")
            mkdir -p "$log_backup/$dir_name"
            find "$dir" -name "*.log" -type f -exec cp {} "$log_backup/$dir_name/" \; 2>/dev/null || true
        fi
    done

    # 系统日志
    if command -v journalctl &> /dev/null; then
        sudo journalctl -u option-learner-guide --since "7 days ago" > "$log_backup/systemd.log" 2>/dev/null || true
    fi

    # 打包日志
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}_logs.tar.gz" "${BACKUP_NAME}_logs"
    rm -rf "${BACKUP_NAME}_logs"

    log_info "日志备份完成: ${BACKUP_NAME}_logs.tar.gz"
}

# 备份数据库（如果存在）
backup_database() {
    # 检查是否有数据库配置
    if [[ -f "$PROJECT_DIR/.env.production" ]] && grep -q "DATABASE_URL\|DB_HOST" "$PROJECT_DIR/.env.production"; then
        log_info "检测到数据库配置，开始备份..."

        # 这里可以根据实际使用的数据库类型添加备份逻辑
        # 例如 PostgreSQL:
        # pg_dump $DATABASE_URL > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"

        # 例如 MongoDB:
        # mongodump --uri $DATABASE_URL --out "$BACKUP_DIR/${BACKUP_NAME}_mongodb"

        log_warning "数据库备份功能需要根据实际数据库类型配置"
    else
        log_info "未检测到数据库配置，跳过数据库备份"
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理 $RETENTION_DAYS 天前的备份..."
    find "$BACKUP_DIR" -name "option-learner-guide_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    log_info "旧备份清理完成"
}

# 生成备份报告
generate_report() {
    local report_file="$BACKUP_DIR/${BACKUP_NAME}_report.txt"
    cat > "$report_file" << EOF
Option Learner Guide 备份报告
==============================

备份时间: $(date)
备份名称: $BACKUP_NAME
项目路径: $PROJECT_DIR
备份路径: $BACKUP_DIR

备份文件:
$(ls -lh "$BACKUP_DIR"/${BACKUP_NAME}_*.tar.gz 2>/dev/null || echo "无备份文件")

系统信息:
- 操作系统: $(uname -a)
- 磁盘使用: $(df -h "$BACKUP_DIR" | tail -1)
- 内存使用: $(free -h | head -2 | tail -1)

服务状态:
$(systemctl is-active option-learner-guide 2>/dev/null || pm2 list 2>/dev/null | grep option-learner-guide || echo "服务状态未知")

备份完成时间: $(date)
EOF

    log_info "备份报告生成: ${BACKUP_NAME}_report.txt"
}

# 主函数
main() {
    log_info "开始备份 Option Learner Guide..."

    create_backup_dir
    backup_code
    backup_config
    backup_logs
    backup_database
    cleanup_old_backups
    generate_report

    log_info "备份完成！备份文件位于: $BACKUP_DIR"
    log_info "备份文件列表:"
    ls -lh "$BACKUP_DIR"/${BACKUP_NAME}_* 2>/dev/null || true
}

# 执行主函数
main "$@"