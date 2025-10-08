#!/bin/bash

# RabbitMQ 站点管理脚本
# 用于配置和管理 Magento 站点的 RabbitMQ 虚拟主机、用户和队列消费者
# 作者: Ansible LEMP Project
# 版本: 2.1.0

# 移除 set -e，改为手动错误处理
# set -e

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

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/tmp/rabbitmq_manager_${SITE_NAME}.lock"
ERROR_LOG="/tmp/rabbitmq_manager_${SITE_NAME}_error.log"

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

# 高性能权限修复函数（基于 magento-permissions-fast.sh 优化）
fix_permissions_fast() {
    local site_path="$1"
    local nginx_group="${2:-www-data}"
    local site_user="$(whoami)"
    
    log_info "修复 Magento 权限（超高性能模式）..."
    
    # 性能配置（优化参数）
    local max_parallel_jobs=8   # 优化并行任务数
    local batch_size=1000       # 优化批处理大小
    
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
        log_error "需要 sudo 权限来管理 RabbitMQ"
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
    echo -e "  ${CYAN}health${NC}     - 健康检查"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa setup${NC}    # 配置 ipwa 站点"
    echo -e "  ${CYAN}./rabbitmq_manager.sh hawk start${NC}    # 启动 hawk 消费者"
    echo -e "  ${CYAN}./rabbitmq_manager.sh ipwa health${NC}   # 健康检查"
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
    
    # 检查消费者进程
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "消费者进程: ${GREEN}运行中${NC}"
    else
        echo -e "消费者进程: ${RED}未运行${NC}"
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
    PID_FILE="/tmp/rabbitmq_consumers_${SITE_NAME}.pid"
    LOG_DIR="/home/doge/logs/rabbitmq"

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
            monitor_memory
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
    log_info "开始配置 RabbitMQ 站点: $SITE_NAME"
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
        
        # 使用 timeout 命令防止卡住（减少超时时间）
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

    # 6. 修复权限（防止 Magento 命令失败）
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

    # 9. 启动队列消费者（简化版本，更接近原始命令）
    log_info "启动队列消费者（简化模式）..."
    start_consumers_simple

    # 10. 等待消费者启动
    log_info "等待消费者启动..."
    sleep 5

    # 11. 显示队列状态
    log_info "显示队列状态..."
    safe_rabbitmq_cmd "list_queues -p '$VHOST_NAME' name consumers messages_ready messages_unacknowledged"

    # 12. 显示配置摘要
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
    echo -e "${YELLOW}📊 消费者配置:${NC}"
    local cpu_cores=$(nproc)
    local consumer_multiplier=$((cpu_cores * 2))
    echo -e "  CPU核心数: ${CYAN}$cpu_cores${NC}"
    echo -e "  消费者倍数: ${CYAN}$consumer_multiplier${NC}"
    echo -e "  启动的消费者类型: ${CYAN}6种${NC} (async.operations.all, product_action_attribute.update, exportProcessor, inventoryQtyUpdate, sales.rule.update, media.storage.catalog.image.resize)"
    echo -e "  动态内存限制: ${CYAN}根据服务器内存自动调整${NC}"
}

# 启动消费者（内部函数）
# 启动消费者函数（简化版本，更接近原始命令）
start_consumers_simple() {
    log_info "启动队列消费者（简化模式）..."
    
    # 切换到网站目录
    cd "$SITE_PATH" || {
        log_error "无法切换到站点目录: $SITE_PATH"
        return 1
    }
    
    # 启动第一个消费者（测试模式）
    log_info "启动测试消费者..."
    php bin/magento queue:consumers:start async.operations.all --max-messages=1 --single-thread &
    local test_pid=$!
    sleep 2
    kill $test_pid 2>/dev/null || true
    
    # 启动主要消费者（后台运行）
    log_info "启动主要消费者..."
    nohup php bin/magento queue:consumers:start async.operations.all --single-thread >/dev/null 2>&1 &
    local pid1=$!
    
    nohup php bin/magento queue:consumers:start product_action_attribute.update --single-thread >/dev/null 2>&1 &
    local pid2=$!
    
    # 保存 PID
    echo "$pid1" > "$PID_FILE"
    echo "$pid2" >> "$PID_FILE"
    
    log_success "队列消费者启动完成 (PID: $pid1, $pid2)"
}

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
        max_memory_kb=6291456  # 6GB for 128GB+ servers
    elif [ "\$total_memory_gb" -ge 64 ]; then
        max_memory_kb=3145728  # 3GB for 64GB+ servers
    else
        max_memory_kb=1572864  # 1.5GB for smaller servers
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
    
    # 根据服务器内存动态调整 PHP 内存限制
    local total_memory_gb=\$(free -g | grep Mem | awk '{print \$2}')
    local php_memory_limit
    
    if [ "\$total_memory_gb" -ge 128 ]; then
        php_memory_limit="2G"
    elif [ "\$total_memory_gb" -ge 64 ]; then
        php_memory_limit="1.5G"
    else
        php_memory_limit="1G"
    fi
    
    while true; do
        echo "\$(date): 启动消费者 \$consumer_name (内存限制: \$php_memory_limit)" >> "\$LOG_DIR/\${SITE_NAME}_\${consumer_name}.log"
        
        cd "\$SITE_PATH"
        php -d memory_limit=\$php_memory_limit bin/magento queue:consumers:start "\$consumer_name" --max-messages=\$max_messages --single-thread &
        local pid=\$!
        
        # 监控内存使用
        monitor_memory \$pid "\$consumer_name"
        
        # 等待进程结束
        wait \$pid
        local exit_code=\$?
        
        echo "\$(date): 消费者 \$consumer_name 退出，退出码: \$exit_code" >> "\$LOG_DIR/\${SITE_NAME}_\${consumer_name}.log"
        
        # 智能错误处理 - 根据退出码调整等待时间
        case \$exit_code in
            0) sleep 5 ;;  # 正常退出，短暂等待
            1) sleep 30 ;; # 一般错误，中等等待
            2) sleep 60 ;; # 严重错误，较长等待
            *) sleep 120 ;; # 未知错误，最长等待
        esac
    done
}

# 启动主要消费者
# 根据 CPU 核心数动态调整消费者数量和消息处理量
local cpu_cores=\$(nproc)
local consumer_multiplier=\$((cpu_cores * 2))  # 每核心2个消费者

start_consumer "async.operations.all" \$((consumer_multiplier * 100)) &
start_consumer "product_action_attribute.update" \$((consumer_multiplier * 50)) &
start_consumer "exportProcessor" \$((consumer_multiplier * 30)) &
start_consumer "inventoryQtyUpdate" \$((consumer_multiplier * 20)) &
start_consumer "sales.rule.update" \$((consumer_multiplier * 15)) &
start_consumer "media.storage.catalog.image.resize" \$((consumer_multiplier * 10)) &

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
    
    if ! check_rabbitmq_service; then
        safe_exit 1
    fi
    
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
    safe_rabbitmq_cmd "list_queues -p '$VHOST_NAME' name consumers messages_ready messages_unacknowledged"
    
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
        safe_rabbitmq_cmd "purge_queue -p '$VHOST_NAME' async.operations.all"
        safe_rabbitmq_cmd "purge_queue -p '$VHOST_NAME' product_action_attribute.update"
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

# 执行主程序
main "$@"
