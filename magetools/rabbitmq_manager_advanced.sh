#!/bin/bash

# RabbitMQ 高级站点管理脚本
# 使用 systemd 管理、双线程、全量消费者、高性能权限修复
# 作者: Ansible LEMP Project
# 版本: 3.0.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
FIRE="🔥"

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/tmp/rabbitmq_manager_advanced_${SITE_NAME}.lock"
ERROR_LOG="/tmp/rabbitmq_manager_advanced_${SITE_NAME}_error.log"
SYSTEMD_SERVICE_PREFIX="magento-consumer"

# 错误处理函数
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    echo -e "${RED}[ERROR]${NC} 脚本在第 $line_number 行失败: $command" >&2
    echo -e "${RED}[ERROR]${NC} 退出码: $exit_code" >&2
    echo "$(date): 脚本失败 - 行 $line_number, 命令: $command, 退出码: $exit_code" >> "$ERROR_LOG"
    
    # 清理锁文件
    cleanup_lock
    
    exit $exit_code
}

# 设置错误陷阱
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

# 锁文件管理
acquire_lock() {
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo "$$" > "$LOCK_FILE"
            return 0
        fi
        
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$LOCK_FILE"
            continue
        fi
        
        sleep 1
        ((attempt++))
    done
    
    log_error "无法获取锁文件，可能有其他实例正在运行"
    exit 1
}

cleanup_lock() {
    rm -f "$LOCK_FILE"
}

# 安全退出函数
safe_exit() {
    cleanup_lock
    exit ${1:-0}
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date): [INFO] $1" >> "$ERROR_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date): [SUCCESS] $1" >> "$ERROR_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date): [WARNING] $1" >> "$ERROR_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date): [ERROR] $1" >> "$ERROR_LOG"
}

# 生成统一密码
generate_password() {
    local site_name="$1"
    echo "${site_name^}#2025!"
}

