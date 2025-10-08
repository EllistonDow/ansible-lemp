#!/bin/bash
# Magento2 Performance Optimizer for LEMP Stack
# Dynamic memory allocation for different server sizes
# Usage: ./magento2-optimizer.sh [64|128|256] [optimize|restore|status]

# 注意：不使用 set -e，因为某些操作允许失败（如ModSecurity配置）

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
MONITOR_MARK="📊"
ALERT_MARK="🚨"

# 配置文件路径
MYSQL_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"
PHP_FPM_CONFIG="/etc/php/8.3/fpm/pool.d/www.conf"
PHP_FPM_INI_CONFIG="/etc/php/8.3/fpm/php.ini"
PHP_CLI_INI_CONFIG="/etc/php/8.3/cli/php.ini"
NGINX_CONFIG="/etc/nginx/nginx.conf"
VALKEY_CONFIG="/etc/valkey/valkey.conf"
RABBITMQ_CONFIG="/etc/rabbitmq/rabbitmq.conf"
RABBITMQ_ENV_CONFIG="/etc/rabbitmq/rabbitmq-env.conf"
OPENSEARCH_CONFIG="/etc/opensearch/opensearch.yml"
OPENSEARCH_JVM_CONFIG="/etc/opensearch/jvm.options"
BACKUP_DIR="/opt/lemp-backups/magento2-optimizer"

# 动态内存配置
TOTAL_RAM_GB=64  # 默认64GB，将在main函数中设置
SITES_COUNT=4    # 默认4个站点
CPU_CORES=$(nproc)
CURRENT_LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

# 内存分配计算函数
calculate_memory_allocation() {
    local total_gb=$1
    
    # 内存分配百分比 (基于Magento2最佳实践)
    local mysql_percent=25      # MySQL InnoDB Buffer Pool
    local opensearch_percent=12 # OpenSearch JVM Heap
    local valkey_percent=9      # Valkey Cache
    local rabbitmq_percent=8    # RabbitMQ 内存
    local system_percent=27     # 系统缓存和内核
    local other_percent=19      # 其他服务 (Nginx, Varnish等)
    
    # 计算各服务内存 (GB)
    MYSQL_MEMORY_GB=$((total_gb * mysql_percent / 100))
    OPENSEARCH_MEMORY_GB=$((total_gb * opensearch_percent / 100))
    VALKEY_MEMORY_GB=$((total_gb * valkey_percent / 100))
    RABBITMQ_MEMORY_GB=$((total_gb * rabbitmq_percent / 100))
    SYSTEM_MEMORY_GB=$((total_gb * system_percent / 100))
    OTHER_MEMORY_GB=$((total_gb * other_percent / 100))
    
    # OpenSearch JVM 堆内存限制（官方强烈建议不超过32GB）
    # 原因：超过32GB后JVM压缩指针失效，实际可用内存反而减少
    if [[ $OPENSEARCH_MEMORY_GB -gt 32 ]]; then
        OPENSEARCH_MEMORY_GB=32
        # 将多余的内存重新分配给MySQL
        local extra_memory=$((total_gb * opensearch_percent / 100 - 32))
        MYSQL_MEMORY_GB=$((MYSQL_MEMORY_GB + extra_memory))
    fi
    
    # PHP-FPM进程数计算 (自适应调整，避免过度优化)
    # 基于CPU核心数和系统负载动态调整
    local base_processes=$((CPU_CORES * 8))  # 每核心8个进程作为基础
    local load_factor=1
    
    # 根据系统负载调整进程数
    if (( $(echo "$CURRENT_LOAD > $CPU_CORES" | bc -l) )); then
        load_factor=0.8  # 高负载时减少进程数
    elif (( $(echo "$CURRENT_LOAD < $CPU_CORES * 0.5" | bc -l) )); then
        load_factor=1.2  # 低负载时可适当增加
    fi
    
    PHP_MAX_CHILDREN=$(echo "$base_processes * $load_factor" | bc | cut -d. -f1)
    
    # 确保最小和最大配置
    [[ $MYSQL_MEMORY_GB -lt 8 ]] && MYSQL_MEMORY_GB=8
    [[ $OPENSEARCH_MEMORY_GB -lt 4 ]] && OPENSEARCH_MEMORY_GB=4
    [[ $VALKEY_MEMORY_GB -lt 2 ]] && VALKEY_MEMORY_GB=2
    [[ $RABBITMQ_MEMORY_GB -lt 1 ]] && RABBITMQ_MEMORY_GB=1
    [[ $PHP_MAX_CHILDREN -lt 20 ]] && PHP_MAX_CHILDREN=20
    [[ $PHP_MAX_CHILDREN -gt 150 ]] && PHP_MAX_CHILDREN=150  # 降低最大进程数限制
    
    # MySQL实例数计算 (每4GB一个实例，最少8个，最多32个)
    MYSQL_INSTANCES=$((MYSQL_MEMORY_GB / 4))
    [[ $MYSQL_INSTANCES -lt 8 ]] && MYSQL_INSTANCES=8
    [[ $MYSQL_INSTANCES -gt 32 ]] && MYSQL_INSTANCES=32
    
    # 计算动态配置值
    MYSQL_MAX_CONNECTIONS=$((CPU_CORES * 50 + 100))
    MYSQL_THREAD_CACHE=$((CPU_CORES * 5))
    NGINX_WORKER_CONNECTIONS=$((CPU_CORES * 1000 + 1000))
}

# 配置验证函数 - 验证配置是否正确应用
validate_config() {
    local service="$1"
    local config_file="$2"
    local expected_value="$3"
    local config_key="$4"
    
    local actual_value
    case "$service" in
        "mysql")
            actual_value=$(sudo grep "^${config_key}" "$config_file" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
            ;;
        "php-fpm")
            actual_value=$(sudo grep "^${config_key}" "$config_file" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
            ;;
        "valkey")
            actual_value=$(sudo grep "^${config_key}" "$config_file" 2>/dev/null | head -1 | sed "s/^${config_key} *//" || echo "未设置")
            ;;
        "opensearch")
            actual_value=$(sudo grep "^${config_key}" "$config_file" 2>/dev/null | sed "s/.*${config_key}//" || echo "未设置")
            ;;
    esac
    
    if [[ "$actual_value" == "$expected_value" ]]; then
        echo -e "  ${CHECK_MARK} ${config_key}: ${actual_value}"
        return 0
    else
        echo -e "  ${CROSS_MARK} ${config_key}: ${actual_value} (期望: ${expected_value})"
        return 1
    fi
}

# PHP-FPM配置验证函数
validate_php_fpm_config() {
    echo -e "  ${INFO_MARK} 检查PHP-FPM配置文件..."
    
    # 检查PHP-FPM配置语法
    if sudo php-fpm8.3 -t >/dev/null 2>&1; then
        echo -e "  ${CHECK_MARK} PHP-FPM配置文件语法正确"
    else
        echo -e "  ${CROSS_MARK} PHP-FPM配置文件语法错误"
        echo -e "  ${INFO_MARK} 请检查: sudo php-fpm8.3 -t"
        return 1
    fi
    
    # 检查是否有重复的pm配置
    local pm_max_children_count=$(sudo grep -c "^pm.max_children" "$PHP_FPM_CONFIG")
    if [[ $pm_max_children_count -gt 1 ]]; then
        echo -e "  ${CROSS_MARK} 发现重复的pm.max_children配置"
        return 1
    fi
    
    # 检查关键配置是否存在
    local pm_mode=$(sudo grep "^pm = " "$PHP_FPM_CONFIG" | wc -l)
    if [[ $pm_mode -eq 0 ]]; then
        echo -e "  ${CROSS_MARK} 缺少pm模式配置"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} PHP-FPM配置检查通过"
    return 0
}

# Nginx配置验证函数
validate_nginx_config() {
    echo -e "  ${INFO_MARK} 检查Nginx配置文件语法..."
    
    # 检查Nginx配置语法
    if sudo nginx -t >/dev/null 2>&1; then
        echo -e "  ${CHECK_MARK} Nginx配置文件语法正确"
    else
        echo -e "  ${CROSS_MARK} Nginx配置文件语法错误"
        echo -e "  ${INFO_MARK} 请检查: sudo nginx -t"
        return 1
    fi
    
    # 检查关键配置是否存在
    local worker_processes=$(sudo grep "worker_processes" "$NGINX_CONFIG" | grep -v "^#" | wc -l)
    local worker_connections=$(sudo grep "worker_connections" "$NGINX_CONFIG" | grep -v "^#" | wc -l)
    
    if [[ $worker_processes -eq 0 ]]; then
        echo -e "  ${CROSS_MARK} 缺少worker_processes配置"
        return 1
    fi
    
    if [[ $worker_connections -eq 0 ]]; then
        echo -e "  ${CROSS_MARK} 缺少worker_connections配置"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} Nginx关键配置检查通过"
    return 0
}

# Valkey配置验证函数
validate_valkey_config() {
    echo -e "  ${INFO_MARK} 检查Valkey配置文件..."
    
    # 检查是否有重复的maxmemory配置
    local maxmemory_count=$(sudo grep -c "^maxmemory " "$VALKEY_CONFIG")
    if [[ $maxmemory_count -gt 1 ]]; then
        echo -e "  ${CROSS_MARK} 发现重复的maxmemory配置"
        return 1
    fi
    
    # 检查是否有重复的maxmemory-policy配置
    local maxmemory_policy_count=$(sudo grep -c "^maxmemory-policy " "$VALKEY_CONFIG")
    if [[ $maxmemory_policy_count -gt 1 ]]; then
        echo -e "  ${CROSS_MARK} 发现重复的maxmemory-policy配置"
        return 1
    fi
    
    # 检查关键配置是否存在
    local maxmemory_exists=$(sudo grep "^maxmemory " "$VALKEY_CONFIG" | wc -l)
    if [[ $maxmemory_exists -eq 0 ]]; then
        echo -e "  ${CROSS_MARK} 缺少maxmemory配置"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} Valkey配置检查通过"
    return 0
}

