#!/bin/bash

# RabbitMQ 站点配置脚本
# 用于为 Magento 站点配置 RabbitMQ 虚拟主机、用户和队列消费者
# 作者: Ansible LEMP Project
# 版本: 1.0.0

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
    echo -e "${CYAN}RabbitMQ 站点配置脚本${NC}"
    echo
    echo -e "${YELLOW}功能:${NC}"
    echo -e "  • 为 Magento 站点创建 RabbitMQ 虚拟主机"
    echo -e "  • 创建专用用户和权限配置"
    echo -e "  • 配置 Magento AMQP 连接"
    echo -e "  • 启动优化的队列消费者"
    echo -e "  • 内存和性能优化"
    echo
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./rabbitmq_config.sh <site_name>${NC}"
    echo -e "  ${CYAN}./rabbitmq_config.sh ipwa${NC}"
    echo -e "  ${CYAN}./rabbitmq_config.sh hawk${NC}"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}./rabbitmq_config.sh ipwa${NC}    # 配置 ipwa 站点"
    echo -e "  ${CYAN}./rabbitmq_config.sh hawk${NC}   # 配置 hawk 站点"
    echo
    echo -e "${YELLOW}站点路径格式:${NC}"
    echo -e "  ${CYAN}/home/doge/<site_name>${NC}"
    echo
}

# 检查参数
if [ $# -eq 0 ]; then
    log_error "请提供站点名称"
    echo
    show_help
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# 获取站点名称
SITE_NAME="$1"
SITE_PATH="/home/doge/$SITE_NAME"
VHOST_NAME="/$SITE_NAME"
USER_NAME="${SITE_NAME}_user"
PASSWORD="${SITE_NAME^}#2025!"

# 验证站点目录是否存在
if [ ! -d "$SITE_PATH" ]; then
    log_error "站点目录不存在: $SITE_PATH"
    exit 1
fi

# 验证 Magento 安装
if [ ! -f "$SITE_PATH/bin/magento" ]; then
    log_error "Magento 安装文件不存在: $SITE_PATH/bin/magento"
    exit 1
fi

log_info "开始配置 RabbitMQ 站点: $SITE_NAME"
log_info "站点路径: $SITE_PATH"
log_info "虚拟主机: $VHOST_NAME"
log_info "用户: $USER_NAME"
echo

# 检查 RabbitMQ 服务状态
if ! systemctl is-active --quiet rabbitmq-server; then
    log_error "RabbitMQ 服务未运行，请先启动 RabbitMQ"
    exit 1
fi

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

# 8. 启动队列消费者（优化版本）
log_info "启动优化的队列消费者..."

# 创建消费者管理脚本
CONSUMER_SCRIPT="/tmp/rabbitmq_consumers_${SITE_NAME}.sh"
cat > "$CONSUMER_SCRIPT" << EOF
#!/bin/bash
# RabbitMQ 消费者管理脚本 - $SITE_NAME
# 自动生成于: $(date)

SITE_PATH="$SITE_PATH"
SITE_NAME="$SITE_NAME"
LOG_DIR="/home/doge/logs/rabbitmq"

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

# 启动消费者管理脚本
nohup "$CONSUMER_SCRIPT" >/dev/null 2>&1 &
CONSUMER_PID=$!

# 保存 PID 到文件
echo "$CONSUMER_PID" > "/tmp/rabbitmq_consumers_${SITE_NAME}.pid"

log_success "队列消费者启动完成 (PID: $CONSUMER_PID)"

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
echo -e "  消费者 PID: ${CYAN}$CONSUMER_PID${NC}"
echo
echo -e "${YELLOW}🔧 管理命令:${NC}"
echo -e "  查看队列状态: ${CYAN}sudo rabbitmqctl list_queues -p $VHOST_NAME${NC}"
echo -e "  停止消费者: ${CYAN}kill \$(cat /tmp/rabbitmq_consumers_${SITE_NAME}.pid)${NC}"
echo -e "  查看日志: ${CYAN}tail -f /home/doge/logs/rabbitmq/${SITE_NAME}_*.log${NC}"
echo -e "  重启消费者: ${CYAN}$CONSUMER_SCRIPT${NC}"
echo
echo -e "${YELLOW}📊 监控:${NC}"
echo -e "  内存监控: ${CYAN}/home/doge/logs/rabbitmq/${SITE_NAME}_memory.log${NC}"
echo -e "  消费者日志: ${CYAN}/home/doge/logs/rabbitmq/${SITE_NAME}_*.log${NC}"
echo