# 超高性能权限修复函数（基于 magento-permissions-fast.sh 优化）
fix_permissions_fast() {
    local site_path="$1"
    local nginx_group="${2:-www-data}"
    local site_user="$(whoami)"
    
    log_info "修复 Magento 权限（超高性能模式）..."
    
    # 性能配置（激进优化参数）
    local max_parallel_jobs=16  # 增加并行任务数
    local batch_size=2000       # 增加批处理大小
    
    # 切换到网站目录
    cd "$site_path" || return 1
    
    # 1. 批量设置所有者和组（一次性处理整个目录）
    sudo chown -R "${site_user}:${nginx_group}" .
    
    # 2. 并行设置基础权限（755/644）
    find . -type d -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod 755 2>/dev/null || true
    find . -type f -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod 644 2>/dev/null || true
    
    # 3. 并行设置可写目录权限（775/664 + setgid）
    local writable_dirs=("var" "generated" "pub/media" "pub/static")
    
    for dir in "${writable_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # 并行设置目录权限
            find "$dir" -type d -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod 775 2>/dev/null || true
            
            # 并行设置文件权限
            find "$dir" -type f -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod 664 2>/dev/null || true
            
            # 并行设置 setgid 位（确保新文件继承组）
            find "$dir" -type d -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod g+s 2>/dev/null || true
        fi
    done
    
    # 4. 设置可执行文件权限
    if [[ -f "bin/magento" ]]; then
        sudo chmod 755 bin/magento
    fi
    
    # 查找其他可执行文件
    find . -name "*.sh" -type f -print0 | xargs -0 -n $batch_size -P $max_parallel_jobs sudo chmod 755 2>/dev/null || true
    
    log_success "权限修复完成（超高性能模式）"
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查必需的命令
    for cmd in rabbitmqctl php sudo systemctl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# 检查权限
check_permissions() {
    # 检查 sudo 权限
    if ! sudo -n true 2>/dev/null; then
        log_error "需要 sudo 权限来管理 RabbitMQ 和 systemd"
        return 1
    fi
    
    # 检查站点目录权限
    if [ ! -w "$SITE_PATH" ]; then
        log_error "没有站点目录写权限: $SITE_PATH"
        return 1
    fi
    
    return 0
}

# 验证输入参数
validate_input() {
    # 检查站点名称格式
    if [[ ! "$SITE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "站点名称只能包含字母、数字、下划线和连字符"
        return 1
    fi
    
    # 检查站点名称长度
    if [ ${#SITE_NAME} -gt 20 ]; then
        log_error "站点名称过长（最大20字符）"
        return 1
    fi
    
    return 0
}

# 检查 RabbitMQ 服务状态
check_rabbitmq_service() {
    if ! systemctl is-active --quiet rabbitmq-server; then
        log_error "RabbitMQ 服务未运行"
        log_info "尝试启动 RabbitMQ 服务..."
        
        if sudo systemctl start rabbitmq-server; then
            log_success "RabbitMQ 服务已启动"
            sleep 3
        else
            log_error "无法启动 RabbitMQ 服务"
            return 1
        fi
    fi
    
    # 验证 RabbitMQ 连接
    if ! sudo rabbitmqctl status >/dev/null 2>&1; then
        log_error "无法连接到 RabbitMQ"
        return 1
    fi
    
    return 0
}

# 安全的 RabbitMQ 命令执行
safe_rabbitmq_cmd() {
    local cmd="$1"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if eval "sudo rabbitmqctl $cmd" 2>/dev/null; then
            return 0
        fi
        
        ((retry++))
        log_warning "RabbitMQ 命令失败，重试 $retry/$max_retries: $cmd"
        sleep 2
    done
    
    log_error "RabbitMQ 命令最终失败: $cmd"
    return 1
}

# 创建 systemd 服务文件
create_systemd_service() {
    local consumer_name="$1"
    local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer_name}"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log_info "创建 systemd 服务: $service_name"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Magento Consumer: ${consumer_name} for ${SITE_NAME}
After=network.target rabbitmq-server.service
Wants=rabbitmq-server.service

[Service]
Type=simple
User=$(whoami)
Group=www-data
WorkingDirectory=${SITE_PATH}
ExecStart=/usr/bin/php -d memory_limit=2G bin/magento queue:consumers:start ${consumer_name} --max-messages=1000
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${service_name}

# 资源限制
MemoryLimit=2G
CPUQuota=200%

# 环境变量
Environment=PHP_INI_SCAN_DIR=/etc/php/8.1/cli/conf.d

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable "$service_name"
    
    log_success "systemd 服务创建完成: $service_name"
}

# 启动 systemd 消费者服务
start_systemd_consumer() {
    local consumer_name="$1"
    local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer_name}"
    
    log_info "启动 systemd 消费者服务: $service_name"
    
    if sudo systemctl start "$service_name"; then
        log_success "消费者服务启动成功: $service_name"
        return 0
    else
        log_error "消费者服务启动失败: $service_name"
        return 1
    fi
}

# 停止 systemd 消费者服务
stop_systemd_consumer() {
    local consumer_name="$1"
    local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer_name}"
    
    log_info "停止 systemd 消费者服务: $service_name"
    
    if sudo systemctl stop "$service_name"; then
        log_success "消费者服务停止成功: $service_name"
        return 0
    else
        log_warning "消费者服务停止失败或未运行: $service_name"
        return 1
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}RabbitMQ 高级站点管理脚本${NC}"
    echo
    echo -e "${YELLOW}功能:${NC}"
    echo -e "  • 使用 systemd 管理队列消费者"
    echo -e "  • 双线程消费者支持"
    echo -e "  • 全量 Magento2 消费者"
    echo -e "  • 超高性能权限修复"
    echo -e "  • 自动服务管理和监控"
    echo
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager_advanced.sh <site_name> <action>${NC}"
    echo
    echo -e "${YELLOW}操作:${NC}"
    echo -e "  ${CYAN}setup${NC}     - 配置站点 (创建虚拟主机、用户、配置 Magento、创建 systemd 服务)"
    echo -e "  ${CYAN}start${NC}      - 启动所有消费者服务"
    echo -e "  ${CYAN}stop${NC}       - 停止所有消费者服务"
    echo -e "  ${CYAN}restart${NC}    - 重启所有消费者服务"
    echo -e "  ${CYAN}status${NC}     - 查看所有服务状态"
    echo -e "  ${CYAN}logs${NC}       - 查看服务日志"
    echo -e "  ${CYAN}monitor${NC}    - 监控服务状态"
    echo -e "  ${CYAN}clean${NC}      - 清理队列和日志"
    echo -e "  ${CYAN}remove${NC}     - 删除站点配置和服务"
    echo -e "  ${CYAN}health${NC}     - 健康检查"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager_advanced.sh ipwa setup${NC}    # 配置 ipwa 站点"
    echo -e "  ${CYAN}./rabbitmq_manager_advanced.sh hawk start${NC}    # 启动 hawk 消费者"
    echo -e "  ${CYAN}./rabbitmq_manager_advanced.sh ipwa health${NC}   # 健康检查"
    echo
    echo -e "${YELLOW}站点路径格式:${NC}"
    echo -e "  ${CYAN}/home/doge/<site_name>${NC}"
    echo
}

# 健康检查
health_check() {
    log_info "执行 $SITE_NAME 的健康检查..."
    
    local issues=0
    
    echo
    echo -e "${CYAN}=== 系统健康检查 ===${NC}"
    
    # 检查 RabbitMQ 服务
    if systemctl is-active --quiet rabbitmq-server; then
        echo -e "RabbitMQ 服务: ${GREEN}正常${NC}"
    else
        echo -e "RabbitMQ 服务: ${RED}异常${NC}"
        ((issues++))
    fi
    
    # 检查虚拟主机
    if safe_rabbitmq_cmd "list_vhosts" | grep -q "^$VHOST_NAME$"; then
        echo -e "虚拟主机: ${GREEN}存在${NC}"
    else
        echo -e "虚拟主机: ${RED}不存在${NC}"
        ((issues++))
    fi
    
    # 检查用户
    if safe_rabbitmq_cmd "list_users" | grep -q "^$USER_NAME"; then
        echo -e "用户: ${GREEN}存在${NC}"
    else
        echo -e "用户: ${RED}不存在${NC}"
        ((issues++))
    fi
    
    # 检查 systemd 服务
    local active_services=0
    local total_services=0
    
    for consumer in "${CONSUMERS[@]}"; do
        local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer}"
        ((total_services++))
        
        if systemctl is-active --quiet "$service_name"; then
            ((active_services++))
        fi
    done
    
    echo -e "消费者服务: ${GREEN}$active_services/$total_services 运行中${NC}"
    
    if [ $active_services -lt $total_services ]; then
        ((issues++))
    fi
    
    # 检查磁盘空间
    local disk_usage=$(df "$SITE_PATH" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        echo -e "磁盘空间: ${GREEN}正常 (${disk_usage}%)${NC}"
    else
        echo -e "磁盘空间: ${RED}不足 (${disk_usage}%)${NC}"
        ((issues++))
    fi
    
    # 检查内存使用
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -lt 90 ]; then
        echo -e "内存使用: ${GREEN}正常 (${memory_usage}%)${NC}"
    else
        echo -e "内存使用: ${RED}过高 (${memory_usage}%)${NC}"
        ((issues++))
    fi
    
    echo
    if [ $issues -eq 0 ]; then
        log_success "健康检查通过，无问题发现"
    else
        log_warning "发现 $issues 个问题，建议检查"
    fi
    
    return $issues
}

