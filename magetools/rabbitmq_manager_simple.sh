#!/bin/bash
# RabbitMQ 管理器 - 简化版本
# 结合了用户脚本的优点和我们的功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
SITE_NAME="${1:-sava}"
VHOST="/${SITE_NAME}"
USER="${SITE_NAME}_user"
PASS="${SITE_NAME^}#2025!"
SITE_DIR="/home/doge/${SITE_NAME}"
PID_FILE="/tmp/rabbitmq_${SITE_NAME}.pid"

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

# 检查站点目录
if [[ ! -d "$SITE_DIR" ]]; then
    log_error "站点目录不存在: $SITE_DIR"
    exit 1
fi

log_info "开始配置 RabbitMQ 站点: $SITE_NAME"
log_info "站点路径: $SITE_DIR"
log_info "虚拟主机: $VHOST"
log_info "用户: $USER"

# 1. RabbitMQ 配置
log_info "配置 RabbitMQ..."

# 创建虚拟主机
if sudo rabbitmqctl list_vhosts | grep -q "^${VHOST}$"; then
    log_warning "虚拟主机 $VHOST 已存在"
else
    sudo rabbitmqctl add_vhost "$VHOST"
    log_success "虚拟主机 $VHOST 创建成功"
fi

# 创建用户
if sudo rabbitmqctl list_users | grep -q "^${USER}"; then
    log_warning "用户 $USER 已存在，更新密码..."
    sudo rabbitmqctl change_password "$USER" "$PASS"
else
    sudo rabbitmqctl add_user "$USER" "$PASS"
    log_success "用户 $USER 创建成功"
fi

# 设置权限
sudo rabbitmqctl set_permissions -p "$VHOST" "$USER" ".*" ".*" ".*"
log_success "用户权限设置完成"

# 2. Magento AMQP 配置
log_info "配置 Magento AMQP 连接..."
cd "$SITE_DIR"

if grep -q "amqp" app/etc/env.php 2>/dev/null; then
    log_info "检测到 AMQP 已配置，跳过配置步骤"
else
    php bin/magento setup:config:set \
        --amqp-host="127.0.0.1" \
        --amqp-port=5672 \
        --amqp-user="$USER" \
        --amqp-password="$PASS" \
        --amqp-virtualhost="$VHOST" \
        --skip-db-validation
    log_success "AMQP 配置完成"
fi

# 3. 权限修复（使用高性能方法）
log_info "修复 Magento 权限（高性能模式）..."

# 性能配置
MAX_PARALLEL_JOBS=8
BATCH_SIZE=1000

# 切换到网站目录
cd "$SITE_DIR"

# 1. 批量设置所有者和组（一次性处理整个目录）
sudo chown -R "$(whoami):www-data" .

# 2. 并行设置基础权限（755/644）
find . -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 755 2>/dev/null || true
find . -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 644 2>/dev/null || true

# 3. 并行设置可写目录权限（775/664 + setgid）
writable_dirs=("var" "generated" "pub/media" "pub/static")

for dir in "${writable_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        # 并行设置目录权限
        find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 775 2>/dev/null || true
        
        # 并行设置文件权限
        find "$dir" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 664 2>/dev/null || true
        
        # 并行设置 setgid 位（确保新文件继承组）
        find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod g+s 2>/dev/null || true
    fi
done

# 4. 设置可执行文件权限
if [[ -f "bin/magento" ]]; then
    sudo chmod 755 bin/magento
fi

# 查找其他可执行文件
find . -name "*.sh" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 755 2>/dev/null || true

log_success "权限修复完成（高性能模式）"

# 4. 清理缓存（使用更安全的方法）
log_info "清理 Magento 缓存..."
php bin/magento cache:clean
log_success "缓存清理完成"

# 5. 停止现有消费者
log_info "停止现有队列消费者..."
pkill -f "queue:consumers:start.*${SITE_NAME}" || true
sleep 2

# 6. 启动队列消费者（全量消费者版本）
log_info "启动队列消费者（全量模式）..."

# 创建日志目录
mkdir -p "$SITE_DIR/var/log"

# 定义所有重要的消费者
consumers=(
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

# 启动所有消费者
consumer_count=0
for consumer in "${consumers[@]}"; do
    log_info "启动消费者: $consumer"
    
    # 创建日志文件并设置权限
    touch "$SITE_DIR/var/log/consumer-${consumer}.log"
    chmod 664 "$SITE_DIR/var/log/consumer-${consumer}.log"
    
    # 启动消费者，添加错误处理
    nohup php bin/magento queue:consumers:start "$consumer" \
        --single-thread --max-messages=1000 \
        >> "$SITE_DIR/var/log/consumer-${consumer}.log" 2>&1 &
    
    pid=$!
    if [[ $pid -gt 0 ]]; then
        echo $pid >> "$PID_FILE"
        consumer_count=$((consumer_count + 1))
        log_success "消费者 $consumer 启动成功 (PID: $pid)"
    else
        log_warning "消费者 $consumer 启动失败"
    fi
    
    # 短暂延迟，避免同时启动太多进程
    sleep 0.5
done

log_success "队列消费者启动完成 (共 $consumer_count 个消费者)"

# 7. 等待消费者启动
log_info "等待消费者启动..."
sleep 5

# 8. 显示队列状态
log_info "显示队列状态..."
sudo rabbitmqctl list_queues -p "$VHOST" name consumers messages_ready messages_unacknowledged

# 9. 显示配置摘要
echo
log_success "🎉 RabbitMQ 配置完成！"
echo
echo -e "${YELLOW}📋 配置摘要:${NC}"
echo -e "  站点名称: ${CYAN}$SITE_NAME${NC}"
echo -e "  站点路径: ${CYAN}$SITE_DIR${NC}"
echo -e "  虚拟主机: ${CYAN}$VHOST${NC}"
echo -e "  用户名: ${CYAN}$USER${NC}"
echo -e "  密码: ${CYAN}$PASS${NC}"
echo -e "  消费者 PID: ${CYAN}$(cat "$PID_FILE" 2>/dev/null | tr '\n' ' ')${NC}"
echo
echo -e "${YELLOW}🔧 管理命令:${NC}"
echo -e "  查看队列状态: ${CYAN}sudo rabbitmqctl list_queues -p $VHOST${NC}"
echo -e "  停止消费者: ${CYAN}pkill -f 'queue:consumers:start.*$SITE_NAME'${NC}"
echo -e "  查看日志: ${CYAN}tail -f $SITE_DIR/var/log/consumer-*.log${NC}"
echo
echo -e "${YELLOW}📊 消费者配置:${NC}"
echo -e "  消费者总数: ${CYAN}$consumer_count个${NC}"
echo -e "  消费者类型: ${CYAN}全量${NC} (包含所有Magento2队列消费者)"
echo -e "  消息处理量: ${CYAN}1000个/次${NC}"
echo -e "  运行模式: ${CYAN}单线程${NC} (稳定省资源)"
echo -e "  日志分离: ${CYAN}是${NC} (每个消费者独立日志)"
