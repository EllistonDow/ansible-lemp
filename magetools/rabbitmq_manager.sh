#!/bin/bash

# RabbitMQ 站点管理脚本
# 用于配置和管理 Magento 站点的 RabbitMQ 虚拟主机、用户和队列消费者
# 作者: Ansible LEMP Project
# 版本: 2.0.0

set -e

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

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}RabbitMQ 站点管理脚本${NC}"
    echo
    echo -e "${YELLOW}功能:${NC}"
    echo -e "  • 配置 Magento 站点的 RabbitMQ 虚拟主机和用户"
    echo -e "  • 启动/停止/重启队列消费者"
    echo -e "  • 查看消费者状态和日志"
    echo -e "  • 监控内存使用情况"
    echo -e "  • 清理队列和日志"
    echo
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh <site_name> <action>${NC}"
    echo
    echo -e "${YELLOW}操作:${NC}"
    echo -e "  ${CYAN}setup${NC}     - 配置站点 (创建虚拟主机、用户、配置 Magento)"
    echo -e "  ${CYAN}start${NC}      - 启动消费者"
    echo -e "  ${CYAN}stop${NC}       - 停止消费者"
    echo -e "  ${CYAN}restart${NC}    - 重启消费者"
    echo -e "  ${CYAN}status${NC}     - 查看状态"
    echo -e "  ${CYAN}logs${NC}       - 查看日志"
    echo -e "  ${CYAN}monitor${NC}    - 监控内存"
    echo -e "  ${CYAN}clean${NC}      - 清理队列"
    echo -e "  ${CYAN}remove${NC}     - 删除站点配置"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa setup${NC}    # 配置 ipwa 站点"
    echo -e "  ${CYAN}./rabbitmq_manager.sh hawk start${NC}    # 启动 hawk 消费者"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa status${NC}   # 查看 ipwa 状态"
    echo -e "  ${CYAN}./rabbitmq_manager.sh hawk logs${NC}     # 查看 hawk 日志"
    echo
    echo -e "${YELLOW}站点路径格式:${NC}"
    echo -e "  ${CYAN}/home/doge/<site_name>${NC}"
    echo
}