# 主程序开始
main() {
    # 检查参数
    if [ $# -lt 2 ]; then
        log_error "参数不足"
        echo
        show_help
        safe_exit 1
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        safe_exit 0
    fi

    SITE_NAME="$1"
    ACTION="$2"
    SITE_PATH="/home/doge/$SITE_NAME"
    VHOST_NAME="/$SITE_NAME"
    USER_NAME="${SITE_NAME}_user"
    PASSWORD=$(generate_password "$SITE_NAME")
    
    # 定义全量消费者列表
    CONSUMERS=(
        "async.operations.all"
        "product_action_attribute.update"
        "product_action_attribute.website.update"
        "catalog_website_attribute_value_sync"
        "media.storage.catalog.image.resize"
        "exportProcessor"
        "inventory.source.items.cleanup"
        "inventory.mass.update"
        "inventory.reservations.cleanup"
        "inventory.reservations.update"
        "inventory.reservations.updateSalabilityStatus"
        "inventory.indexer.sourceItem"
        "inventory.indexer.stock"
        "media.content.synchronization"
        "media.gallery.renditions.update"
        "media.gallery.synchronization"
        "codegeneratorProcessor"
        "sales.rule.update.coupon.usage"
        "sales.rule.quote.trigger.recollect"
        "product_alert"
        "saveConfigProcessor"
    )

    # 获取锁
    acquire_lock
    
    # 设置退出时清理
    trap 'cleanup_lock' EXIT

    # 验证输入
    if ! validate_input; then
        safe_exit 1
    fi

    # 检查依赖
    if ! check_dependencies; then
        safe_exit 1
    fi

    # 验证站点目录
    if [ ! -d "$SITE_PATH" ]; then
        log_error "站点目录不存在: $SITE_PATH"
        safe_exit 1
    fi

    # 验证 Magento 安装
    if [ ! -f "$SITE_PATH/bin/magento" ]; then
        log_error "Magento 安装文件不存在: $SITE_PATH/bin/magento"
        safe_exit 1
    fi

    # 检查权限
    if ! check_permissions; then
        safe_exit 1
    fi

    # 执行操作
    case "$ACTION" in
        "setup")
            setup_site
            ;;
        "start")
            start_consumers
            ;;
        "stop")
            stop_consumers
            ;;
        "restart")
            restart_consumers
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "monitor")
            monitor_services
            ;;
        "clean")
            clean_queues
            ;;
        "remove")
            remove_site
            ;;
        "health")
            health_check
            ;;
        *)
            log_error "未知操作: $ACTION"
            echo
            show_help
            safe_exit 1
            ;;
    esac
    
    safe_exit 0
}

