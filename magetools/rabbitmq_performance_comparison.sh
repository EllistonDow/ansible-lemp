#!/bin/bash

# RabbitMQ 脚本性能对比测试
# 对比 simple 版本和 advanced 版本
# 作者: Ansible LEMP Project
# 版本: 1.0.0

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
TIMER="⏱️"

# 测试站点
TEST_SITE="test_performance"

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

# 时间测量函数
measure_time() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "$duration"
}

# 创建测试站点
create_test_site() {
    log_info "创建测试站点: $TEST_SITE"
    
    local test_path="/home/doge/$TEST_SITE"
    
    # 如果测试站点已存在，先清理
    if [ -d "$test_path" ]; then
        log_warning "测试站点已存在，先清理..."
        sudo rm -rf "$test_path"
    fi
    
    # 创建测试目录结构
    mkdir -p "$test_path"/{bin,app/etc,var,generated,pub/media,pub/static}
    
    # 创建模拟的 Magento 文件
    cat > "$test_path/bin/magento" << 'EOF'
#!/bin/bash
echo "Magento CLI 模拟"
EOF
    chmod +x "$test_path/bin/magento"
    
    # 创建模拟的 env.php
    cat > "$test_path/app/etc/env.php" << 'EOF'
<?php
return [
    'backend' => [
        'frontName' => 'admin'
    ],
    'cache' => [
        'graphql' => [
            'id_suffix' => '_graphql'
        ],
        'frontend' => [
            'default' => [
                'id_prefix' => 'test_'
            ]
        ]
    ],
    'queue' => [
        'consumers_wait_for_messages' => 1
    ]
];
EOF
    
    # 创建一些测试文件
    for i in {1..1000}; do
        echo "test file $i" > "$test_path/var/test_file_$i.txt"
    done
    
    log_success "测试站点创建完成"
}

# 清理测试站点
cleanup_test_site() {
    log_info "清理测试站点: $TEST_SITE"
    
    local test_path="/home/doge/$TEST_SITE"
    
    if [ -d "$test_path" ]; then
        sudo rm -rf "$test_path"
        log_success "测试站点已清理"
    fi
    
    # 清理 RabbitMQ 配置
    sudo rabbitmqctl delete_vhost "/$TEST_SITE" 2>/dev/null || true
    sudo rabbitmqctl delete_user "${TEST_SITE}_user" 2>/dev/null || true
    
    # 清理 systemd 服务
    for consumer in async.operations.all product_action_attribute.update exportProcessor inventoryQtyUpdate sales.rule.update media.storage.catalog.image.resize; do
        local service_name="magento-consumer-${TEST_SITE}-${consumer}"
        sudo systemctl disable "$service_name" 2>/dev/null || true
        sudo systemctl stop "$service_name" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/${service_name}.service"
    done
    
    sudo systemctl daemon-reload
}

# 测试 simple 版本
test_simple_version() {
    log_info "测试 Simple 版本..."
    
    local start_time=$(date +%s.%N)
    
    # 运行 simple 版本
    ./rabbitmq_manager_simple.sh "$TEST_SITE" setup
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "$duration"
}

# 测试 advanced 版本
test_advanced_version() {
    log_info "测试 Advanced 版本..."
    
    local start_time=$(date +%s.%N)
    
    # 运行 advanced 版本
    ./rabbitmq_manager_advanced.sh "$TEST_SITE" setup
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "$duration"
}

