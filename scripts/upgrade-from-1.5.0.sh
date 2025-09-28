#!/bin/bash
# LEMP Stack Upgrade Script: v1.5.0 → v1.6.3
# 安全升级脚本，包含备份和分步升级

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
ROCKET="🚀"

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "    LEMP Stack 升级工具 v1.5.0 → v1.6.3"
    echo -e "==============================================${NC}"
    echo
}

print_warning() {
    echo -e "${WARNING_MARK} ${YELLOW}重要提醒：${NC}"
    echo -e "  • 此升级包含 RabbitMQ 4.1.4 (破坏性升级)"
    echo -e "  • 此升级包含 Erlang OTP 27 升级"
    echo -e "  • 建议先在测试环境验证"
    echo -e "  • 升级前会自动创建备份"
    echo
    read -p "确认继续升级？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${INFO_MARK} 升级已取消"
        exit 0
    fi
}

create_backup() {
    echo -e "${INFO_MARK} ${BLUE}创建系统备份...${NC}"
    
    BACKUP_DIR="/opt/lemp-upgrade-backup/$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$BACKUP_DIR"
    
    echo -e "  ${INFO_MARK} 备份目录: $BACKUP_DIR"
    
    # 备份配置文件
    echo -e "  ${INFO_MARK} 备份配置文件..."
    sudo cp -r /etc/nginx/ "$BACKUP_DIR/nginx/" 2>/dev/null || true
    sudo cp -r /etc/mysql/ "$BACKUP_DIR/mysql/" 2>/dev/null || true
    sudo cp -r /etc/php/ "$BACKUP_DIR/php/" 2>/dev/null || true
    sudo cp /etc/rabbitmq/rabbitmq.conf "$BACKUP_DIR/rabbitmq.conf" 2>/dev/null || true
    
    # 备份服务状态
    systemctl list-units --type=service --state=running | grep -E "(nginx|mysql|php|rabbitmq|opensearch|valkey)" > "$BACKUP_DIR/services-status.txt" 2>/dev/null || true
    ss -tlnp | grep -E ":80|:443|:3306|:5672|:6379|:9200" > "$BACKUP_DIR/ports-status.txt" 2>/dev/null || true
    
    # 备份 RabbitMQ 配置
    echo -e "  ${INFO_MARK} 备份 RabbitMQ 配置..."
    sudo rabbitmq-diagnostics export_definitions "$BACKUP_DIR/rabbitmq-definitions.json" 2>/dev/null || true
    
    # 备份数据库
    echo -e "  ${INFO_MARK} 备份数据库..."
    sudo mysqldump --all-databases > "$BACKUP_DIR/all-databases.sql" 2>/dev/null || true
    
    echo -e "  ${CHECK_MARK} 备份完成: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/lemp-upgrade-backup-path
}

check_current_version() {
    echo -e "${INFO_MARK} ${BLUE}检查当前版本...${NC}"
    
    if [[ -f "./lemp-check.sh" ]]; then
        ./lemp-check.sh v
    else
        echo -e "  ${WARNING_MARK} 未找到版本检查脚本"
    fi
}

upgrade_rabbitmq() {
    echo -e "${ROCKET} ${BLUE}升级 RabbitMQ 4.1.4 + Erlang 27...${NC}"
    
    # 检查 RabbitMQ 状态
    if systemctl is-active --quiet rabbitmq-server; then
        echo -e "  ${INFO_MARK} 停止 RabbitMQ 服务..."
        sudo systemctl stop rabbitmq-server
    fi
    
    # 运行 RabbitMQ 升级
    echo -e "  ${INFO_MARK} 安装新版本 RabbitMQ..."
    ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=install" || {
        echo -e "  ${CROSS_MARK} RabbitMQ 升级失败"
        return 1
    }
    
    # 恢复配置（如果存在备份）
    BACKUP_DIR=$(cat /tmp/lemp-upgrade-backup-path 2>/dev/null || echo "")
    if [[ -f "$BACKUP_DIR/rabbitmq-definitions.json" ]]; then
        echo -e "  ${INFO_MARK} 恢复 RabbitMQ 配置..."
        sleep 10  # 等待服务完全启动
        sudo rabbitmq-diagnostics import_definitions "$BACKUP_DIR/rabbitmq-definitions.json" 2>/dev/null || true
    fi
    
    echo -e "  ${CHECK_MARK} RabbitMQ 升级完成"
}