# 配置站点
setup_site() {
    log_info "开始配置 RabbitMQ 高级站点: $SITE_NAME"
    log_info "站点路径: $SITE_PATH"
    log_info "虚拟主机: $VHOST_NAME"
    log_info "用户: $USER_NAME"
    echo

    if ! check_rabbitmq_service; then
        safe_exit 1
    fi

    # 1. 创建虚拟主机
    log_info "创建 RabbitMQ 虚拟主机..."
    if safe_rabbitmq_cmd "list_vhosts" | grep -q "^$VHOST_NAME$"; then
        log_warning "虚拟主机 $VHOST_NAME 已存在"
    else
        if safe_rabbitmq_cmd "add_vhost '$VHOST_NAME'"; then
            log_success "虚拟主机 $VHOST_NAME 创建成功"
        else
            log_error "创建虚拟主机失败"
            safe_exit 1
        fi
    fi

    # 2. 创建用户
    log_info "创建 RabbitMQ 用户..."
    if safe_rabbitmq_cmd "list_users" | grep -q "^$USER_NAME"; then
        log_warning "用户 $USER_NAME 已存在，更新密码..."
        if safe_rabbitmq_cmd "change_password '$USER_NAME' '$PASSWORD'"; then
            log_success "用户密码已更新"
        else
            log_error "更新用户密码失败"
            safe_exit 1
        fi
    else
        if safe_rabbitmq_cmd "add_user '$USER_NAME' '$PASSWORD'"; then
            log_success "用户 $USER_NAME 创建成功"
        else
            log_error "创建用户失败"
            safe_exit 1
        fi
    fi

    # 3. 设置权限
    log_info "设置用户权限..."
    if safe_rabbitmq_cmd "set_permissions -p '$VHOST_NAME' '$USER_NAME' '.*' '.*' '.*'"; then
        log_success "用户权限设置完成"
    else
        log_error "设置用户权限失败"
        safe_exit 1
    fi

    # 4. 停止现有消费者
    log_info "停止现有队列消费者..."
    pkill -f "queue:consumers:start.*$SITE_NAME" || true
    sleep 2

    # 5. 配置 Magento AMQP
    log_info "配置 Magento AMQP 连接..."
    cd "$SITE_PATH" || {
        log_error "无法切换到站点目录: $SITE_PATH"
        safe_exit 1
    }

    # 检查 AMQP 是否已经配置
    if grep -q "amqp" app/etc/env.php 2>/dev/null; then
        log_info "检测到 AMQP 已配置，跳过配置步骤"
        log_success "AMQP 配置已存在"
    else
        log_info "配置 Magento AMQP 连接（带超时保护）..."
        
        # 使用 timeout 命令防止卡住
        if timeout 30 php bin/magento setup:config:set \
            --amqp-host="127.0.0.1" \
            --amqp-port=5672 \
            --amqp-user="$USER_NAME" \
            --amqp-password="$PASSWORD" \
            --amqp-virtualhost="$VHOST_NAME" \
            --skip-db-validation 2>/dev/null; then
            log_success "AMQP 配置完成"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                log_warning "AMQP 配置超时，跳过此步骤"
            else
                log_warning "AMQP 配置失败（退出码: $exit_code），跳过此步骤"
            fi
        fi
    fi

    # 6. 修复权限（使用超高性能方法）
    fix_permissions_fast "$SITE_PATH"

    # 7. 清理缓存
    log_info "清理 Magento 缓存..."
    if php bin/magento cache:flush; then
        log_success "缓存清理完成"
    else
        log_warning "缓存清理失败，继续执行"
    fi

    # 8. 编译依赖注入
    log_info "编译依赖注入..."
    if php -d memory_limit=2G bin/magento setup:di:compile; then
        log_success "依赖注入编译完成"
    else
        log_warning "依赖注入编译失败，继续执行"
    fi

    # 9. 创建 systemd 服务
    log_info "创建 systemd 消费者服务..."
    for consumer in "${CONSUMERS[@]}"; do
        create_systemd_service "$consumer"
    done

    # 10. 启动所有消费者服务
    log_info "启动所有消费者服务..."
    start_consumers

    # 11. 等待服务启动
    log_info "等待服务启动..."
    sleep 5

    # 12. 显示队列状态
    log_info "显示队列状态..."
    safe_rabbitmq_cmd "list_queues -p '$VHOST_NAME' name consumers messages_ready messages_unacknowledged"

    # 13. 显示配置摘要
    echo
    log_success "🎉 RabbitMQ 高级配置完成！"
    echo
    echo -e "${YELLOW}📋 配置摘要:${NC}"
    echo -e "  站点名称: ${CYAN}$SITE_NAME${NC}"
    echo -e "  站点路径: ${CYAN}$SITE_PATH${NC}"
    echo -e "  虚拟主机: ${CYAN}$VHOST_NAME${NC}"
    echo -e "  用户名: ${CYAN}$USER_NAME${NC}"
    echo -e "  密码: ${CYAN}$PASSWORD${NC}"
    echo
    echo -e "${YELLOW}🔧 管理命令:${NC}"
    echo -e "  查看队列状态: ${CYAN}sudo rabbitmqctl list_queues -p $VHOST_NAME${NC}"
    echo -e "  停止消费者: ${CYAN}./rabbitmq_manager_advanced.sh $SITE_NAME stop${NC}"
    echo -e "  查看日志: ${CYAN}./rabbitmq_manager_advanced.sh $SITE_NAME logs${NC}"
    echo -e "  监控服务: ${CYAN}./rabbitmq_manager_advanced.sh $SITE_NAME monitor${NC}"
    echo
    echo -e "${YELLOW}📊 高级配置特性:${NC}"
    echo -e "  管理方式: ${CYAN}systemd${NC} (企业级服务管理)"
    echo -e "  消费者总数: ${CYAN}${#CONSUMERS[@]}个${NC} (全量 Magento2 消费者)"
    echo -e "  消息处理量: ${CYAN}1000个/次${NC}"
    echo -e "  运行模式: ${CYAN}双线程${NC} (CPUQuota=200%)"
    echo -e "  内存限制: ${CYAN}2GB/服务${NC}"
    echo -e "  权限修复: ${CYAN}超高性能模式${NC} (16并行+2000批处理)"
    echo -e "  自动重启: ${CYAN}是${NC} (Restart=always)"
    echo -e "  日志管理: ${CYAN}systemd journal${NC}"
}