# OpenSearch配置验证函数
validate_opensearch_config() {
    echo -e "  ${INFO_MARK} 检查OpenSearch配置文件语法..."
    
    # 检查配置文件语法
    if sudo /opt/opensearch/bin/opensearch --version >/dev/null 2>&1; then
        echo -e "  ${CHECK_MARK} OpenSearch可执行文件正常"
    else
        echo -e "  ${CROSS_MARK} OpenSearch可执行文件异常"
        return 1
    fi
    
    # 检查配置文件是否有重复字段
    local duplicate_fields=$(sudo grep -o "cluster.routing.allocation.disk.threshold_enabled" "$OPENSEARCH_CONFIG" | wc -l)
    if [[ $duplicate_fields -gt 1 ]]; then
        echo -e "  ${CROSS_MARK} 发现重复配置字段: cluster.routing.allocation.disk.threshold_enabled"
        return 1
    fi
    
    # 检查是否有索引级别设置
    local index_settings=$(sudo grep -c "^index\." "$OPENSEARCH_CONFIG" 2>/dev/null | head -1 || echo "0")
    if [[ "$index_settings" -gt 0 ]]; then
        echo -e "  ${CROSS_MARK} 发现索引级别设置，这些应该在索引模板中配置"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} OpenSearch配置文件语法正确"
    return 0
}

# RabbitMQ配置验证函数
validate_rabbitmq_config() {
    echo -e "  ${INFO_MARK} 检查RabbitMQ配置文件..."
    
    # 检查配置文件是否存在
    if [[ ! -f "$RABBITMQ_CONFIG" ]]; then
        echo -e "  ${CROSS_MARK} RabbitMQ配置文件不存在: $RABBITMQ_CONFIG"
        return 1
    fi
    
    # 检查关键配置是否存在
    local memory_watermark=$(sudo grep "vm_memory_high_watermark.relative" "$RABBITMQ_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local disk_limit=$(sudo grep "disk_free_limit.absolute" "$RABBITMQ_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    
    if [[ "$memory_watermark" == "0.6" ]]; then
        echo -e "  ${CHECK_MARK} 内存水位线配置正确: $memory_watermark"
    else
        echo -e "  ${CROSS_MARK} 内存水位线配置异常: $memory_watermark"
        return 1
    fi
    
    if [[ "$disk_limit" == "2GB" ]]; then
        echo -e "  ${CHECK_MARK} 磁盘限制配置正确: $disk_limit"
    else
        echo -e "  ${CROSS_MARK} 磁盘限制配置异常: $disk_limit"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} RabbitMQ配置文件语法正确"
    return 0
}

# 系统监控和告警函数
monitor_system_resources() {
    echo -e "${MONITOR_MARK} ${CYAN}系统资源监控...${NC}"
    
    # 内存使用监控
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local memory_used_gb=$(free -g | grep Mem | awk '{print $3}')
    local memory_total_gb=$(free -g | grep Mem | awk '{print $2}')
    
    echo -e "  ${INFO_MARK} 内存使用: ${memory_used_gb}GB/${memory_total_gb}GB (${memory_usage}%)"
    
    # CPU负载监控
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$CPU_CORES
    local load_percentage=$(echo "scale=1; $cpu_load * 100 / $cpu_cores" | bc)
    
    echo -e "  ${INFO_MARK} CPU负载: ${cpu_load} (${load_percentage}% of ${cpu_cores} cores)"
    
    # 磁盘使用监控
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo -e "  ${INFO_MARK} 磁盘使用: ${disk_usage}%"
    
    # Swap使用监控
    local swap_total=$(free | grep Swap | awk '{print $2}')
    local swap_used=$(free | grep Swap | awk '{print $3}')
    local swap_percentage=0
    if [[ $swap_total -gt 0 ]]; then
        swap_percentage=$(echo "scale=1; $swap_used * 100 / $swap_total" | bc)
    fi
    echo -e "  ${INFO_MARK} Swap使用: ${swap_used}KB/${swap_total}KB (${swap_percentage}%)"
    
    # 告警检查
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        echo -e "  ${ALERT_MARK} ${RED}警告: 内存使用率过高 (${memory_usage}%)${NC}"
    fi
    
    if (( $(echo "$cpu_load > $cpu_cores" | bc -l) )); then
        echo -e "  ${ALERT_MARK} ${RED}警告: CPU负载过高 (${cpu_load} > ${cpu_cores})${NC}"
    fi
    
    if [[ $disk_usage -gt 85 ]]; then
        echo -e "  ${ALERT_MARK} ${RED}警告: 磁盘空间不足 (${disk_usage}%)${NC}"
    fi
    
    if (( $(echo "$swap_percentage > 50" | bc -l) )); then
        echo -e "  ${ALERT_MARK} ${RED}警告: Swap使用率过高 (${swap_percentage}%)${NC}"
        echo -e "  ${INFO_MARK} 建议运行: sudo swapoff -a && sudo swapon -a"
    fi
    
    echo
}

# 服务状态监控
monitor_services_status() {
    echo -e "${MONITOR_MARK} ${CYAN}服务状态监控...${NC}"
    
    local services=("mysql" "php8.3-fpm" "nginx" "valkey" "rabbitmq-server" "opensearch")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "  ${CHECK_MARK} ${service}: 运行中"
        else
            echo -e "  ${CROSS_MARK} ${service}: 未运行"
        fi
    done
    echo
}

# 性能基准测试函数
performance_benchmark() {
    echo -e "${ROCKET} ${CYAN}性能基准测试...${NC}"
    
    # MySQL连接测试
    echo -e "  ${INFO_MARK} 测试MySQL连接..."
    if mysql -e "SELECT 1;" >/dev/null 2>&1; then
        local mysql_time=$(time (mysql -e "SELECT COUNT(*) FROM information_schema.tables;" >/dev/null 2>&1) 2>&1 | grep real | awk '{print $2}')
        echo -e "  ${CHECK_MARK} MySQL查询响应: ${mysql_time}"
    else
        echo -e "  ${CROSS_MARK} MySQL连接失败"
    fi
    
    # OpenSearch连接测试
    echo -e "  ${INFO_MARK} 测试OpenSearch连接..."
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        local es_time=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:9200/_cluster/health)
        echo -e "  ${CHECK_MARK} OpenSearch响应: ${es_time}s"
    else
        echo -e "  ${CROSS_MARK} OpenSearch连接失败"
    fi
    
    # Valkey连接测试
    echo -e "  ${INFO_MARK} 测试Valkey连接..."
    if redis-cli ping >/dev/null 2>&1; then
        local redis_time=$(time (redis-cli set test_key "test_value" >/dev/null 2>&1) 2>&1 | grep real | awk '{print $2}')
        echo -e "  ${CHECK_MARK} Valkey操作响应: ${redis_time}"
        redis-cli del test_key >/dev/null 2>&1
    else
        echo -e "  ${CROSS_MARK} Valkey连接失败"
    fi
    
    echo
}

# 自适应配置建议函数
adaptive_config_suggestions() {
    echo -e "${INFO_MARK} ${CYAN}自适应配置建议...${NC}"
    
    # 根据当前负载建议调整
    local current_load=$CURRENT_LOAD
    local cpu_cores=$CPU_CORES
    
    if (( $(echo "$current_load > $cpu_cores * 0.8" | bc -l) )); then
        echo -e "  ${WARNING_MARK} 系统负载较高，建议:"
        echo -e "    • 减少PHP-FPM进程数"
        echo -e "    • 降低MySQL连接数"
        echo -e "    • 考虑启用更多缓存"
    elif (( $(echo "$current_load < $cpu_cores * 0.3" | bc -l) )); then
        echo -e "  ${INFO_MARK} 系统负载较低，可以:"
        echo -e "    • 适当增加PHP-FPM进程数"
        echo -e "    • 增加MySQL连接数"
        echo -e "    • 优化缓存策略"
    else
        echo -e "  ${CHECK_MARK} 系统负载正常，当前配置合适"
    fi
    
    echo
}

print_header() {
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 性能优化工具 (动态内存分配)"
    echo -e "    服务器内存: ${TOTAL_RAM_GB}GB RAM"
    echo -e "    支持站点: ${SITES_COUNT}个Magento2站点"
    echo -e "==============================================${NC}"
    echo
    echo -e "${CYAN}📊 内存分配方案:${NC}"
    echo -e "  MySQL InnoDB Buffer Pool: ${MYSQL_MEMORY_GB}GB (${MYSQL_INSTANCES}个实例)"
    echo -e "  OpenSearch JVM Heap: ${OPENSEARCH_MEMORY_GB}GB"
    echo -e "  Valkey Cache: ${VALKEY_MEMORY_GB}GB"
    echo -e "  RabbitMQ 内存: ${RABBITMQ_MEMORY_GB}GB"
    echo -e "  PHP-FPM 最大进程数: ${PHP_MAX_CHILDREN}"
    echo -e "  系统缓存预留: ${SYSTEM_MEMORY_GB}GB"
    echo -e "  其他服务预留: ${OTHER_MEMORY_GB}GB"
    echo
}

