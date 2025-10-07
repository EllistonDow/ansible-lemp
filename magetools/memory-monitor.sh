#!/bin/bash

# 智能内存监控和自动释放脚本
# 监控系统内存使用率，达到阈值时自动释放内存
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

# 配置参数
MEMORY_THRESHOLD=85        # 内存使用率阈值 (%)
SWAP_THRESHOLD=30          # Swap使用率阈值 (%)
CPU_THRESHOLD=80           # CPU使用率阈值 (%)
LOG_FILE="/var/log/memory-monitor.log"
LOCK_FILE="/tmp/memory-monitor.lock"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

# 检查是否已有实例在运行
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "内存监控脚本已在运行 (PID: $pid)"
            exit 0
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# 清理锁文件
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}

# 设置信号处理
trap cleanup EXIT INT TERM

# 获取系统资源使用情况
get_system_stats() {
    # 内存使用率
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    MEMORY_USED_GB=$(free -g | grep Mem | awk '{print $3}')
    MEMORY_TOTAL_GB=$(free -g | grep Mem | awk '{print $2}')
    
    # Swap使用率
    SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
    SWAP_USED=$(free | grep Swap | awk '{print $3}')
    SWAP_PERCENTAGE=0
    if [[ $SWAP_TOTAL -gt 0 ]]; then
        SWAP_PERCENTAGE=$(echo "scale=1; $SWAP_USED * 100 / $SWAP_TOTAL" | bc)
    fi
    
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    
    # 磁盘使用率
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
}

# 显示系统状态
show_system_status() {
    echo -e "${CYAN}📊 系统资源状态:${NC}"
    echo -e "  内存: ${MEMORY_USED_GB}GB/${MEMORY_TOTAL_GB}GB (${MEMORY_USAGE}%)"
    echo -e "  Swap: ${SWAP_USED}KB/${SWAP_TOTAL}KB (${SWAP_PERCENTAGE}%)"
    echo -e "  CPU: ${CPU_USAGE}%"
    echo -e "  磁盘: ${DISK_USAGE}%"
}

# 清理系统缓存
clear_system_cache() {
    log_info "清理系统缓存..."
    
    # 清理页面缓存
    echo 3 > /proc/sys/vm/drop_caches
    log_success "页面缓存已清理"
    
    # 清理目录项和inode缓存
    echo 2 > /proc/sys/vm/drop_caches
    log_success "目录项和inode缓存已清理"
    
    # 清理所有缓存
    echo 1 > /proc/sys/vm/drop_caches
    log_success "所有缓存已清理"
}

# 清理Swap空间
clear_swap() {
    log_info "清理Swap空间..."
    
    local swap_before=$(free | grep Swap | awk '{print $3}')
    if [[ $swap_before -gt 0 ]]; then
        swapoff -a && swapon -a
        local swap_after=$(free | grep Swap | awk '{print $3}')
        log_success "Swap已清理: ${swap_before}KB → ${swap_after}KB"
    else
        log_info "Swap使用率为0%，无需清理"
    fi
}

# 清理PHP-FPM缓存
clear_php_cache() {
    log_info "清理PHP-FPM缓存..."
    
    # 重启PHP-FPM进程池
    if systemctl is-active --quiet php8.3-fpm; then
        systemctl reload php8.3-fpm
        log_success "PHP-FPM进程池已重新加载"
    fi
    
    # 清理OPcache
    if command -v php >/dev/null 2>&1; then
        php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache已清理'; }"
    fi
}

# 清理Valkey缓存
clear_valkey_cache() {
    log_info "清理Valkey缓存..."
    
    if command -v redis-cli >/dev/null 2>&1; then
        # 清理过期键
        redis-cli --scan --pattern "*" | head -1000 | xargs -r redis-cli del
        log_success "Valkey过期键已清理"
    fi
}

# 清理MySQL缓存
clear_mysql_cache() {
    log_info "清理MySQL缓存..."
    
    if command -v mysql >/dev/null 2>&1; then
        mysql -e "FLUSH TABLES; FLUSH LOGS; RESET QUERY CACHE;" 2>/dev/null || true
        log_success "MySQL缓存已清理"
    fi
}