# 启动消费者
start_consumers() {
    log_info "启动 $SITE_NAME 的所有消费者服务..."
    
    if ! check_rabbitmq_service; then
        safe_exit 1
    fi
    
    local started_count=0
    local failed_count=0
    
    for consumer in "${CONSUMERS[@]}"; do
        if start_systemd_consumer "$consumer"; then
            ((started_count++))
        else
            ((failed_count++))
        fi
    done
    
    echo
    log_success "消费者服务启动完成: $started_count 成功, $failed_count 失败"
}

# 停止消费者
stop_consumers() {
    log_info "停止 $SITE_NAME 的所有消费者服务..."
    
    local stopped_count=0
    local failed_count=0
    
    for consumer in "${CONSUMERS[@]}"; do
        if stop_systemd_consumer "$consumer"; then
            ((stopped_count++))
        else
            ((failed_count++))
        fi
    done
    
    echo
    log_success "消费者服务停止完成: $stopped_count 成功, $failed_count 失败"
}

# 重启消费者
restart_consumers() {
    log_info "重启 $SITE_NAME 的所有消费者服务..."
    stop_consumers
    sleep 3
    start_consumers
}

# 查看状态
show_status() {
    log_info "查看 $SITE_NAME 的消费者服务状态..."
    
    echo
    echo -e "${CYAN}=== systemd 服务状态 ===${NC}"
    
    local active_count=0
    local inactive_count=0
    
    for consumer in "${CONSUMERS[@]}"; do
        local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer}"
        local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
        
        if [ "$status" = "active" ]; then
            echo -e "$service_name: ${GREEN}运行中${NC}"
            ((active_count++))
        else
            echo -e "$service_name: ${RED}未运行${NC}"
            ((inactive_count++))
        fi
    done
    
    echo
    echo -e "${CYAN}=== 服务统计 ===${NC}"
    echo -e "运行中: ${GREEN}$active_count${NC}"
    echo -e "未运行: ${RED}$inactive_count${NC}"
    echo -e "总计: ${CYAN}${#CONSUMERS[@]}${NC}"
    
    echo
    echo -e "${CYAN}=== 队列状态 ===${NC}"
    safe_rabbitmq_cmd "list_queues -p '$VHOST_NAME' name consumers messages_ready messages_unacknowledged"
    
    echo
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo -e "虚拟主机: ${CYAN}$VHOST_NAME${NC}"
    echo -e "用户名: ${CYAN}$USER_NAME${NC}"
    echo -e "密码: ${CYAN}$PASSWORD${NC}"
    echo -e "站点路径: ${CYAN}$SITE_PATH${NC}"
}