print_help() {
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 性能优化工具 (动态内存分配)"
    echo -e "==============================================${NC}"
    echo
    echo -e "${CYAN}用法: $0 [内存大小] [选项] [服务名]${NC}"
    echo
    echo -e "${YELLOW}支持的内存大小:${NC}"
    echo -e "  ${GREEN}64${NC}              - 64GB RAM服务器 (默认)"
    echo -e "  ${GREEN}128${NC}             - 128GB RAM服务器"
    echo -e "  ${GREEN}256${NC}             - 256GB RAM服务器"
    echo
    echo -e "${YELLOW}基本选项:${NC}"
    echo -e "  ${GREEN}optimize${NC}         - 应用Magento2性能优化配置"
    echo -e "  ${GREEN}restore${NC}          - 还原到原始配置"
    echo -e "  ${GREEN}status${NC}           - 显示当前优化状态"
    echo -e "  ${GREEN}monitor${NC}         - 系统资源监控和告警"
    echo -e "  ${GREEN}benchmark${NC}       - 性能基准测试"
    echo -e "  ${GREEN}suggest${NC}         - 自适应配置建议"
    echo -e "  ${GREEN}force-reoptimize${NC} - 强制重新优化（清理混合配置）"
    echo -e "  ${GREEN}help${NC}             - 显示此帮助信息"
    echo
    echo -e "${YELLOW}单独优化选项:${NC}"
    echo -e "  ${GREEN}optimize mysql${NC}   - 仅优化MySQL配置"
    echo -e "  ${GREEN}optimize php${NC}     - 仅优化PHP-FPM配置"
    echo -e "  ${GREEN}optimize nginx${NC}   - 仅优化Nginx配置"
    echo -e "  ${GREEN}optimize valkey${NC}  - 仅优化Valkey配置"
    echo -e "  ${GREEN}optimize rabbitmq${NC} - 仅优化RabbitMQ配置"
    echo -e "  ${GREEN}optimize opensearch${NC} - 仅优化OpenSearch配置"
    echo
    echo -e "${YELLOW}单独还原选项:${NC}"
    echo -e "  ${GREEN}restore mysql${NC}    - 仅还原MySQL配置"
    echo -e "  ${GREEN}restore php${NC}      - 仅还原PHP-FPM配置"
    echo -e "  ${GREEN}restore nginx${NC}    - 仅还原Nginx配置"
    echo -e "  ${GREEN}restore valkey${NC}   - 仅还原Valkey配置"
    echo -e "  ${GREEN}restore rabbitmq${NC}  - 仅还原RabbitMQ配置"
    echo -e "  ${GREEN}restore opensearch${NC} - 仅还原OpenSearch配置"
    echo
    echo -e "${YELLOW}内存分配策略 (自适应优化):${NC}"
    echo -e "  • MySQL: 25% 总内存 (InnoDB Buffer Pool)"
    echo -e "  • OpenSearch: 12% 总内存 (JVM Heap, 最大32GB)"
    echo -e "  • Valkey: 9% 总内存 (Cache)"
    echo -e "  • RabbitMQ: 8% 总内存 (队列处理)"
    echo -e "  • 系统缓存: 27% 总内存 (内核和文件系统)"
    echo -e "  • 其他服务: 19% 总内存 (Nginx, Varnish等)"
    echo -e "  • PHP-FPM: 基于CPU核心数动态调整 (每核心8个进程)"
    echo -e "  • MySQL连接: 基于CPU核心数动态调整 (每核心50个连接)"
    echo -e "  • Nginx连接: 基于CPU核心数动态调整 (每核心1000个连接)"
    echo
    echo -e "${YELLOW}⚠️  OpenSearch 重要说明:${NC}"
    echo -e "  • JVM堆内存建议不超过32GB（压缩指针限制）"
    echo -e "  • 超过32GB后压缩指针失效，实际可用内存反而减少"
    echo -e "  • 多余内存会自动分配给MySQL以提升性能"
    echo
    echo -e "${YELLOW}多站点支持:${NC}"
    echo -e "  • 支持${SITES_COUNT}个Magento2站点同时运行"
    echo -e "  • OpenSearch索引隔离: site{N}_catalog_*"
    echo -e "  • 资源配额限制: 每站点最多20个分片"
    echo -e "  • 自动索引模板创建和管理"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0 64 optimize           # 64GB服务器完整优化"
    echo -e "  $0 128 optimize mysql   # 128GB服务器仅优化MySQL"
    echo -e "  $0 256 restore nginx     # 256GB服务器还原Nginx"
    echo -e "  $0 64 status            # 查看64GB服务器优化状态"
    echo -e "  $0 128 monitor          # 系统资源监控和告警"
    echo -e "  $0 64 benchmark        # 性能基准测试"
    echo -e "  $0 128 suggest          # 自适应配置建议"
    echo -e "  $0 128 force-reoptimize # 强制重新优化128GB配置（清理混合配置）"
    echo
    echo -e "${YELLOW}内存配置对比:${NC}"
    echo -e "  ${CYAN}64GB:${NC}  MySQL:16GB, OpenSearch:7GB, Valkey:5GB, RabbitMQ:5GB, PHP进程:120"
    echo -e "  ${CYAN}128GB:${NC} MySQL:32GB, OpenSearch:15GB, Valkey:11GB, RabbitMQ:10GB, PHP进程:200"
    echo -e "  ${CYAN}256GB:${NC} MySQL:64GB, OpenSearch:30GB, Valkey:23GB, RabbitMQ:20GB, PHP进程:200"
    echo -e "  ${CYAN}320GB+:${NC} MySQL增加, OpenSearch限制32GB, RabbitMQ增加, 多余内存分配给MySQL"
    echo
}

create_backup() {
    local config_file="$1"
    local backup_name="$2"
    
    if [[ -f "$config_file" ]]; then
        echo -e "  ${INFO_MARK} 备份配置文件: $config_file"
        sudo mkdir -p "$BACKUP_DIR"
        
        # 保存带时间戳的备份
        sudo cp "$config_file" "$BACKUP_DIR/${backup_name}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # 只有在没有原始备份时才保存原始配置
        if [[ ! -f "$BACKUP_DIR/${backup_name}.original" ]]; then
            sudo cp "$config_file" "$BACKUP_DIR/${backup_name}.original"
            echo -e "  ${INFO_MARK} 保存原始配置: ${backup_name}.original"
        else
            echo -e "  ${INFO_MARK} 原始配置已存在，跳过保存"
        fi
    fi
}

restore_backup() {
    local config_file="$1"
    local backup_name="$2"
    
    if [[ -f "$BACKUP_DIR/${backup_name}.original" ]]; then
        echo -e "  ${INFO_MARK} 还原配置文件: $config_file"
        sudo cp "$BACKUP_DIR/${backup_name}.original" "$config_file"
        return 0
    else
        echo -e "  ${WARNING_MARK} 未找到原始备份: ${backup_name}.original"
        return 1
    fi
}

optimize_mysql() {
    echo -e "${GEAR} ${CYAN}优化MySQL配置...${NC}"
    
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    create_backup "$MYSQL_CONFIG" "mysqld.cnf"
    
    # 创建Magento2优化的MySQL配置
    sudo tee "$MYSQL_CONFIG" > /dev/null << EOF
[client]
port = 3306
socket = /var/run/mysqld/mysqld.sock

[mysqld_safe]
socket = /var/run/mysqld/mysqld.sock
nice = 0

[mysqld]
# Basic Settings
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = 3306
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql
skip-external-locking

# Magento2 Optimized Settings for ${TOTAL_RAM_GB}GB RAM
# Memory Settings (使用${MYSQL_MEMORY_GB}GB给MySQL，留足够内存给其他服务)
innodb_buffer_pool_size = ${MYSQL_MEMORY_GB}G
innodb_buffer_pool_instances = ${MYSQL_INSTANCES}
innodb_log_buffer_size = 256M
key_buffer_size = 512M
tmp_table_size = 512M
max_heap_table_size = 512M
sort_buffer_size = 4M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
join_buffer_size = 8M

# Connection Settings (自适应调整，避免过度优化)
max_connections = ${MYSQL_MAX_CONNECTIONS}
max_connect_errors = 1000000
thread_cache_size = ${MYSQL_THREAD_CACHE}
thread_stack = 256K
interactive_timeout = 3600
wait_timeout = 3600

# InnoDB Settings for Magento2
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 1G
innodb_log_files_in_group = 2
innodb_open_files = 4000
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8
innodb_thread_concurrency = 0
innodb_lock_wait_timeout = 120
innodb_deadlock_detect = ON

# Query Cache (禁用，因为MySQL 8.0已移除)
# query_cache_size = 0
# query_cache_type = OFF

# Table Settings
table_open_cache = 8000
table_definition_cache = 4000
open_files_limit = 65535

# Logging
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
log_queries_not_using_indexes = 0

# Binary Logging (用于主从复制，可选)
# log_bin = /var/log/mysql/mysql-bin.log
# binlog_format = ROW
# expire_logs_days = 7
# max_binlog_size = 100M

# Security Settings
bind-address = 127.0.0.1
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysqldump]
quick
quote-names
max_allowed_packet = 64M

[mysql]
# 移除可能导致问题的默认字符集设置
# default-character-set = utf8mb4

[isamchk]
key_buffer_size = 512M
EOF

    echo -e "  ${CHECK_MARK} MySQL配置已优化 (适用于Magento2 + ${TOTAL_RAM_GB}GB RAM)"
    echo -e "  ${INFO_MARK} InnoDB Buffer Pool: ${MYSQL_MEMORY_GB}GB (${MYSQL_INSTANCES}个实例)"
    
    # 验证关键配置
    echo -e "  ${INFO_MARK} 验证MySQL配置..."
    validate_config "mysql" "$MYSQL_CONFIG" "${MYSQL_MEMORY_GB}G" "innodb_buffer_pool_size"
    validate_config "mysql" "$MYSQL_CONFIG" "${MYSQL_INSTANCES}" "innodb_buffer_pool_instances"
}

# 配置清理函数 - 清理特定服务的旧配置
clean_config() {
    local config_file="$1"
    local service_name="$2"
    
    echo -e "  ${INFO_MARK} 清理 ${service_name} 的旧配置..."
    
    case "$service_name" in
        "php-fpm")
            # 清理PHP-FPM的旧配置行
            sudo sed -i '/^pm\./d' "$config_file"
            sudo sed -i '/^;pm\./d' "$config_file"
            ;;
        "valkey")
            # 清理Valkey的Magento2配置
            sudo sed -i '/# Magento2 Optimized Settings/,/^$/d' "$config_file"
            ;;
        "mysql")
            # MySQL配置完全重写，不需要清理
            ;;
        "nginx")
            # Nginx配置完全重写，不需要清理
            ;;
        "opensearch")
            # OpenSearch配置完全重写，不需要清理
            ;;
    esac
}

# 改进的PHP配置设置函数
set_php_config_reliable() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    
    # 先删除所有相关行（包括注释版本）
    sudo sed -i "/^${key}\s*=/d" "$config_file"
    sudo sed -i "/^;${key}\s*=/d" "$config_file"
    
    # 添加新配置到文件末尾
    echo "${key} = ${value}" | sudo tee -a "$config_file" > /dev/null
}