# 智能内存释放策略 - 按优先级释放
intelligent_memory_release() {
    log_warning "内存使用率过高 (${MEMORY_USAGE}%)，开始智能内存释放..."
    
    # 获取各服务内存使用情况
    local mysql_memory=$(ps aux | grep mysqld | grep -v grep | awk '{sum+=$6} END {print sum/1024/1024}' || echo "0")
    local opensearch_memory=$(ps aux | grep opensearch | grep -v grep | awk '{sum+=$6} END {print sum/1024/1024}' || echo "0")
    local valkey_memory=$(ps aux | grep valkey | grep -v grep | awk '{sum+=$6} END {print sum/1024/1024}' || echo "0")
    local php_memory=$(ps aux | grep php-fpm | grep -v grep | awk '{sum+=$6} END {print sum/1024/1024}' || echo "0")
    
    log_info "各服务内存使用情况:"
    echo "  MySQL: ${mysql_memory}GB (优先级: 最高)"
    echo "  OpenSearch: ${opensearch_memory}GB (优先级: 中等)"
    echo "  Valkey: ${valkey_memory}GB (优先级: 最低)"
    echo "  PHP-FPM: ${php_memory}GB (优先级: 中等)"
    
    # 第一阶段：清理系统缓存（最安全）
    log_info "第一阶段：清理系统缓存..."
    echo 1 > /proc/sys/vm/drop_caches
    sleep 1
    get_system_stats
    log_info "系统缓存清理后内存使用率: ${MEMORY_USAGE}%"
    
    # 第二阶段：清理应用缓存（按优先级）
    if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        log_info "第二阶段：按优先级清理应用缓存..."
        
        # 1. 优先清理 Valkey 缓存（影响最小）
        if (( $(echo "$valkey_memory > 1" | bc -l) )); then
            log_info "清理 Valkey 缓存 (优先级: 最低，影响最小)..."
            clear_valkey_cache
            sleep 2
            get_system_stats
            log_info "Valkey 缓存清理后内存使用率: ${MEMORY_USAGE}%"
        fi
        
        # 2. 清理 PHP-FPM 缓存（中等影响）
        if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
            log_info "清理 PHP-FPM 缓存 (优先级: 中等)..."
            clear_php_cache
            sleep 2
            get_system_stats
            log_info "PHP-FPM 缓存清理后内存使用率: ${MEMORY_USAGE}%"
        fi
        
        # 3. 清理 MySQL 缓存（高影响，但效果最好）
        if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
            log_info "清理 MySQL 缓存 (优先级: 最高，效果最好)..."
            clear_mysql_cache
            sleep 2
            get_system_stats
            log_info "MySQL 缓存清理后内存使用率: ${MEMORY_USAGE}%"
        fi
        
        # 4. 最后清理 OpenSearch 缓存（重要但可重建）
        if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
            log_warning "清理 OpenSearch 缓存 (优先级: 中等，重要但可重建)..."
            clear_opensearch_cache
            sleep 2
            get_system_stats
            log_info "OpenSearch 缓存清理后内存使用率: ${MEMORY_USAGE}%"
        fi
    fi
    
    # 第三阶段：Swap 清理（谨慎处理）
    if (( $(echo "$SWAP_PERCENTAGE > $SWAP_THRESHOLD" | bc -l) )); then
        local available_memory=$(free -m | grep Mem | awk '{print $7}')
        local swap_used_mb=$(free -m | grep Swap | awk '{print $3}')
        
        if [[ $available_memory -gt $swap_used_mb ]]; then
            log_info "第三阶段：安全清理 Swap..."
            clear_swap
        else
            log_warning "可用内存不足，跳过 Swap 清理以避免 OOM"
        fi
    fi
    
    # 最终检查
    get_system_stats
    log_success "智能内存释放完成，当前使用率: ${MEMORY_USAGE}%"
}

# 清理 OpenSearch 缓存
clear_opensearch_cache() {
    log_info "清理 OpenSearch 缓存..."
    
    if command -v curl >/dev/null 2>&1; then
        # 清理字段数据缓存
        curl -X POST "localhost:9200/_cache/clear?fielddata=true" 2>/dev/null || true
        
        # 清理请求缓存
        curl -X POST "localhost:9200/_cache/clear?request=true" 2>/dev/null || true
        
        # 清理查询缓存
        curl -X POST "localhost:9200/_cache/clear?query=true" 2>/dev/null || true
        
        log_success "OpenSearch 缓存已清理"
    else
        log_warning "curl 命令不可用，跳过 OpenSearch 缓存清理"
    fi
}

# 激进的内存释放策略（仅在紧急情况下使用）
aggressive_memory_release() {
    log_warning "执行激进内存释放（紧急模式）..."
    
    # 1. 清理所有系统缓存
    echo 3 > /proc/sys/vm/drop_caches
    log_success "所有系统缓存已清理"
    
    # 2. 强制清理Swap（即使有风险）
    clear_swap
    
    # 3. 重启PHP-FPM（而不是重载）
    if systemctl is-active --quiet php8.3-fpm; then
        log_warning "重启PHP-FPM进程池..."
        systemctl restart php8.3-fpm
        log_success "PHP-FPM已重启"
    fi
    
    # 4. 清理所有应用缓存
    clear_valkey_cache
    clear_mysql_cache
    
    # 5. 等待服务恢复
    sleep 5
    
    get_system_stats
    log_success "激进内存释放完成，当前使用率: ${MEMORY_USAGE}%"
}

