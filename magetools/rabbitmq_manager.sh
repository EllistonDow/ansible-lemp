#!/bin/bash

# RabbitMQ 消费者管理脚本
# 用于管理 Magento 站点的 RabbitMQ 队列消费者
# 作者: Ansible LEMP Project
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "${CYAN}RabbitMQ 消费者管理脚本${NC}"
    echo
    echo -e "${YELLOW}功能:${NC}"
    echo -e "  • 启动/停止/重启队列消费者"
    echo -e "  • 查看消费者状态和日志"
    echo -e "  • 监控内存使用情况"
    echo -e "  • 清理队列和日志"
    echo
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh <site_name> <action>${NC}"
    echo
    echo -e "${YELLOW}操作:${NC}"
    echo -e "  ${CYAN}start${NC}     - 启动消费者"
    echo -e "  ${CYAN}stop${NC}      - 停止消费者"
    echo -e "  ${CYAN}restart${NC}   - 重启消费者"
    echo -e "  ${CYAN}status${NC}    - 查看状态"
    echo -e "  ${CYAN}logs${NC}      - 查看日志"
    echo -e "  ${CYAN}monitor${NC}   - 监控内存"
    echo -e "  ${CYAN}clean${NC}     - 清理队列"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa start${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh hawk status${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa logs${NC}"
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
PID_FILE="/tmp/rabbitmq_consumers_${SITE_NAME}.pid"
LOG_DIR="/home/doge/logs/rabbitmq"

# 验证站点目录
if [ ! -d "$SITE_PATH" ]; then
    log_error "站点目录不存在: $SITE_PATH"
    exit 1
fi

# 启动消费者
start_consumers() {
    log_info "启动 $SITE_NAME 的队列消费者..."
    
    # 检查是否已经在运行
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_warning "消费者已经在运行 (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    # 创建消费者脚本
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
    local max_memory=512000  # 512MB
    
    while kill -0 \$pid 2>/dev/null; do
        local memory=\$(ps -o rss= -p \$pid 2>/dev/null | tr -d ' ')
        if [ -n "\$memory" ] && [ \$memory -gt \$max_memory ]; then
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
    
    # 启动消费者
    nohup "$CONSUMER_SCRIPT" >/dev/null 2>&1 &
    CONSUMER_PID=$!
    echo "$CONSUMER_PID" > "$PID_FILE"
    
    log_success "消费者启动成功 (PID: $CONSUMER_PID)"
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

# 执行操作
case "$ACTION" in
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
    *)
        log_error "未知操作: $ACTION"
        echo
        show_help
        exit 1
        ;;
esac