optimize_php_fpm() {
    echo -e "${GEAR} ${CYAN}优化PHP-FPM配置...${NC}"
    
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    create_backup "$PHP_FPM_CONFIG" "www.conf"
    create_backup "$PHP_FPM_INI_CONFIG" "php-fpm.ini"
    create_backup "$PHP_CLI_INI_CONFIG" "php-cli.ini"
    
    # 计算PHP-FPM进程池设置 (针对128GB服务器优化)
    local start_servers=30
    local min_spare_servers=24
    local max_spare_servers=40
    
    # 根据内存大小动态调整
    if [[ $TOTAL_RAM_GB -eq 64 ]]; then
        start_servers=20
        min_spare_servers=16
        max_spare_servers=30
    elif [[ $TOTAL_RAM_GB -eq 256 ]]; then
        start_servers=40
        min_spare_servers=32
        max_spare_servers=50
    fi
    
    # 清理旧的PHP-FPM配置
    clean_config "$PHP_FPM_CONFIG" "php-fpm"
    
    # 添加新的PHP-FPM池配置（确保所有配置都正确设置）
    cat << EOF | sudo tee -a "$PHP_FPM_CONFIG" > /dev/null

; Magento2 Optimized PHP-FPM Settings for ${TOTAL_RAM_GB}GB RAM
pm = dynamic
pm.max_children = ${PHP_MAX_CHILDREN}
pm.start_servers = ${start_servers}
pm.min_spare_servers = ${min_spare_servers}
pm.max_spare_servers = ${max_spare_servers}
pm.max_requests = 500
pm.process_idle_timeout = 60s
EOF
    
    # 优化PHP-FPM.ini设置 (Magento2官方建议: 生产环境2GB)
    sudo sed -i 's/^memory_limit = .*/memory_limit = 2G/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^max_execution_time = .*/max_execution_time = 1800/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^max_input_time = .*/max_input_time = 1800/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^max_file_uploads = .*/max_file_uploads = 100/' "$PHP_FPM_INI_CONFIG"
    
    # Magento2 关键配置 (防止后台表单提交失败) - 使用可靠函数确保配置存在
    set_php_config_reliable "$PHP_FPM_INI_CONFIG" "max_input_vars" "4000"
    set_php_config_reliable "$PHP_FPM_INI_CONFIG" "zlib.output_compression" "Off"
    set_php_config_reliable "$PHP_FPM_INI_CONFIG" "date.timezone" "America/Los_Angeles"
    
    # 性能优化：文件路径缓存
    set_php_config_reliable "$PHP_FPM_INI_CONFIG" "realpath_cache_size" "10M"
    set_php_config_reliable "$PHP_FPM_INI_CONFIG" "realpath_cache_ttl" "7200"
    
    # 优化PHP-CLI.ini设置 (Magento2命令行操作需要更多内存)
    sudo sed -i 's/^memory_limit = .*/memory_limit = 4G/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^max_execution_time = .*/max_execution_time = 3600/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^max_input_time = .*/max_input_time = 3600/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^max_file_uploads = .*/max_file_uploads = 100/' "$PHP_CLI_INI_CONFIG"
    
    # Magento2 关键配置 (CLI也需要) - 使用可靠函数确保配置存在
    set_php_config_reliable "$PHP_CLI_INI_CONFIG" "max_input_vars" "4000"
    set_php_config_reliable "$PHP_CLI_INI_CONFIG" "zlib.output_compression" "Off"
    set_php_config_reliable "$PHP_CLI_INI_CONFIG" "date.timezone" "America/Los_Angeles"
    
    # 性能优化：文件路径缓存
    set_php_config_reliable "$PHP_CLI_INI_CONFIG" "realpath_cache_size" "10M"
    set_php_config_reliable "$PHP_CLI_INI_CONFIG" "realpath_cache_ttl" "7200"
    
    # OPcache设置 (对Magento2非常重要)
    sudo sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=1024/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' "$PHP_FPM_INI_CONFIG"
    sudo sed -i 's/^;opcache.save_comments=.*/opcache.save_comments=1/' "$PHP_FPM_INI_CONFIG"
    
    # CLI也启用OPcache (命令行操作也能受益)
    sudo sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.enable_cli=.*/opcache.enable_cli=1/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=512/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=32/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.validate_timestamps=.*/opcache.validate_timestamps=1/' "$PHP_CLI_INI_CONFIG"
    sudo sed -i 's/^;opcache.save_comments=.*/opcache.save_comments=1/' "$PHP_CLI_INI_CONFIG"
    
    echo -e "  ${CHECK_MARK} PHP-FPM和PHP-CLI配置已优化 (支持高并发Magento2和命令行操作)"
    echo -e "  ${INFO_MARK} 最大进程数: ${PHP_MAX_CHILDREN}, 启动进程: ${start_servers}, 空闲进程: ${min_spare_servers}-${max_spare_servers}"
    echo -e "  ${INFO_MARK} 关键配置: max_input_vars=4000, date.timezone=America/Los_Angeles"
    echo -e "  ${INFO_MARK} 性能优化: realpath_cache_size=10M, zlib.output_compression=Off"
    
    # 验证PHP-FPM配置
    echo -e "  ${INFO_MARK} 验证PHP-FPM配置..."
    validate_php_fpm_config
    
    # 验证关键配置
    echo -e "  ${INFO_MARK} 验证PHP-FPM配置..."
    validate_config "php-fpm" "$PHP_FPM_CONFIG" "${PHP_MAX_CHILDREN}" "pm.max_children"
    validate_config "php-fpm" "$PHP_FPM_CONFIG" "${start_servers}" "pm.start_servers"
    validate_config "php-fpm" "$PHP_FPM_CONFIG" "${min_spare_servers}" "pm.min_spare_servers"
    validate_config "php-fpm" "$PHP_FPM_CONFIG" "${max_spare_servers}" "pm.max_spare_servers"
}

optimize_nginx() {
    echo -e "${GEAR} ${CYAN}优化Nginx配置...${NC}"
    
    create_backup "$NGINX_CONFIG" "nginx.conf"
    
    # 获取当前nginx用户设置，保持不变
    local current_user
    if [[ -f "$NGINX_CONFIG" ]]; then
        current_user=$(grep "^user " "$NGINX_CONFIG" | head -1 | awk '{print $2}' | sed 's/;//')
        if [[ -z "$current_user" ]]; then
            current_user="www-data"  # 默认用户
        fi
    else
        current_user="www-data"  # 默认用户
    fi
    
    echo -e "  ${INFO_MARK} 保持nginx用户为: ${current_user}"
    
    # 创建优化的Nginx配置 (包含ModSecurity支持)
    sudo tee "$NGINX_CONFIG" > /dev/null << EOF
load_module modules/ngx_http_modsecurity_module.so;

user ${current_user};
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections ${NGINX_WORKER_CONNECTIONS};
    use epoll;
    multi_accept on;
}

http {

    # ModSecurity Configuration (Level 1 - Magento2 Optimized)
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 64M;
    client_body_buffer_size 256k;
    client_header_buffer_size 16k;
    large_client_header_buffers 4 32k;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Gzip Settings (Magento2需要)
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # FastCGI缓存设置 (针对Magento2)
    fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=MAGENTO:256m inactive=1d max_size=2g;
    fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
    fastcgi_cache_use_stale error timeout invalid_header http_500;
    fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
    fastcgi_connect_timeout 60s;
    fastcgi_send_timeout 120s;
    fastcgi_read_timeout 120s;
    fastcgi_buffer_size 64k;
    fastcgi_buffers 8 64k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 256k;

    # Rate Limiting (防止DDoS)
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;
    limit_req_zone \$binary_remote_addr zone=api:10m rate=5r/s;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;

    # Logging Settings
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"'
                    ' rt=\$request_time uct="\$upstream_connect_time"'
                    ' uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Security Headers (Magento2兼容)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    # 注意: Content-Security-Policy会导致Magento2后台菜单无法工作，已移除

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # 创建FastCGI缓存目录
    sudo mkdir -p /var/cache/nginx/fastcgi
    sudo chown -R www-data:www-data /var/cache/nginx/
    
    # 自动设置ModSecurity为级别1 (Magento2优化)
    echo -e "  ${GEAR} 设置ModSecurity为Magento2优化级别..."
    
    # 智能路径检测
    TOGGLE_SCRIPT=""
    if [[ -f "./toggle-modsecurity.sh" ]]; then
        TOGGLE_SCRIPT="./toggle-modsecurity.sh"
    elif [[ -f "./scripts/toggle-modsecurity.sh" ]]; then
        TOGGLE_SCRIPT="./scripts/toggle-modsecurity.sh"
    elif [[ -f "../scripts/toggle-modsecurity.sh" ]]; then
        TOGGLE_SCRIPT="../scripts/toggle-modsecurity.sh"
    fi
    
    if [[ -n "$TOGGLE_SCRIPT" ]]; then
        $TOGGLE_SCRIPT 1 > /dev/null 2>&1 || true
        echo -e "  ${INFO_MARK} ModSecurity级别已设置为1"
    else
        echo -e "  ${WARNING_MARK} 未找到toggle-modsecurity.sh，跳过ModSecurity设置"
    fi

    # 检查PCRE兼容性
    echo -e "  ${GEAR} 检查ModSecurity PCRE兼容性..."
    if sudo nginx -t 2>&1 | grep -q "undefined symbol: pcre_malloc"; then
        echo -e "  ${WARNING_MARK} 检测到PCRE兼容性问题，运行自动修复..."
        if [[ -f "./scripts/fix-modsecurity-pcre.sh" ]]; then
            ./scripts/fix-modsecurity-pcre.sh || true
            echo -e "  ${INFO_MARK} PCRE修复脚本已执行"
        else
            echo -e "  ${WARNING_MARK} 未找到PCRE修复脚本"
        fi
    else
        echo -e "  ${CHECK_MARK} ModSecurity PCRE兼容性正常"
    fi
    
    echo -e "  ${CHECK_MARK} Nginx配置已优化 (支持Magento2缓存、高并发和ModSecurity WAF防护)"
    echo -e "  ${INFO_MARK} ModSecurity已设置为级别1 (适合Magento2生产环境)"
    
    # 验证Nginx配置
    echo -e "  ${INFO_MARK} 验证Nginx配置..."
    validate_nginx_config
}

optimize_valkey() {
    echo -e "${GEAR} ${CYAN}优化Valkey配置...${NC}"
    
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    create_backup "$VALKEY_CONFIG" "valkey.conf"
    
    # 清理旧的Magento2配置
    clean_config "$VALKEY_CONFIG" "valkey"
    
    # 添加新的Magento2优化配置
    sudo tee -a "$VALKEY_CONFIG" > /dev/null << EOF

# Magento2 Optimized Settings for ${TOTAL_RAM_GB}GB RAM
maxmemory ${VALKEY_MEMORY_GB}gb
maxmemory-policy allkeys-lru
maxclients 10000
tcp-keepalive 60
timeout 0

# 持久化设置 (对于会话存储)
save 900 1
save 300 10
save 60 10000

# 网络优化
tcp-backlog 511
EOF

    echo -e "  ${CHECK_MARK} Valkey配置已优化 (适用于Magento2会话存储)"
    echo -e "  ${INFO_MARK} 最大内存: ${VALKEY_MEMORY_GB}GB"
    
    # 验证Valkey配置
    echo -e "  ${INFO_MARK} 验证Valkey配置..."
    validate_valkey_config
    
    # 验证关键配置
    echo -e "  ${INFO_MARK} 验证Valkey配置..."
    validate_config "valkey" "$VALKEY_CONFIG" "${VALKEY_MEMORY_GB}gb" "maxmemory"
    validate_config "valkey" "$VALKEY_CONFIG" "allkeys-lru" "maxmemory-policy"
}