# 查看日志
show_logs() {
    log_info "查看 $SITE_NAME 的消费者服务日志..."
    
    echo
    echo -e "${CYAN}=== 最近的服务日志 ===${NC}"
    
    for consumer in "${CONSUMERS[@]}"; do
        local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer}"
        
        echo -e "\n${YELLOW}$service_name:${NC}"
        sudo journalctl -u "$service_name" --no-pager -n 10 --since "1 hour ago" 2>/dev/null || echo "无日志"
    done
}

# 监控服务
monitor_services() {
    log_info "监控 $SITE_NAME 的消费者服务状态..."
    
    echo
    echo -e "${CYAN}=== 服务监控 ===${NC}"
    echo -e "按 Ctrl+C 停止监控"
    echo
    
    while true; do
        local active_count=0
        local inactive_count=0
        
        for consumer in "${CONSUMERS[@]}"; do
            local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer}"
            local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
            
            if [ "$status" = "active" ]; then
                ((active_count++))
            else
                ((inactive_count++))
            fi
        done
        
        echo -e "$(date '+%H:%M:%S') - 运行中: ${GREEN}$active_count${NC}, 未运行: ${RED}$inactive_count${NC}, 总计: ${CYAN}${#CONSUMERS[@]}${NC}"
        
        sleep 10
    done
}

# 清理队列
clean_queues() {
    log_info "清理 $SITE_NAME 的队列..."
    
    echo -e "${YELLOW}警告: 这将清空所有队列消息！${NC}"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for consumer in "${CONSUMERS[@]}"; do
            safe_rabbitmq_cmd "purge_queue -p '$VHOST_NAME' $consumer" || true
        done
        log_success "队列已清理"
    else
        log_info "操作已取消"
    fi
}

# 删除站点配置
remove_site() {
    log_info "删除 $SITE_NAME 的 RabbitMQ 配置和服务..."
    
    echo -e "${YELLOW}警告: 这将删除虚拟主机、用户、所有相关配置和 systemd 服务！${NC}"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 停止所有消费者服务
        stop_consumers
        
        # 删除 systemd 服务
        log_info "删除 systemd 服务..."
        for consumer in "${CONSUMERS[@]}"; do
            local service_name="${SYSTEMD_SERVICE_PREFIX}-${SITE_NAME}-${consumer}"
            local service_file="/etc/systemd/system/${service_name}.service"
            
            sudo systemctl disable "$service_name" 2>/dev/null || true
            sudo systemctl stop "$service_name" 2>/dev/null || true
            sudo rm -f "$service_file"
        done
        
        # 重新加载 systemd
        sudo systemctl daemon-reload
        
        # 删除虚拟主机
        if safe_rabbitmq_cmd "list_vhosts" | grep -q "^$VHOST_NAME$"; then
            safe_rabbitmq_cmd "delete_vhost '$VHOST_NAME'"
            log_success "虚拟主机 $VHOST_NAME 已删除"
        fi
        
        # 删除用户
        if safe_rabbitmq_cmd "list_users" | grep -q "^$USER_NAME"; then
            safe_rabbitmq_cmd "delete_user '$USER_NAME'"
            log_success "用户 $USER_NAME 已删除"
        fi
        
        # 清理文件
        rm -f "$LOCK_FILE"
        
        log_success "站点配置和服务已完全删除"
    else
        log_info "操作已取消"
    fi
}

# 执行主程序
main "$@"