# 测试权限修复性能
test_permission_performance() {
    log_info "测试权限修复性能..."
    
    local test_path="/home/doge/$TEST_SITE"
    
    # 创建更多测试文件
    for i in {1..5000}; do
        echo "permission test file $i" > "$test_path/var/permission_test_$i.txt"
    done
    
    # 测试 simple 版本的权限修复
    log_info "测试 Simple 版本权限修复..."
    local start_time=$(date +%s.%N)
    
    # 模拟 simple 版本的权限修复（使用内部函数）
    cd "$test_path"
    sudo chown -R "$(whoami):www-data" .
    find . -type d -exec sudo chmod 755 {} \;
    find . -type f -exec sudo chmod 644 {} \;
    find var generated pub/media pub/static -type d -exec sudo chmod 775 {} \; 2>/dev/null || true
    find var generated pub/media pub/static -type f -exec sudo chmod 664 {} \; 2>/dev/null || true
    
    local end_time=$(date +%s.%N)
    local simple_duration=$(echo "$end_time - $start_time" | bc)
    
    # 测试 advanced 版本的权限修复
    log_info "测试 Advanced 版本权限修复..."
    start_time=$(date +%s.%N)
    
    # 模拟 advanced 版本的权限修复（使用高性能方法）
    cd "$test_path"
    sudo chown -R "$(whoami):www-data" .
    find . -type d -print0 | xargs -0 -n 2000 -P 16 sudo chmod 755 2>/dev/null || true
    find . -type f -print0 | xargs -0 -n 2000 -P 16 sudo chmod 644 2>/dev/null || true
    find var generated pub/media pub/static -type d -print0 | xargs -0 -n 2000 -P 16 sudo chmod 775 2>/dev/null || true
    find var generated pub/media pub/static -type f -print0 | xargs -0 -n 2000 -P 16 sudo chmod 664 2>/dev/null || true
    
    end_time=$(date +%s.%N)
    local advanced_duration=$(echo "$end_time - $start_time" | bc)
    
    echo "Simple: $simple_duration, Advanced: $advanced_duration"
}

# 测试消费者管理
test_consumer_management() {
    log_info "测试消费者管理..."
    
    # 测试 simple 版本消费者启动
    log_info "测试 Simple 版本消费者启动..."
    local start_time=$(date +%s.%N)
    
    ./rabbitmq_manager_simple.sh "$TEST_SITE" start
    
    local end_time=$(date +%s.%N)
    local simple_start_duration=$(echo "$end_time - $start_time" | bc)
    
    sleep 2
    
    # 测试 simple 版本消费者停止
    start_time=$(date +%s.%N)
    
    ./rabbitmq_manager_simple.sh "$TEST_SITE" stop
    
    end_time=$(date +%s.%N)
    local simple_stop_duration=$(echo "$end_time - $start_time" | bc)
    
    # 测试 advanced 版本消费者启动
    log_info "测试 Advanced 版本消费者启动..."
    start_time=$(date +%s.%N)
    
    ./rabbitmq_manager_advanced.sh "$TEST_SITE" start
    
    end_time=$(date +%s.%N)
    local advanced_start_duration=$(echo "$end_time - $start_time" | bc)
    
    sleep 2
    
    # 测试 advanced 版本消费者停止
    start_time=$(date +%s.%N)
    
    ./rabbitmq_manager_advanced.sh "$TEST_SITE" stop
    
    end_time=$(date +%s.%N)
    local advanced_stop_duration=$(echo "$end_time - $start_time" | bc)
    
    echo "Simple Start: $simple_start_duration, Simple Stop: $simple_stop_duration"
    echo "Advanced Start: $advanced_start_duration, Advanced Stop: $advanced_stop_duration"
}