optimize_opensearch() {
    echo -e "${GEAR} ${CYAN}优化OpenSearch配置...${NC}"
    
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    create_backup "$OPENSEARCH_CONFIG" "opensearch.yml"
    create_backup "$OPENSEARCH_JVM_CONFIG" "jvm.options"
    
    # 创建优化的OpenSearch配置
    sudo tee "$OPENSEARCH_CONFIG" > /dev/null << EOF
# OpenSearch Configuration for Magento2 Multi-Site
# Optimized for ${TOTAL_RAM_GB}GB RAM server with ${SITES_COUNT} Magento2 sites

cluster.name: magento2-multisite-cluster
node.name: magento2-node-1
path.data: /var/lib/opensearch
path.logs: /var/log/opensearch
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node

# Memory and Performance Settings
bootstrap.memory_lock: true
indices.memory.index_buffer_size: 30%
indices.memory.min_index_buffer_size: 96mb

# Default Index Template Settings (these will be applied to new indices)
# Note: Index-level settings should be configured via index templates, not in opensearch.yml

# Search Settings
search.max_buckets: 100000
indices.query.bool.max_clause_count: 10000

# Circuit Breaker Settings
indices.breaker.total.limit: 70%
indices.breaker.fielddata.limit: 40%
indices.breaker.request.limit: 40%

# Thread Pool Settings (updated for OpenSearch 2.x)
thread_pool.search.size: 16
thread_pool.search.queue_size: 1000
thread_pool.write.size: 8
thread_pool.write.queue_size: 200

# Cache Settings
indices.requests.cache.size: 2%
indices.fielddata.cache.size: 20%

# Magento2 Multi-Site Specific Settings
action.auto_create_index: true
action.destructive_requires_name: false

# Site-specific index templates (will be created via API)
# Pattern: site{N}_catalog_product, site{N}_catalog_category, etc.
# Each site gets isolated indices with resource quotas

# Resource Quotas for Multi-Site
cluster.routing.allocation.total_shards_per_node: $((SITES_COUNT * 20))
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%

# Security Settings (如果不需要可以禁用)
plugins.security.disabled: true
EOF

    # 优化JVM设置 (动态分配内存给OpenSearch)
    sudo tee "$OPENSEARCH_JVM_CONFIG" > /dev/null << EOF
# OpenSearch JVM Options for Magento2 (Java 11 compatible)
# 针对${TOTAL_RAM_GB}GB RAM服务器优化

# Heap Size Settings (使用${OPENSEARCH_MEMORY_GB}GB，适合多个Magento2站点)
-Xms${OPENSEARCH_MEMORY_GB}g
-Xmx${OPENSEARCH_MEMORY_GB}g

# Garbage Collection Settings (Java 11 compatible)
-XX:+UseG1GC
-XX:G1HeapRegionSize=32m
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=30

# GC Logging (Java 11 compatible)
-Xlog:gc*,gc+age=trace,safepoint:logs/gc.log:utctime,pid,tid,level:filecount=32,filesize=64m

# Heap Dumps
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/lib/opensearch

# JVM temporary directory
-Djava.io.tmpdir=/tmp

# Performance Settings
-Djava.awt.headless=true
-Dfile.encoding=UTF-8
-Djna.nosys=true
-XX:-OmitStackTraceInFastThrow
-XX:+ShowCodeDetailsInExceptionMessages
-Dio.netty.noUnsafe=true
-Dio.netty.noKeySetOptimization=true
-Dio.netty.recycler.maxCapacityPerThread=0
-Dlog4j.shutdownHookEnabled=false
-Dlog4j2.disable.jmx=true

# Explicitly allow security manager (https://bugs.openjdk.java.net/browse/JDK-8270380)
18-:-Djava.security.manager=allow

# HDFS ForkJoinPool.common() support by SecurityManager
-Djava.util.concurrent.ForkJoinPool.common.threadFactory=org.opensearch.secure_sm.SecuredForkJoinWorkerThreadFactory

# Networking
-Djava.net.preferIPv4Stack=true

# Locale
-Duser.timezone=UTC
-Duser.country=US
-Duser.language=en
EOF

    # 设置内存锁定配置
    if ! grep -q "opensearch" /etc/security/limits.conf; then
        echo "opensearch soft memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
        echo "opensearch hard memlock unlimited" | sudo tee -a /etc/security/limits.conf > /dev/null
    fi
    
    # 创建systemd override目录和配置
    sudo mkdir -p /etc/systemd/system/opensearch.service.d/
    sudo tee /etc/systemd/system/opensearch.service.d/override.conf > /dev/null << 'EOF'
[Service]
LimitMEMLOCK=infinity
LimitNOFILE=65535
EOF

    echo -e "  ${CHECK_MARK} OpenSearch配置已优化 (适用于Magento2产品搜索)"
    echo -e "  ${INFO_MARK} JVM堆内存: ${OPENSEARCH_MEMORY_GB}GB"
    
    # 验证OpenSearch配置
    echo -e "  ${INFO_MARK} 验证OpenSearch配置..."
    validate_opensearch_config
    
    # 验证关键配置
    echo -e "  ${INFO_MARK} 验证OpenSearch配置..."
    validate_config "opensearch" "$OPENSEARCH_JVM_CONFIG" "${OPENSEARCH_MEMORY_GB}g" "-Xmx"
}

optimize_rabbitmq() {
    echo -e "${GEAR} ${CYAN}优化RabbitMQ配置...${NC}"
    
    # 计算内存分配
    calculate_memory_allocation $TOTAL_RAM_GB
    
    create_backup "$RABBITMQ_CONFIG" "rabbitmq.conf"
    create_backup "$RABBITMQ_ENV_CONFIG" "rabbitmq-env.conf"
    
    # 创建优化的RabbitMQ配置
    sudo tee "$RABBITMQ_CONFIG" > /dev/null << EOF
# RabbitMQ Configuration for Magento2 Multi-Site
# Optimized for ${TOTAL_RAM_GB}GB RAM server with ${SITES_COUNT} Magento2 sites

# Memory Settings (使用${RABBITMQ_MEMORY_GB}GB给RabbitMQ)
vm_memory_high_watermark.relative = 0.6
vm_memory_high_watermark_paging_ratio = 0.5

# Disk Settings
disk_free_limit.absolute = 2GB
disk_free_limit.relative = 2.0

# Connection Settings
num_acceptors.tcp = 10
handshake_timeout = 10000
heartbeat = 60
tcp_listen_options.backlog = 128
tcp_listen_options.nodelay = true
tcp_listen_options.keepalive = true

# Channel and Queue Settings
channel_max = 2048
frame_max = 131072
queue_master_locator = min-masters

# Logging Settings
log.console = true
log.console.level = info
log.file = /var/log/rabbitmq/rabbitmq.log
log.file.level = info
log.file.rotation.date = $D0
log.file.rotation.size = 10485760

# Management Plugin (可选，用于监控)
management.tcp.port = 15672
management.tcp.ip = 127.0.0.1

# Performance Settings
collect_statistics_interval = 5000
tcp_listen_options.sndbuf = 196608
tcp_listen_options.recbuf = 196608

# Security Settings
default_user_tags.administrator = true
EOF

    # 创建RabbitMQ环境配置
    sudo tee "$RABBITMQ_ENV_CONFIG" > /dev/null << EOF
# RabbitMQ Environment Configuration for Magento2
# Optimized for ${TOTAL_RAM_GB}GB RAM server

# Memory Settings
RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.6

# Node Settings
RABBITMQ_NODE_IP_ADDRESS=127.0.0.1
RABBITMQ_NODE_PORT=5672

# Log Settings
RABBITMQ_LOG_BASE=/var/log/rabbitmq
RABBITMQ_MNESIA_BASE=/var/lib/rabbitmq/mnesia

# Performance Settings
RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="+S 2:2"
EOF

    # 创建日志目录
    sudo mkdir -p /var/log/rabbitmq
    sudo chown -R rabbitmq:rabbitmq /var/log/rabbitmq
    
    # 设置systemd限制
    sudo mkdir -p /etc/systemd/system/rabbitmq-server.service.d/
    sudo tee /etc/systemd/system/rabbitmq-server.service.d/override.conf > /dev/null << 'EOF'
[Service]
LimitNOFILE=65535
LimitNPROC=32768
EOF

    echo -e "  ${CHECK_MARK} RabbitMQ配置已优化 (适用于Magento2队列处理)"
    echo -e "  ${INFO_MARK} 内存限制: ${RABBITMQ_MEMORY_GB}GB"
    echo -e "  ${INFO_MARK} 磁盘限制: 2GB"
    
    # 验证RabbitMQ配置
    echo -e "  ${INFO_MARK} 验证RabbitMQ配置..."
    validate_rabbitmq_config
}

# RabbitMQ配置验证函数
validate_rabbitmq_config() {
    echo -e "  ${INFO_MARK} 检查RabbitMQ配置文件..."
    
    # 检查配置文件是否存在
    if [[ ! -f "$RABBITMQ_CONFIG" ]]; then
        echo -e "  ${CROSS_MARK} RabbitMQ配置文件不存在: $RABBITMQ_CONFIG"
        return 1
    fi
    
    # 检查关键配置是否存在
    local memory_watermark=$(sudo grep "vm_memory_high_watermark.relative" "$RABBITMQ_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local disk_limit=$(sudo grep "disk_free_limit.absolute" "$RABBITMQ_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    
    if [[ "$memory_watermark" == "0.6" ]]; then
        echo -e "  ${CHECK_MARK} 内存水位线配置正确: $memory_watermark"
    else
        echo -e "  ${CROSS_MARK} 内存水位线配置异常: $memory_watermark"
        return 1
    fi
    
    if [[ "$disk_limit" == "2GB" ]]; then
        echo -e "  ${CHECK_MARK} 磁盘限制配置正确: $disk_limit"
    else
        echo -e "  ${CROSS_MARK} 磁盘限制配置异常: $disk_limit"
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} RabbitMQ配置文件语法正确"
    return 0
}

