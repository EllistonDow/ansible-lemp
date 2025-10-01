#!/bin/bash
set -e

TOTAL_RAM_GB=128
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

calculate_memory_allocation() {
    local total_gb=$1
    MYSQL_MEMORY_GB=$((total_gb * 25 / 100))
    OPENSEARCH_MEMORY_GB=$((total_gb * 12 / 100))
    VALKEY_MEMORY_GB=$((total_gb * 9 / 100))
    SYSTEM_MEMORY_GB=$((total_gb * 31 / 100))
    OTHER_MEMORY_GB=$((total_gb * 23 / 100))
    PHP_MAX_CHILDREN=200
    MYSQL_INSTANCES=8
}

print_header() {
    calculate_memory_allocation $TOTAL_RAM_GB
    
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 性能优化工具 (动态内存分配)"
    echo -e "    服务器内存: ${TOTAL_RAM_GB}GB RAM"
    echo -e "==============================================${NC}"
    echo
    echo -e "${CYAN}📊 内存分配方案:${NC}"
    echo -e "  MySQL InnoDB Buffer Pool: ${MYSQL_MEMORY_GB}GB (${MYSQL_INSTANCES}个实例)"
    echo -e "  OpenSearch JVM Heap: ${OPENSEARCH_MEMORY_GB}GB"
    echo -e "  Valkey Cache: ${VALKEY_MEMORY_GB}GB"
    echo -e "  PHP-FPM 最大进程数: ${PHP_MAX_CHILDREN}"
    echo
}

print_header
echo "测试完成"