# 检查参数
if [ $# -lt 2 ]; then
    log_error "参数不足"
    echo
    show_help
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

SITE_NAME="$1"
ACTION="$2"
SITE_PATH="/home/doge/$SITE_NAME"
VHOST_NAME="/$SITE_NAME"
USER_NAME="${SITE_NAME}_user"
PASSWORD="${SITE_NAME^}#2025!"
PID_FILE="/tmp/rabbitmq_consumers_${SITE_NAME}.pid"
LOG_DIR="/home/doge/logs/rabbitmq"

# 验证站点目录
if [ ! -d "$SITE_PATH" ]; then
    log_error "站点目录不存在: $SITE_PATH"
    exit 1
fi

# 验证 Magento 安装
if [ ! -f "$SITE_PATH/bin/magento" ]; then
    log_error "Magento 安装文件不存在: $SITE_PATH/bin/magento"
    exit 1
fi

# 检查 RabbitMQ 服务状态
check_rabbitmq_service() {
    if ! systemctl is-active --quiet rabbitmq-server; then
        log_error "RabbitMQ 服务未运行，请先启动 RabbitMQ"
        log_info "启动命令: sudo systemctl start rabbitmq-server"
        exit 1
    fi
}

# 配置站点
setup_site() {
    log_info "开始配置 RabbitMQ 站点: $SITE_NAME"
    log_info "站点路径: $SITE_PATH"
    log_info "虚拟主机: $VHOST_NAME"
    log_info "用户: $USER_NAME"
    echo

    check_rabbitmq_service

    # 1. 创建虚拟主机
    log_info "创建 RabbitMQ 虚拟主机..."
    if sudo rabbitmqctl list_vhosts | grep -q "^$VHOST_NAME$"; then
        log_warning "虚拟主机 $VHOST_NAME 已存在"
    else
        sudo rabbitmqctl add_vhost "$VHOST_NAME"
        log_success "虚拟主机 $VHOST_NAME 创建成功"
    fi

    # 2. 创建用户
    log_info "创建 RabbitMQ 用户..."
    if sudo rabbitmqctl list_users | grep -q "^$USER_NAME"; then
        log_warning "用户 $USER_NAME 已存在，更新密码..."
        sudo rabbitmqctl change_password "$USER_NAME" "$PASSWORD"
    else
        sudo rabbitmqctl add_user "$USER_NAME" "$PASSWORD"
        log_success "用户 $USER_NAME 创建成功"
    fi

    # 3. 设置权限
    log_info "设置用户权限..."
    sudo rabbitmqctl set_permissions -p "$VHOST_NAME" "$USER_NAME" ".*" ".*" ".*"
    log_success "用户权限设置完成"

    # 4. 停止现有消费者
    log_info "停止现有队列消费者..."
    pkill -f "queue:consumers:start.*$SITE_NAME" || true
    sleep 2

    # 5. 配置 Magento AMQP
    log_info "配置 Magento AMQP 连接..."
    cd "$SITE_PATH"

    php -d detect_unicode=0 bin/magento setup:config:set \
        --amqp-host="127.0.0.1" \
        --amqp-port=5672 \
        --amqp-user="$USER_NAME" \
        --amqp-password="$PASSWORD" \
        --amqp-virtualhost="$VHOST_NAME"

    log_success "AMQP 配置完成"

    # 6. 清理缓存
    log_info "清理 Magento 缓存..."
    php -d detect_unicode=0 bin/magento cache:flush
    log_success "缓存清理完成"

    # 7. 编译依赖注入
    log_info "编译依赖注入..."
    php -d memory_limit=2G -d detect_unicode=0 bin/magento setup:di:compile
    log_success "依赖注入编译完成"

    # 8. 启动队列消费者
    log_info "启动优化的队列消费者..."
    start_consumers_internal

    # 9. 等待消费者启动
    log_info "等待消费者启动..."
    sleep 5

    # 10. 显示队列状态
    log_info "显示队列状态..."
    sudo rabbitmqctl list_queues -p "$VHOST_NAME" name consumers messages_ready messages_unacknowledged

    # 11. 显示配置摘要
    echo
    log_success "🎉 RabbitMQ 配置完成！"
    echo
    echo -e "${YELLOW}📋 配置摘要:${NC}"
    echo -e "  站点名称: ${CYAN}$SITE_NAME${NC}"
    echo -e "  站点路径: ${CYAN}$SITE_PATH${NC}"
    echo -e "  虚拟主机: ${CYAN}$VHOST_NAME${NC}"
    echo -e "  用户名: ${CYAN}$USER_NAME${NC}"
    echo -e "  密码: ${CYAN}$PASSWORD${NC}"
    echo -e "  消费者 PID: ${CYAN}$(cat "$PID_FILE" 2>/dev/null || echo 'N/A')${NC}"
    echo
    echo -e "${YELLOW}🔧 管理命令:${NC}"
    echo -e "  查看队列状态: ${CYAN}sudo rabbitmqctl list_queues -p $VHOST_NAME${NC}"
    echo -e "  停止消费者: ${CYAN}./rabbitmq_manager.sh $SITE_NAME stop${NC}"
    echo -e "  查看日志: ${CYAN}./rabbitmq_manager.sh $SITE_NAME logs${NC}"
    echo -e "  监控内存: ${CYAN}./rabbitmq_manager.sh $SITE_NAME monitor${NC}"
    echo
}

# 启动消费者（内部函数）
start_consumers_internal() {
    # 创建消费者管理脚本
    CONSUMER_SCRIPT="/tmp/rabbitmq_consumers_${SITE_NAME}.sh"
    cat > "$CONSUMER_SCRIPT" << EOF
#!/bin/bash
# RabbitMQ 消费者管理脚本 - $SITE_NAME
# 自动生成于: $(date)

SITE_PATH="$SITE_PATH"
SITE_NAME="$SITE_NAME"
LOG_DIR="$LOG_DIR"

# 创建日志目录
mkdir -p "\$LOG_DIR"

# 内存监控函数
monitor_memory() {
    local pid=\$1
    local consumer_name=\$2
    
    # 根据系统总内存动态调整监控阈值
    local total_memory_gb=\$(free -g | grep Mem | awk '{print \$2}')
    local max_memory_kb
    
    if [ "\$total_memory_gb" -ge 128 ]; then
        max_memory_kb=4194304  # 4GB for 128GB+ servers
    elif [ "\$total_memory_gb" -ge 64 ]; then
        max_memory_kb=2097152  # 2GB for 64GB+ servers
    else
        max_memory_kb=1048576  # 1GB for smaller servers
    fi
    
    while kill -0 \$pid 2>/dev/null; do
        local memory=\$(ps -o rss= -p \$pid 2>/dev/null | tr -d ' ')
        if [ -n "\$memory" ] && [ \$memory -gt \$max_memory_kb ]; then
            echo "\$(date): \$consumer_name 内存使用过高 (\${memory}KB)，重启消费者" >> "\$LOG_DIR/\${SITE_NAME}_memory.log"
            kill \$pid
            return 1
        fi
        sleep 30
    done
    return 0
}

# 启动消费者函数
start_consumer() {
    local consumer_name=\$1
    local max_messages=\${2:-1000}
    
    while true; do
        echo "\$(date): 启动消费者 \$consumer_name" >> "\$LOG_DIR/\${SITE_NAME}_\${consumer_name}.log"
        
        cd "\$SITE_PATH"
        php -d memory_limit=1G -d detect_unicode=0 bin/magento queue:consumers:start "\$consumer_name" --max-messages=\$max_messages --single-thread &
        local pid=\$!
        
        # 监控内存使用
        monitor_memory \$pid "\$consumer_name"
        
        # 等待进程结束
        wait \$pid
        local exit_code=\$?
        
        echo "\$(date): 消费者 \$consumer_name 退出，退出码: \$exit_code" >> "\$LOG_DIR/\${SITE_NAME}_\${consumer_name}.log"
        
        # 如果正常退出，等待5秒后重启
        if [ \$exit_code -eq 0 ]; then
            sleep 5
        else
            # 异常退出，等待30秒后重启
            sleep 30
        fi
    done
}

# 启动主要消费者
start_consumer "async.operations.all" 1000 &
start_consumer "product_action_attribute.update" 500 &

# 等待所有后台进程
wait
EOF

    chmod +x "$CONSUMER_SCRIPT"
    
    # 启动消费者管理脚本
    nohup "$CONSUMER_SCRIPT" >/dev/null 2>&1 &
    CONSUMER_PID=$!
    echo "$CONSUMER_PID" > "$PID_FILE"
    
    log_success "队列消费者启动完成 (PID: $CONSUMER_PID)"
}

# 启动消费者
start_consumers() {
    log_info "启动 $SITE_NAME 的队列消费者..."
    
    check_rabbitmq_service
    
    # 检查是否已经在运行
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_warning "消费者已经在运行 (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    start_consumers_internal
}

# 停止消费者
stop_consumers() {
    log_info "停止 $SITE_NAME 的队列消费者..."
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            sleep 2
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID"
            fi
            log_success "消费者已停止 (PID: $PID)"
        else
            log_warning "消费者进程不存在"
        fi
        rm -f "$PID_FILE"
    else
        log_warning "PID 文件不存在"
    fi
    
    # 清理相关进程
    pkill -f "queue:consumers:start.*$SITE_NAME" || true
}

# 重启消费者
restart_consumers() {
    log_info "重启 $SITE_NAME 的队列消费者..."
    stop_consumers
    sleep 3
    start_consumers
}

# 查看状态
show_status() {
    log_info "查看 $SITE_NAME 的消费者状态..."
    
    echo
    echo -e "${CYAN}=== 进程状态 ===${NC}"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "消费者进程: ${GREEN}运行中${NC} (PID: $PID)"
            echo -e "内存使用: $(ps -o rss= -p "$PID" | tr -d ' ') KB"
        else
            echo -e "消费者进程: ${RED}已停止${NC}"
        fi
    else
        echo -e "消费者进程: ${RED}未启动${NC}"
    fi
    
    echo
    echo -e "${CYAN}=== 队列状态 ===${NC}"
    sudo rabbitmqctl list_queues -p "$VHOST_NAME" name consumers messages_ready messages_unacknowledged
    
    echo
    echo -e "${CYAN}=== 相关进程 ===${NC}"
    ps aux | grep "queue:consumers:start.*$SITE_NAME" | grep -v grep || echo "无相关进程"
    
    echo
    echo -e "${CYAN}=== 配置信息 ===${NC}"
    echo -e "虚拟主机: ${CYAN}$VHOST_NAME${NC}"
    echo -e "用户名: ${CYAN}$USER_NAME${NC}"
    echo -e "密码: ${CYAN}$PASSWORD${NC}"
    echo -e "站点路径: ${CYAN}$SITE_PATH${NC}"
}

# 查看日志
show_logs() {
    log_info "查看 $SITE_NAME 的消费者日志..."
    
    if [ ! -d "$LOG_DIR" ]; then
        log_warning "日志目录不存在: $LOG_DIR"
        return 1
    fi
    
    echo
    echo -e "${CYAN}=== 内存监控日志 ===${NC}"
    if [ -f "$LOG_DIR/${SITE_NAME}_memory.log" ]; then
        tail -20 "$LOG_DIR/${SITE_NAME}_memory.log"
    else
        echo "无内存监控日志"
    fi
    
    echo
    echo -e "${CYAN}=== 消费者日志 ===${NC}"
    for log_file in "$LOG_DIR"/${SITE_NAME}_*.log; do
        if [ -f "$log_file" ]; then
            echo -e "\n${YELLOW}$(basename "$log_file"):${NC}"
            tail -10 "$log_file"
        fi
    done
}

# 监控内存
monitor_memory() {
    log_info "监控 $SITE_NAME 的消费者内存使用..."
    
    if [ ! -f "$PID_FILE" ]; then
        log_error "消费者未启动"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    if ! kill -0 "$PID" 2>/dev/null; then
        log_error "消费者进程不存在"
        return 1
    fi
    
    echo
    echo -e "${CYAN}=== 内存监控 ===${NC}"
    echo -e "PID: $PID"
    echo -e "按 Ctrl+C 停止监控"
    echo
    
    while true; do
        memory=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
        if [ -n "$memory" ]; then
            memory_mb=$((memory / 1024))
            echo -e "$(date '+%H:%M:%S') - 内存使用: ${memory_mb}MB (${memory}KB)"
        else
            echo -e "$(date '+%H:%M:%S') - 进程已停止"
            break
        fi
        sleep 5
    done
}

# 清理队列
clean_queues() {
    log_info "清理 $SITE_NAME 的队列..."
    
    echo -e "${YELLOW}警告: 这将清空所有队列消息！${NC}"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rabbitmqctl purge_queue -p "$VHOST_NAME" async.operations.all
        sudo rabbitmqctl purge_queue -p "$VHOST_NAME" product_action_attribute.update
        log_success "队列已清理"
    else
        log_info "操作已取消"
    fi
}

# 删除站点配置
remove_site() {
    log_info "删除 $SITE_NAME 的 RabbitMQ 配置..."
    
    echo -e "${YELLOW}警告: 这将删除虚拟主机、用户和所有相关配置！${NC}"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 停止消费者
        stop_consumers
        
        # 删除虚拟主机
        if sudo rabbitmqctl list_vhosts | grep -q "^$VHOST_NAME$"; then
            sudo rabbitmqctl delete_vhost "$VHOST_NAME"
            log_success "虚拟主机 $VHOST_NAME 已删除"
        fi
        
        # 删除用户
        if sudo rabbitmqctl list_users | grep -q "^$USER_NAME"; then
            sudo rabbitmqctl delete_user "$USER_NAME"
            log_success "用户 $USER_NAME 已删除"
        fi
        
        # 清理文件
        rm -f "$PID_FILE"
        rm -f "/tmp/rabbitmq_consumers_${SITE_NAME}.sh"
        
        # 清理日志
        if [ -d "$LOG_DIR" ]; then
            rm -f "$LOG_DIR"/${SITE_NAME}_*.log
            log_success "日志文件已清理"
        fi
        
        log_success "站点配置已完全删除"
    else
        log_info "操作已取消"
    fi
}

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
        monitor_memory
        ;;
    "clean")
        clean_queues
        ;;
    "remove")
        remove_site
        ;;
    *)
        log_error "未知操作: $ACTION"
        echo
        show_help
        exit 1
        ;;
esac