# 生成性能报告
generate_report() {
    local simple_setup_time="$1"
    local advanced_setup_time="$2"
    local permission_results="$3"
    local consumer_results="$4"
    
    echo
    echo -e "${CYAN}=== 性能对比报告 ===${NC}"
    echo
    
    echo -e "${YELLOW}📊 总体性能对比:${NC}"
    echo -e "  Simple 版本总耗时: ${RED}${simple_setup_time}秒${NC}"
    echo -e "  Advanced 版本总耗时: ${GREEN}${advanced_setup_time}秒${NC}"
    
    local speedup=$(echo "scale=2; $simple_setup_time / $advanced_setup_time" | bc)
    echo -e "  性能提升: ${CYAN}${speedup}倍${NC}"
    echo
    
    echo -e "${YELLOW}🔧 功能特性对比:${NC}"
    echo -e "  Simple 版本:"
    echo -e "    - 管理方式: ${RED}nohup${NC}"
    echo -e "    - 消费者数量: ${RED}21个${NC}"
    echo -e "    - 线程模式: ${RED}单线程${NC}"
    echo -e "    - 权限修复: ${RED}标准方法${NC}"
    echo -e "    - 服务管理: ${RED}手动${NC}"
    echo -e "    - 日志管理: ${RED}文件${NC}"
    echo
    echo -e "  Advanced 版本:"
    echo -e "    - 管理方式: ${GREEN}systemd${NC}"
    echo -e "    - 消费者数量: ${GREEN}21个${NC}"
    echo -e "    - 线程模式: ${GREEN}双线程${NC}"
    echo -e "    - 权限修复: ${GREEN}超高性能${NC}"
    echo -e "    - 服务管理: ${GREEN}自动${NC}"
    echo -e "    - 日志管理: ${GREEN}systemd journal${NC}"
    echo
    
    echo -e "${YELLOW}⚡ 性能优势分析:${NC}"
    echo -e "  Advanced 版本优势:"
    echo -e "    ${GREEN}✅${NC} 企业级服务管理 (systemd)"
    echo -e "    ${GREEN}✅${NC} 自动重启和故障恢复"
    echo -e "    ${GREEN}✅${NC} 资源限制和监控"
    echo -e "    ${GREEN}✅${NC} 超高性能权限修复"
    echo -e "    ${GREEN}✅${NC} 双线程处理能力"
    echo -e "    ${GREEN}✅${NC} 集中化日志管理"
    echo -e "    ${GREEN}✅${NC} 更好的系统集成"
    echo
    echo -e "  Simple 版本优势:"
    echo -e "    ${YELLOW}⚠️${NC} 简单易用"
    echo -e "    ${YELLOW}⚠️${NC} 无需 root 权限"
    echo -e "    ${YELLOW}⚠️${NC} 快速部署"
    echo
    
    echo -e "${YELLOW}🎯 推荐使用场景:${NC}"
    echo -e "  ${GREEN}Advanced 版本${NC} 适用于:"
    echo -e "    - 生产环境"
    echo -e "    - 需要高可用性"
    echo -e "    - 大规模部署"
    echo -e "    - 企业级管理"
    echo
    echo -e "  ${YELLOW}Simple 版本${NC} 适用于:"
    echo -e "    - 开发环境"
    echo -e "    - 快速测试"
    echo -e "    - 简单部署"
    echo -e "    - 学习用途"
    echo
    
    echo -e "${CYAN}=== 测试完成 ===${NC}"
}

# 主程序
main() {
    echo -e "${CYAN}${ROCKET} RabbitMQ 脚本性能对比测试${NC}"
    echo
    
    # 检查脚本是否存在
    if [ ! -f "./rabbitmq_manager_simple.sh" ]; then
        log_error "rabbitmq_manager_simple.sh 不存在"
        exit 1
    fi
    
    if [ ! -f "./rabbitmq_manager_advanced.sh" ]; then
        log_error "rabbitmq_manager_advanced.sh 不存在"
        exit 1
    fi
    
    # 创建测试站点
    create_test_site
    
    # 测试 simple 版本
    log_info "开始测试 Simple 版本..."
    local simple_setup_time=$(test_simple_version)
    
    # 清理并重新创建测试站点
    cleanup_test_site
    create_test_site
    
    # 测试 advanced 版本
    log_info "开始测试 Advanced 版本..."
    local advanced_setup_time=$(test_advanced_version)
    
    # 测试权限修复性能
    local permission_results=$(test_permission_performance)
    
    # 测试消费者管理
    local consumer_results=$(test_consumer_management)
    
    # 生成报告
    generate_report "$simple_setup_time" "$advanced_setup_time" "$permission_results" "$consumer_results"
    
    # 清理测试站点
    cleanup_test_site
    
    log_success "性能对比测试完成！"
}

# 执行主程序
main "$@"