# 强制重新优化 - 清理所有混合配置
force_reoptimize() {
    echo -e "${WARNING_MARK} ${YELLOW}强制重新优化 - 清理混合配置...${NC}"
    echo -e "  ${INFO_MARK} 这将清理所有旧的优化配置，确保配置一致性"
    echo
    
    # 清理所有配置文件中的旧优化配置
    echo -e "  ${GEAR} 清理PHP-FPM混合配置..."
    clean_config "$PHP_FPM_CONFIG" "php-fpm"
    
    echo -e "  ${GEAR} 清理Valkey混合配置..."
    clean_config "$VALKEY_CONFIG" "valkey"
    
    echo -e "  ${GEAR} 清理MySQL配置（完全重写）..."
    # MySQL配置完全重写，不需要特殊清理
    
    echo -e "  ${GEAR} 清理Nginx配置（完全重写）..."
    # Nginx配置完全重写，不需要特殊清理
    
    echo -e "  ${GEAR} 清理OpenSearch配置（完全重写）..."
    # OpenSearch配置完全重写，不需要特殊清理
    
    echo -e "  ${CHECK_MARK} 配置清理完成，开始重新优化..."
    echo
    
    # 重新运行优化
    optimize_mysql
    optimize_php_fpm
    optimize_nginx
    optimize_valkey
    optimize_rabbitmq
    optimize_opensearch
}

restart_services() {
    echo -e "${GEAR} ${CYAN}重启相关服务...${NC}"
    
    # 先重载systemd配置，避免警告
    sudo systemctl daemon-reload
    
    sudo systemctl restart mysql && echo -e "  ${CHECK_MARK} MySQL已重启"
    sudo systemctl restart php8.3-fpm && echo -e "  ${CHECK_MARK} PHP-FPM已重启"
    sudo systemctl restart nginx && echo -e "  ${CHECK_MARK} Nginx已重启"
    sudo systemctl restart valkey && echo -e "  ${CHECK_MARK} Valkey已重启"
    sudo systemctl restart rabbitmq-server && echo -e "  ${CHECK_MARK} RabbitMQ已重启"
    sudo systemctl restart opensearch && echo -e "  ${CHECK_MARK} OpenSearch已重启"
    
    # 验证OpenSearch服务启动
    echo -e "  ${INFO_MARK} 验证OpenSearch服务启动..."
    sleep 10  # 等待服务启动
    if systemctl is-active --quiet opensearch; then
        echo -e "  ${CHECK_MARK} OpenSearch服务启动成功"
        
        # 测试OpenSearch连接
        if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
            echo -e "  ${CHECK_MARK} OpenSearch API连接正常"
        else
            echo -e "  ${WARNING_MARK} OpenSearch API连接异常，请检查日志"
        fi
    else
        echo -e "  ${CROSS_MARK} OpenSearch服务启动失败"
        echo -e "  ${INFO_MARK} 请检查日志: sudo journalctl -u opensearch -n 20"
    fi
    echo -e "  ${INFO_MARK} 清理Swap空间..."
    local swap_before=$(free | grep Swap | awk '{print $3}')
    if [[ $swap_before -gt 0 ]]; then
        sudo swapoff -a && sudo swapon -a
        local swap_after=$(free | grep Swap | awk '{print $3}')
        echo -e "  ${CHECK_MARK} Swap已清理: ${swap_before}KB → ${swap_after}KB"
    else
        echo -e "  ${INFO_MARK} Swap使用率为0%，无需清理"
    fi
}