upgrade_nginx() {
    echo -e "${ROCKET} ${BLUE}升级 Nginx (包含 ModSecurity)...${NC}"
    
    # 检查是否启用 ModSecurity
    if grep -q "modsecurity on" /etc/nginx/nginx.conf 2>/dev/null; then
        MODSECURITY_ENABLED="true"
    else
        MODSECURITY_ENABLED="false"
    fi
    
    echo -e "  ${INFO_MARK} ModSecurity 状态: $MODSECURITY_ENABLED"
    
    # 升级 Nginx
    ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=$MODSECURITY_ENABLED" || {
        echo -e "  ${CROSS_MARK} Nginx 升级失败"
        return 1
    }
    
    # 测试配置
    echo -e "  ${INFO_MARK} 测试 Nginx 配置..."
    if command -v nginx-test >/dev/null 2>&1; then
        sudo nginx-test
    else
        sudo nginx -t
    fi
    
    echo -e "  ${CHECK_MARK} Nginx 升级完成"
}

upgrade_basic_tools() {
    echo -e "${ROCKET} ${BLUE}升级基础工具 (包含 phpMyAdmin 修复)...${NC}"
    
    ansible-playbook playbooks/basic-tools.yml || {
        echo -e "  ${CROSS_MARK} 基础工具升级失败"
        return 1
    }
    
    echo -e "  ${CHECK_MARK} 基础工具升级完成"
}

verify_upgrade() {
    echo -e "${INFO_MARK} ${BLUE}验证升级结果...${NC}"
    
    # 运行系统检查
    if [[ -f "./lemp-check.sh" ]]; then
        echo -e "  ${INFO_MARK} 运行系统检查..."
        ./lemp-check.sh status
    fi
    
    # 测试 ModSecurity
    echo -e "  ${INFO_MARK} 测试 ModSecurity..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/phpmyadmin/?test=%3Cscript%3Ealert%28%27xss%27%29%3C%2fscript%3E" 2>/dev/null || echo "000")
    if [[ "$response" == "403" ]]; then
        echo -e "  ${CHECK_MARK} ModSecurity 工作正常"
    else
        echo -e "  ${WARNING_MARK} ModSecurity 可能未正常工作 (响应码: $response)"
    fi
    
    # 测试 phpMyAdmin
    echo -e "  ${INFO_MARK} 测试 phpMyAdmin..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/phpmyadmin/" 2>/dev/null || echo "000")
    if [[ "$response" == "200" ]]; then
        echo -e "  ${CHECK_MARK} phpMyAdmin 访问正常"
    else
        echo -e "  ${WARNING_MARK} phpMyAdmin 可能无法访问 (响应码: $response)"
    fi
    
    echo -e "  ${CHECK_MARK} 验证完成"
}

show_summary() {
    echo
    echo -e "${CHECK_MARK} ${GREEN}升级到 v1.6.3 完成！${NC}"
    echo
    echo -e "${INFO_MARK} ${YELLOW}主要更新:${NC}"
    echo -e "  • RabbitMQ 4.1.4 + Erlang OTP 27"
    echo -e "  • ModSecurity 兼容性修复"
    echo -e "  • phpMyAdmin 配置修复"
    echo -e "  • Magento2 优化器 ModSecurity 集成"
    echo
    echo -e "${INFO_MARK} ${YELLOW}备份位置:${NC}"
    if [[ -f "/tmp/lemp-upgrade-backup-path" ]]; then
        echo -e "  $(cat /tmp/lemp-upgrade-backup-path)"
    fi
    echo
    echo -e "${INFO_MARK} ${YELLOW}下一步建议:${NC}"
    echo -e "  • 测试所有应用功能"
    echo -e "  • 验证数据完整性"
    echo -e "  • 如有问题，使用备份回滚"
    echo
}

# 主程序
main() {
    print_header
    print_warning
    
    echo -e "${ROCKET} ${GREEN}开始升级过程...${NC}"
    echo
    
    check_current_version
    create_backup
    
    # 分步升级
    upgrade_rabbitmq
    upgrade_nginx
    upgrade_basic_tools
    
    verify_upgrade
    show_summary
}

# 检查是否在正确的目录
if [[ ! -f "README.md" ]] || [[ ! -d "scripts" ]]; then
    echo -e "${CROSS_MARK} ${RED}错误: 请在 ansible-lemp 项目根目录运行此脚本${NC}"
    exit 1
fi

# 检查是否以非 root 用户运行
if [[ $EUID -eq 0 ]]; then
    echo -e "${WARNING_MARK} ${YELLOW}警告: 请不要以 root 身份运行此脚本${NC}"
    echo -e "使用: ${GREEN}./scripts/upgrade-from-1.5.0.sh${NC}"
    exit 1
fi

# 运行主程序
main "$@"