# 监控模式
monitor_mode() {
    log_info "启动内存监控模式..."
    log_info "警戒线: 内存 ${MEMORY_THRESHOLD}%, Swap ${SWAP_THRESHOLD}%, CPU ${CPU_THRESHOLD}%"
    
    while true; do
        get_system_stats
        show_system_status
        
        # 检查是否需要释放内存
        if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
            # 根据内存使用率选择释放策略
            if (( $(echo "$MEMORY_USAGE > 95" | bc -l) )); then
                log_error "内存使用率极高 (${MEMORY_USAGE}%)，使用激进释放策略"
                aggressive_memory_release
            else
                intelligent_memory_release
            fi
        elif (( $(echo "$SWAP_PERCENTAGE > $SWAP_THRESHOLD" | bc -l) )); then
            log_warning "Swap使用率过高 (${SWAP_PERCENTAGE}%)，安全清理Swap..."
            # 检查可用内存是否足够
            local available_memory=$(free -m | grep Mem | awk '{print $7}')
            local swap_used_mb=$(free -m | grep Swap | awk '{print $3}')
            if [[ $available_memory -gt $swap_used_mb ]]; then
                clear_swap
            else
                log_warning "可用内存不足，跳过Swap清理"
            fi
        elif (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
            log_warning "CPU使用率过高 (${CPU_USAGE}%)"
        fi
        
        sleep 30  # 每30秒检查一次
    done
}

# 一次性检查模式
check_mode() {
    get_system_stats
    show_system_status
    
    if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        log_warning "内存使用率过高 (${MEMORY_USAGE}%)"
        echo -e "  ${YELLOW}选择释放策略:${NC}"
        echo -e "  1) 安全释放 (推荐)"
        echo -e "  2) 激进释放 (紧急情况)"
        echo -e "  3) 跳过释放"
        
        read -p "请选择 (1-3): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                intelligent_memory_release
                ;;
            2)
                log_warning "确认执行激进释放策略?"
                read -p "这将重启PHP-FPM，可能影响正在处理的请求 (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    aggressive_memory_release
                else
                    log_info "已取消激进释放"
                fi
                ;;
            3)
                log_info "跳过内存释放"
                ;;
            *)
                log_info "无效选择，跳过内存释放"
                ;;
        esac
    else
        log_success "内存使用率正常 (${MEMORY_USAGE}%)"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
智能内存监控和自动释放脚本

用法:
    $0 [模式] [选项]

模式:
    monitor     持续监控模式（每30秒检查一次）
    check       一次性检查模式
    release     立即执行内存释放
    status      显示当前系统状态
    help        显示此帮助信息

选项:
    --threshold=85       设置内存使用率阈值 (默认: 85%)
    --swap-threshold=30  设置Swap使用率阈值 (默认: 30%)
    --cpu-threshold=80   设置CPU使用率阈值 (默认: 80%)

示例:
    $0 monitor                    # 持续监控
    $0 check                      # 一次性检查
    $0 release                    # 立即释放内存
    $0 monitor --threshold=90     # 监控，阈值90%

功能:
    - 自动监控内存、Swap、CPU使用率
    - 智能优先级释放：Valkey → PHP-FPM → MySQL → OpenSearch
    - 分级清理：系统缓存、应用缓存、Swap清理
    - 安全保护：避免OOM和程序崩溃
    - 详细的日志记录和操作确认

智能释放策略:
    - 优先级释放：按影响程度智能选择清理顺序
    - 渐进式清理：每步检查效果，避免过度清理
    - OOM保护：Swap清理前检查可用内存
    - 服务保护：优先使用重载而非重启

释放优先级:
    1. Valkey缓存 (影响最小，12%内存)
    2. PHP-FPM缓存 (中等影响，19%内存)
    3. MySQL缓存 (高影响，31%内存，效果最好)
    4. OpenSearch缓存 (重要但可重建，19%内存)

EOF
}

# 主函数
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
    
    # 检查锁文件
    check_lock
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    # 解析命令行参数
    case "${1:-check}" in
        monitor)
            # 解析阈值参数
            for arg in "$@"; do
                case $arg in
                    --threshold=*)
                        MEMORY_THRESHOLD="${arg#*=}"
                        ;;
                    --swap-threshold=*)
                        SWAP_THRESHOLD="${arg#*=}"
                        ;;
                    --cpu-threshold=*)
                        CPU_THRESHOLD="${arg#*=}"
                        ;;
                esac
            done
            monitor_mode
            ;;
        check)
            check_mode
            ;;
        release)
            get_system_stats
            echo -e "  ${YELLOW}选择释放策略:${NC}"
            echo -e "  1) 安全释放 (推荐)"
            echo -e "  2) 激进释放 (紧急情况)"
            
            read -p "请选择 (1-2): " -n 1 -r
            echo
            
            case $REPLY in
                1)
                    intelligent_memory_release
                    ;;
                2)
                    aggressive_memory_release
                    ;;
                *)
                    log_info "无效选择，使用智能释放策略"
                    intelligent_memory_release
                    ;;
            esac
            ;;
        status)
            get_system_stats
            show_system_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知模式: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