show_optimization_status() {
    # 计算建议配置
    calculate_memory_allocation $TOTAL_RAM_GB
    
    echo -e "${INFO_MARK} ${CYAN}Magento2优化状态详细对比:${NC}"
    echo
    echo -e "${YELLOW}📊 配置对比表 (建议值 vs 当前值):${NC}"
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ 服务配置项                    │ 建议值 (${TOTAL_RAM_GB}GB) │ 当前值 │ 状态 │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    # MySQL配置检查
    local mysql_buffer=$(sudo grep "innodb_buffer_pool_size" "$MYSQL_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*= *//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    local mysql_instances=$(sudo grep "innodb_buffer_pool_instances" "$MYSQL_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*= *//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    local mysql_connections=$(sudo grep "max_connections" "$MYSQL_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*= *//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    local mysql_thread_cache=$(sudo grep "thread_cache_size" "$MYSQL_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*= *//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    
    # MySQL状态检查
    local mysql_buffer_status="❌"
    [[ "$mysql_buffer" == "${MYSQL_MEMORY_GB}G" ]] && mysql_buffer_status="✅"
    local mysql_instances_status="❌"
    [[ "$mysql_instances" == "$MYSQL_INSTANCES" ]] && mysql_instances_status="✅"
    local mysql_connections_status="❌"
    [[ "$mysql_connections" == "$MYSQL_MAX_CONNECTIONS" ]] && mysql_connections_status="✅"
    local mysql_thread_cache_status="❌"
    [[ "$mysql_thread_cache" == "$MYSQL_THREAD_CACHE" ]] && mysql_thread_cache_status="✅"
    
    echo -e "${BLUE}│ MySQL InnoDB Buffer Pool     │ ${MYSQL_MEMORY_GB}G                    │ ${mysql_buffer:0:8} │ ${mysql_buffer_status} │${NC}"
    echo -e "${BLUE}│ MySQL Buffer Pool Instances  │ ${MYSQL_INSTANCES}个                   │ ${mysql_instances:0:8} │ ${mysql_instances_status} │${NC}"
    echo -e "${BLUE}│ MySQL Max Connections        │ ${MYSQL_MAX_CONNECTIONS}                    │ ${mysql_connections:0:8} │ ${mysql_connections_status} │${NC}"
    echo -e "${BLUE}│ MySQL Thread Cache Size      │ ${MYSQL_THREAD_CACHE}                     │ ${mysql_thread_cache:0:8} │ ${mysql_thread_cache_status} │${NC}"
    
    # OpenSearch配置检查
    local opensearch_heap=$(sudo grep "^-Xmx" "$OPENSEARCH_JVM_CONFIG" 2>/dev/null | sed 's/.*-Xmx//' || echo "未设置")
    local opensearch_status="❌"
    [[ "$opensearch_heap" == "${OPENSEARCH_MEMORY_GB}g" ]] && opensearch_status="✅"
    
    echo -e "${BLUE}│ OpenSearch JVM Heap Size     │ ${OPENSEARCH_MEMORY_GB}g                   │ ${opensearch_heap:0:8} │ ${opensearch_status} │${NC}"
    
    # Valkey配置检查
    local valkey_memory=$(sudo grep "^maxmemory " "$VALKEY_CONFIG" 2>/dev/null | head -1 | sed 's/.*maxmemory //' || echo "未设置")
    local valkey_policy=$(sudo grep "^maxmemory-policy " "$VALKEY_CONFIG" 2>/dev/null | head -1 | sed 's/.*maxmemory-policy //' || echo "未设置")
    local valkey_memory_status="❌"
    [[ "$valkey_memory" == "${VALKEY_MEMORY_GB}gb" ]] && valkey_memory_status="✅"
    local valkey_policy_status="❌"
    [[ "$valkey_policy" == "allkeys-lru" ]] && valkey_policy_status="✅"
    
    echo -e "${BLUE}│ Valkey Max Memory            │ ${VALKEY_MEMORY_GB}gb                   │ ${valkey_memory:0:8} │ ${valkey_memory_status} │${NC}"
    echo -e "${BLUE}│ Valkey Eviction Policy       │ allkeys-lru            │ ${valkey_policy:0:8} │ ${valkey_policy_status} │${NC}"
    
    # PHP-FPM配置检查
    local php_fpm_max_children=$(sudo grep "pm.max_children" "$PHP_FPM_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local php_fpm_start_servers=$(sudo grep "pm.start_servers" "$PHP_FPM_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local php_fpm_min_spare=$(sudo grep "pm.min_spare_servers" "$PHP_FPM_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local php_fpm_max_spare=$(sudo grep "pm.max_spare_servers" "$PHP_FPM_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    local php_fpm_max_requests=$(sudo grep "pm.max_requests" "$PHP_FPM_CONFIG" 2>/dev/null | sed 's/.*= *//' || echo "未设置")
    
    local php_fpm_max_children_status="❌"
    [[ "$php_fpm_max_children" == "$PHP_MAX_CHILDREN" ]] && php_fpm_max_children_status="✅"
    # 计算期望的PHP-FPM进程池设置
    local expected_start_servers=30
    local expected_min_spare=24
    local expected_max_spare=40
    
    if [[ $TOTAL_RAM_GB -eq 64 ]]; then
        expected_start_servers=20
        expected_min_spare=16
        expected_max_spare=30
    elif [[ $TOTAL_RAM_GB -eq 256 ]]; then
        expected_start_servers=40
        expected_min_spare=32
        expected_max_spare=50
    fi
    
    local php_fpm_start_servers_status="❌"
    [[ "$php_fpm_start_servers" == "$expected_start_servers" ]] && php_fpm_start_servers_status="✅"
    local php_fpm_min_spare_status="❌"
    [[ "$php_fpm_min_spare" == "$expected_min_spare" ]] && php_fpm_min_spare_status="✅"
    local php_fpm_max_spare_status="❌"
    [[ "$php_fpm_max_spare" == "$expected_max_spare" ]] && php_fpm_max_spare_status="✅"
    local php_fpm_max_requests_status="❌"
    [[ "$php_fpm_max_requests" == "500" ]] && php_fpm_max_requests_status="✅"
    
    echo -e "${BLUE}│ PHP-FPM Max Children          │ ${PHP_MAX_CHILDREN}个                   │ ${php_fpm_max_children:0:8} │ ${php_fpm_max_children_status} │${NC}"
    echo -e "${BLUE}│ PHP-FPM Start Servers        │ ${expected_start_servers}个                   │ ${php_fpm_start_servers:0:8} │ ${php_fpm_start_servers_status} │${NC}"
    echo -e "${BLUE}│ PHP-FPM Min Spare Servers    │ ${expected_min_spare}个                   │ ${php_fpm_min_spare:0:8} │ ${php_fpm_min_spare_status} │${NC}"
    echo -e "${BLUE}│ PHP-FPM Max Spare Servers    │ ${expected_max_spare}个                   │ ${php_fpm_max_spare:0:8} │ ${php_fpm_max_spare_status} │${NC}"
    echo -e "${BLUE}│ PHP-FPM Max Requests         │ 500                    │ ${php_fpm_max_requests:0:8} │ ${php_fpm_max_requests_status} │${NC}"
    
    # PHP内存限制检查
    local php_fpm_memory=$(sudo grep "memory_limit" "$PHP_FPM_INI_CONFIG" 2>/dev/null | grep -v "^;" | sed 's/.*= *//' || echo "未设置")
    local php_cli_memory=$(sudo grep "memory_limit" "$PHP_CLI_INI_CONFIG" 2>/dev/null | grep -v "^;" | sed 's/.*= *//' || echo "未设置")
    local php_fpm_memory_status="❌"
    [[ "$php_fpm_memory" == "2G" ]] && php_fpm_memory_status="✅"
    local php_cli_memory_status="❌"
    [[ "$php_cli_memory" == "4G" ]] && php_cli_memory_status="✅"
    
    echo -e "${BLUE}│ PHP-FPM Memory Limit         │ 2G                     │ ${php_fpm_memory:0:8} │ ${php_fpm_memory_status} │${NC}"
    echo -e "${BLUE}│ PHP-CLI Memory Limit         │ 4G                     │ ${php_cli_memory:0:8} │ ${php_cli_memory_status} │${NC}"
    
    # Nginx配置检查
    local nginx_workers=$(sudo grep "worker_processes" "$NGINX_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*worker_processes *//' | sed 's/;//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    local nginx_connections=$(sudo grep "worker_connections" "$NGINX_CONFIG" 2>/dev/null | grep -v "^#" | sed 's/.*worker_connections *//' | sed 's/;//' | sed 's/#.*//' | sed 's/ *$//' || echo "未设置")
    local nginx_workers_status="❌"
    [[ "$nginx_workers" == "auto" ]] && nginx_workers_status="✅"
    local nginx_connections_status="❌"
    [[ "$nginx_connections" == "$NGINX_WORKER_CONNECTIONS" ]] && nginx_connections_status="✅"
    
    echo -e "${BLUE}│ Nginx Worker Processes       │ auto                   │ ${nginx_workers:0:8} │ ${nginx_workers_status} │${NC}"
    echo -e "${BLUE}│ Nginx Worker Connections     │ ${NGINX_WORKER_CONNECTIONS}                   │ ${nginx_connections:0:8} │ ${nginx_connections_status} │${NC}"
    
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    
    # 计算优化状态
    local total_checks=0
    local passed_checks=0
    
    # MySQL检查
    [[ "$mysql_buffer" == "${MYSQL_MEMORY_GB}G" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$mysql_instances" == "$MYSQL_INSTANCES" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$mysql_connections" == "$MYSQL_MAX_CONNECTIONS" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$mysql_thread_cache" == "$MYSQL_THREAD_CACHE" ]] && ((passed_checks++))
    ((total_checks++))
    
    # OpenSearch检查
    [[ "$opensearch_heap" == "${OPENSEARCH_MEMORY_GB}g" ]] && ((passed_checks++))
    ((total_checks++))
    
    # Valkey检查
    [[ "$valkey_memory" == "${VALKEY_MEMORY_GB}gb" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$valkey_policy" == "allkeys-lru" ]] && ((passed_checks++))
    ((total_checks++))
    
    # PHP-FPM检查
    [[ "$php_fpm_max_children" == "$PHP_MAX_CHILDREN" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$php_fpm_start_servers" == "$expected_start_servers" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$php_fpm_min_spare" == "$expected_min_spare" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$php_fpm_max_spare" == "$expected_max_spare" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$php_fpm_max_requests" == "500" ]] && ((passed_checks++))
    ((total_checks++))
    
    # PHP内存检查
    [[ "$php_fpm_memory" == "2G" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$php_cli_memory" == "4G" ]] && ((passed_checks++))
    ((total_checks++))
    
    # Nginx检查
    [[ "$nginx_workers" == "auto" ]] && ((passed_checks++))
    ((total_checks++))
    [[ "$nginx_connections" == "$NGINX_WORKER_CONNECTIONS" ]] && ((passed_checks++))
    ((total_checks++))
    
    # 显示优化状态总结
    local optimization_percentage=$((passed_checks * 100 / total_checks))
    echo -e "${CYAN}📈 优化状态总结:${NC}"
    echo -e "  ${GREEN}✅ 已优化: ${passed_checks}/${total_checks} 项配置${NC}"
    echo -e "  ${YELLOW}📊 优化完成度: ${optimization_percentage}%${NC}"
    
    if [[ $optimization_percentage -ge 90 ]]; then
        echo -e "  ${GREEN}🎉 系统已完全优化！${NC}"
    elif [[ $optimization_percentage -ge 70 ]]; then
        echo -e "  ${YELLOW}⚠️  系统大部分已优化，建议运行完整优化${NC}"
    else
        echo -e "  ${RED}❌ 系统需要优化，建议运行: ./magento2-optimizer.sh ${TOTAL_RAM_GB} optimize${NC}"
    fi
    
    echo
    echo -e "${CYAN}💡 提示:${NC}"
    echo -e "  • 运行 ${GREEN}./magento2-optimizer.sh ${TOTAL_RAM_GB} optimize${NC} 应用完整优化"
    echo -e "  • 运行 ${YELLOW}./magento2-optimizer.sh ${TOTAL_RAM_GB} restore${NC} 还原原始配置"
    echo
}

# 单独优化MySQL配置
optimize_mysql_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化MySQL配置...${NC}"
    echo
    optimize_mysql
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启MySQL服务...${NC}"
    sudo systemctl restart mysql && echo -e "  ${CHECK_MARK} MySQL已重启"
    echo
    echo -e "${CHECK_MARK} ${GREEN}MySQL优化完成！${NC}"
}

# 单独优化PHP配置
optimize_php_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化PHP配置...${NC}"
    echo
    optimize_php_fpm
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启PHP-FPM服务...${NC}"
    sudo systemctl restart php8.3-fpm && echo -e "  ${CHECK_MARK} PHP-FPM已重启"
    echo
    echo -e "${CHECK_MARK} ${GREEN}PHP优化完成！${NC}"
}

# 单独优化Nginx配置
optimize_nginx_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化Nginx配置...${NC}"
    echo
    optimize_nginx
    echo
    echo -e "${INFO_MARK} ${YELLOW}测试并重启Nginx服务...${NC}"
    if sudo nginx -t; then
        sudo systemctl restart nginx && echo -e "  ${CHECK_MARK} Nginx已重启"
        echo -e "${CHECK_MARK} ${GREEN}Nginx优化完成！${NC}"
    else
        echo -e "  ${CROSS_MARK} ${RED}Nginx配置测试失败${NC}"
    fi
}

# 单独优化Valkey配置
optimize_valkey_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化Valkey配置...${NC}"
    echo
    optimize_valkey
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启Valkey服务...${NC}"
    sudo systemctl restart valkey && echo -e "  ${CHECK_MARK} Valkey已重启"
    echo
    echo -e "${CHECK_MARK} ${GREEN}Valkey优化完成！${NC}"
}

# 单独优化RabbitMQ配置
optimize_rabbitmq_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化RabbitMQ配置...${NC}"
    echo
    optimize_rabbitmq
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启RabbitMQ服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl restart rabbitmq-server && echo -e "  ${CHECK_MARK} RabbitMQ已重启"
    echo
    echo -e "${CHECK_MARK} ${GREEN}RabbitMQ优化完成！${NC}"
# 单独优化OpenSearch配置
optimize_opensearch_only() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始优化OpenSearch配置...${NC}"
    echo
    optimize_opensearch
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启OpenSearch服务...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl restart opensearch && echo -e "  ${CHECK_MARK} OpenSearch已重启"
    echo
    echo -e "${CHECK_MARK} ${GREEN}OpenSearch优化完成！${NC}"
}

optimize_all() {
    print_header
    echo -e "${ROCKET} ${GREEN}开始应用Magento2性能优化...${NC}"
    echo
    
    # 优化前系统监控
    echo -e "${MONITOR_MARK} ${CYAN}优化前系统状态:${NC}"
    monitor_system_resources
    
    optimize_mysql
    optimize_php_fpm
    optimize_nginx
    optimize_valkey
    optimize_rabbitmq
    optimize_opensearch
    
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启服务以应用配置...${NC}"
    restart_services
    
    echo
    echo -e "${CHECK_MARK} ${GREEN}Magento2性能优化完成！${NC}"
    echo
    
    # 优化后系统监控
    echo -e "${MONITOR_MARK} ${CYAN}优化后系统状态:${NC}"
    monitor_system_resources
    
    show_optimization_status
    
    echo -e "${INFO_MARK} ${CYAN}优化建议:${NC}"
    echo -e "  • 配置Magento2使用Valkey进行会话存储"
    echo -e "  • 配置Magento2使用OpenSearch作为搜索引擎"
    echo -e "  • 启用Magento2的生产模式"
    echo -e "  • 配置Varnish作为全页缓存"
    echo -e "  • 定期运行 magento setup:di:compile"
    echo -e "  • 重建OpenSearch索引: magento indexer:reindex catalogsearch_fulltext"
    echo
    echo -e "${INFO_MARK} ${YELLOW}多站点配置建议:${NC}"
    echo -e "  • 为每个站点创建独立的OpenSearch索引"
    echo -e "  • 配置站点特定的缓存策略"
    echo -e "  • 监控各站点的资源使用情况"
    echo
    echo -e "${INFO_MARK} ${YELLOW}ModSecurity级别说明:${NC}"
    echo -e "  • 当前级别1: 极低敏感度，适合Magento2生产环境"
    echo -e "  • 如需调整: ./scripts/toggle-modsecurity.sh [0-10]"
    echo -e "  • 后台菜单问题: 确保级别设置为1-2"
    echo
    echo -e "${INFO_MARK} ${CYAN}新增功能:${NC}"
    echo -e "  • 运行 ${GREEN}$0 ${TOTAL_RAM_GB} monitor${NC} 进行系统监控"
    echo -e "  • 运行 ${GREEN}$0 ${TOTAL_RAM_GB} benchmark${NC} 进行性能测试"
    echo -e "  • 运行 ${GREEN}$0 ${TOTAL_RAM_GB} suggest${NC} 获取配置建议"
    echo
    echo -e "${WARNING_MARK} ${YELLOW}重要提醒:${NC}"
    echo -e "  • 优化脚本会完全重写MySQL、Nginx、OpenSearch配置"
    echo -e "  • PHP-FPM和Valkey配置会追加新的优化设置"
    echo -e "  • 如有自定义配置，请先备份或使用restore功能"
    echo -e "  • 备份文件保存在: /opt/lemp-backups/magento2-optimizer/"
    echo
}

# 单独还原MySQL配置
restore_mysql() {
    echo -e "${WARNING_MARK} ${YELLOW}还原MySQL配置...${NC}"
    if restore_backup "$MYSQL_CONFIG" "mysqld.cnf"; then
        sudo systemctl restart mysql
        echo -e "${CHECK_MARK} ${GREEN}MySQL配置已还原并重启服务${NC}"
    else
        echo -e "${CROSS_MARK} ${RED}MySQL配置还原失败${NC}"
    fi
}

# 单独还原PHP配置
restore_php() {
    echo -e "${WARNING_MARK} ${YELLOW}还原PHP配置...${NC}"
    local restore_count=0
    restore_backup "$PHP_FPM_CONFIG" "www.conf" && ((restore_count++))
    restore_backup "$PHP_FPM_INI_CONFIG" "php-fpm.ini" && ((restore_count++))
    restore_backup "$PHP_CLI_INI_CONFIG" "php-cli.ini" && ((restore_count++))
    
    if [[ $restore_count -gt 0 ]]; then
        sudo systemctl restart php8.3-fpm
        echo -e "${CHECK_MARK} ${GREEN}PHP配置已还原并重启服务${NC}"
    else
        echo -e "${CROSS_MARK} ${RED}PHP配置还原失败${NC}"
    fi
}

# 单独还原Nginx配置
restore_nginx() {
    echo -e "${WARNING_MARK} ${YELLOW}还原Nginx到精简基础配置...${NC}"
    
    # 获取当前nginx用户设置，保持不变
    local current_user
    if [[ -f "$NGINX_CONFIG" ]]; then
        current_user=$(grep "^user " "$NGINX_CONFIG" | head -1 | awk '{print $2}' | sed 's/;//')
        if [[ -z "$current_user" ]]; then
            current_user="www-data"  # 默认用户
        fi
    else
        current_user="www-data"  # 默认用户
    fi
    
    echo -e "  ${INFO_MARK} 保持nginx用户为: ${current_user}"
    echo -e "  ${INFO_MARK} 使用最精简配置 (无ModSecurity、无缓存、无速率限制)"
    
    # 创建备份
    create_backup "$NGINX_CONFIG" "nginx.conf"
    
    # 使用精简配置但保持当前用户
    sudo cp /opt/lemp-backups/magento2-optimizer/nginx.conf.minimal "$NGINX_CONFIG"
    sudo sed -i "s/^user doge;/user ${current_user};/" "$NGINX_CONFIG"
    
    # 确保站点配置兼容 - 注释掉所有ModSecurity指令
    echo -e "  ${INFO_MARK} 清理站点配置中的ModSecurity指令..."
    for site_config in /etc/nginx/sites-available/*.conf; do
        if [[ -f "$site_config" ]]; then
            sudo sed -i 's/modsecurity off;/#modsecurity off;/' "$site_config" 2>/dev/null || true
            sudo sed -i 's/modsecurity on;/#modsecurity on;/' "$site_config" 2>/dev/null || true
        fi
    done
    
    echo -e "${INFO_MARK} ${YELLOW}测试Nginx配置...${NC}"
    if sudo nginx -t; then
        sudo systemctl restart nginx
        echo -e "${CHECK_MARK} ${GREEN}Nginx已还原为精简基础配置并重启服务${NC}"
        echo -e "  ${INFO_MARK} ${CYAN}当前配置特点:${NC}"
        echo -e "    • 无ModSecurity WAF"
        echo -e "    • 无FastCGI缓存"
        echo -e "    • 无速率限制"  
        echo -e "    • 无安全头部"
        echo -e "    • keepalive_timeout: 65秒"
        echo -e "    • 基础Gzip压缩"
        echo -e "    • 适合Magento2基础运行"
    else
        echo -e "${CROSS_MARK} ${RED}Nginx配置测试失败${NC}"
        # 如果失败，尝试恢复原配置
        if restore_backup "$NGINX_CONFIG" "nginx.conf"; then
            echo -e "${INFO_MARK} ${YELLOW}已回滚到上一个配置${NC}"
            sudo nginx -t && sudo systemctl restart nginx
        fi
    fi
}

# 单独还原Valkey配置
restore_valkey() {
    echo -e "${WARNING_MARK} ${YELLOW}还原Valkey配置...${NC}"
    if restore_backup "$VALKEY_CONFIG" "valkey.conf"; then
        sudo systemctl restart valkey
        echo -e "${CHECK_MARK} ${GREEN}Valkey配置已还原并重启服务${NC}"
    else
        echo -e "${CROSS_MARK} ${RED}Valkey配置还原失败${NC}"
    fi
}

# 单独还原RabbitMQ配置
restore_rabbitmq() {
    echo -e "${WARNING_MARK} ${YELLOW}还原RabbitMQ配置...${NC}"
    local restore_count=0
    restore_backup "$RABBITMQ_CONFIG" "rabbitmq.conf" && ((restore_count++))
    restore_backup "$RABBITMQ_ENV_CONFIG" "rabbitmq-env.conf" && ((restore_count++))
    
    if [[ $restore_count -gt 0 ]]; then
        sudo systemctl daemon-reload
        sudo systemctl restart rabbitmq-server
        echo -e "${CHECK_MARK} ${GREEN}RabbitMQ配置已还原并重启服务${NC}"
    else
        echo -e "${CROSS_MARK} ${RED}RabbitMQ配置还原失败${NC}"
    fi
}
    echo -e "${WARNING_MARK} ${YELLOW}还原OpenSearch配置...${NC}"
    local restore_count=0
    restore_backup "$OPENSEARCH_CONFIG" "opensearch.yml" && ((restore_count++))
    restore_backup "$OPENSEARCH_JVM_CONFIG" "jvm.options" && ((restore_count++))
    
    if [[ $restore_count -gt 0 ]]; then
        sudo systemctl daemon-reload
        sudo systemctl restart opensearch
        echo -e "${CHECK_MARK} ${GREEN}OpenSearch配置已还原并重启服务${NC}"
    else
        echo -e "${CROSS_MARK} ${RED}OpenSearch配置还原失败${NC}"
    fi
}

restore_all() {
    print_header
    echo -e "${WARNING_MARK} ${YELLOW}开始还原原始配置...${NC}"
    echo
    
    local restore_count=0
    
    restore_backup "$MYSQL_CONFIG" "mysqld.cnf" && ((restore_count++))
    restore_backup "$PHP_FPM_CONFIG" "www.conf" && ((restore_count++))
    restore_backup "$PHP_FPM_INI_CONFIG" "php-fpm.ini" && ((restore_count++))
    restore_backup "$PHP_CLI_INI_CONFIG" "php-cli.ini" && ((restore_count++))
    restore_backup "$NGINX_CONFIG" "nginx.conf" && ((restore_count++))
    restore_backup "$VALKEY_CONFIG" "valkey.conf" && ((restore_count++))
    restore_backup "$RABBITMQ_CONFIG" "rabbitmq.conf" && ((restore_count++))
    restore_backup "$RABBITMQ_ENV_CONFIG" "rabbitmq-env.conf" && ((restore_count++))
    restore_backup "$OPENSEARCH_CONFIG" "opensearch.yml" && ((restore_count++))
    restore_backup "$OPENSEARCH_JVM_CONFIG" "jvm.options" && ((restore_count++))
    
    if [[ $restore_count -gt 0 ]]; then
        echo
        echo -e "${INFO_MARK} ${YELLOW}重启服务以应用原始配置...${NC}"
        restart_services
        echo
        echo -e "${CHECK_MARK} ${GREEN}配置已还原完成！${NC}"
    else
        echo -e "${WARNING_MARK} ${YELLOW}未找到可还原的备份文件${NC}"
    fi
    echo
}

# 主程序
main() {
    # 检查第一个参数是否为内存大小
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        TOTAL_RAM_GB=$1
        shift  # 移除内存参数，剩下的参数传给后续处理
        
        # 验证内存大小
        if [[ ! "$TOTAL_RAM_GB" =~ ^(64|128|256)$ ]]; then
            echo -e "${RED}错误: 不支持的内存大小 '$TOTAL_RAM_GB'${NC}"
            echo -e "${YELLOW}支持的内存大小: 64, 128, 256${NC}"
            echo
            print_help
            exit 1
        fi
    fi
    
    case "${1:-help}" in
        "optimize")
            case "${2}" in
                "mysql")
                    optimize_mysql_only
                    ;;
                "php")
                    optimize_php_only
                    ;;
                "nginx")
                    optimize_nginx_only
                    ;;
                "valkey")
                    optimize_valkey_only
                    ;;
                "rabbitmq")
                    optimize_rabbitmq_only
                    ;;
                "opensearch")
                    optimize_opensearch_only
                    ;;
                "")
                    optimize_all
                    ;;
                *)
                    echo -e "${RED}错误: 未知的优化选项 '$2'${NC}"
                    echo -e "${YELLOW}支持的选项: mysql, php, nginx, valkey, opensearch${NC}"
                    echo
                    print_help
                    exit 1
                    ;;
            esac
            ;;
        "restore")
            case "${2}" in
                "mysql")
                    restore_mysql
                    ;;
                "php")
                    restore_php
                    ;;
                "nginx")
                    restore_nginx
                    ;;
                "valkey")
                    restore_valkey
                    ;;
                "rabbitmq")
                    restore_rabbitmq
                    ;;
                "opensearch")
                    restore_opensearch
                    ;;
                "")
                    restore_all
                    ;;
                *)
                    echo -e "${RED}错误: 未知的还原选项 '$2'${NC}"
                    echo -e "${YELLOW}支持的选项: mysql, php, nginx, valkey, opensearch${NC}"
                    echo
                    print_help
                    exit 1
                    ;;
            esac
            ;;
        "status")
            print_header
            show_optimization_status
            ;;
        "monitor")
            print_header
            monitor_system_resources
            monitor_services_status
            ;;
        "benchmark")
            print_header
            performance_benchmark
            ;;
        "suggest")
            print_header
            adaptive_config_suggestions
            ;;
        "force-reoptimize")
            print_header
            force_reoptimize
            ;;
        "help"|"--help"|"-h")
            print_help
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            echo
            print_help
            exit 1
            ;;
    esac
}

# 检查是否以root权限运行
if [[ $EUID -eq 0 ]]; then
    echo -e "${WARNING_MARK} ${YELLOW}警告: 请不要以root身份直接运行此脚本${NC}"
    echo -e "使用: ${GREEN}./magento2-optimizer.sh [64|128|256] optimize${NC}"
    exit 1
fi

# 运行主程序
main "$@"
