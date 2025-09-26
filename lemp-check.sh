#!/bin/bash
# LEMP Stack 环境检查脚本
# 用法: ./lemp-check.sh [v|s|h|a]
#   v - 查看版本信息
#   s - 查看服务状态  
#   h - 显示帮助信息
#   a - 显示所有信息

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
PACKAGE="📦"

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "    LEMP Stack 环境检查工具"
    echo -e "==========================================${NC}"
    echo
}

print_help() {
    print_header
    echo -e "${CYAN}用法: $0 [选项]${NC}"
    echo
    echo -e "${YELLOW}选项:${NC}"
    echo -e "  ${GREEN}v${NC}  - 查看所有程序版本信息"
    echo -e "  ${GREEN}s${NC}  - 查看所有服务运行状态"
    echo -e "  ${GREEN}a${NC}  - 显示所有信息 (版本+状态)"
    echo -e "  ${GREEN}h${NC}  - 显示此帮助信息"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0 v     # 查看版本"
    echo -e "  $0 s     # 查看状态"
    echo -e "  $0 a     # 查看全部"
    echo -e "  $0       # 默认显示全部"
    echo
}

check_version() {
    local program="$1"
    local version_cmd="$2"
    local name="$3"
    
    if command -v $program >/dev/null 2>&1; then
        local version=$(eval $version_cmd 2>/dev/null | head -1)
        if [[ -n "$version" ]]; then
            echo -e "  ${CHECK_MARK} ${GREEN}$name${NC}: $version"
        else
            echo -e "  ${WARNING_MARK} ${YELLOW}$name${NC}: 已安装但无法获取版本"
        fi
    else
        echo -e "  ${CROSS_MARK} ${RED}$name${NC}: 未安装"
    fi
}

check_service() {
    local service="$1" 
    local name="$2"
    local port="$3"
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        local status="运行中"
        if [[ -n "$port" ]]; then
            if netstat -tlpn 2>/dev/null | grep -q ":$port "; then
                status="运行中 (端口:$port)"
            else
                status="运行中 (端口未监听)"
            fi
        fi
        echo -e "  ${CHECK_MARK} ${GREEN}$name${NC}: $status"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo -e "  ${WARNING_MARK} ${YELLOW}$name${NC}: 已安装但未运行"
    else
        echo -e "  ${CROSS_MARK} ${RED}$name${NC}: 未安装或未启用"
    fi
}

check_special_service() {
    local name="$1"
    local check_cmd="$2"
    local port="$3"
    
    if eval $check_cmd >/dev/null 2>&1; then
        local status="运行中"
        if [[ -n "$port" ]]; then
            if netstat -tlpn 2>/dev/null | grep -q ":$port "; then
                status="运行中 (端口:$port)"
            fi
        fi
        echo -e "  ${CHECK_MARK} ${GREEN}$name${NC}: $status"
    else
        echo -e "  ${CROSS_MARK} ${RED}$name${NC}: 未运行或无法访问"
    fi
}

show_versions() {
    echo -e "${PACKAGE} ${CYAN}程序版本信息:${NC}"
    echo
    
    # 1. Ansible
    check_version "ansible" "ansible --version | head -1" "Ansible"
    
    # 2. Composer  
    check_version "composer" "composer --version" "Composer"
    
    # 3. Nginx
    check_version "nginx" "nginx -v 2>&1" "Nginx"
    
    # 4. PHP
    check_version "php" "php --version | head -1" "PHP"
    
    # 5. MySQL/Percona
    if command -v mysql >/dev/null 2>&1; then
        local mysql_version=$(mysql --version 2>/dev/null | head -1)
        echo -e "  ${CHECK_MARK} ${GREEN}MySQL/Percona${NC}: $mysql_version"
    else
        echo -e "  ${CROSS_MARK} ${RED}MySQL/Percona${NC}: 未安装"
    fi
    
    # 6. RabbitMQ
    if command -v rabbitmqctl >/dev/null 2>&1; then
        local rabbitmq_version=$(timeout 3 sudo rabbitmqctl version 2>/dev/null | grep "RabbitMQ version" | head -1 2>/dev/null || echo "RabbitMQ (已安装)")
        echo -e "  ${CHECK_MARK} ${GREEN}RabbitMQ${NC}: $rabbitmq_version"
    else
        echo -e "  ${CROSS_MARK} ${RED}RabbitMQ${NC}: 未安装"
    fi
    
    # 7. Valkey
    if command -v valkey-cli >/dev/null 2>&1; then
        local valkey_version=$(valkey-cli --version 2>/dev/null || echo "Valkey (Redis兼容)")
        echo -e "  ${CHECK_MARK} ${GREEN}Valkey${NC}: $valkey_version"
    elif [[ -L /usr/local/bin/valkey-cli ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}Valkey${NC}: Redis兼容版本"
    else
        echo -e "  ${CROSS_MARK} ${RED}Valkey${NC}: 未安装"
    fi
    
    # 8. Varnish
    check_version "varnishd" "varnishd -V 2>&1 | head -1" "Varnish"
    
    # 9. OpenSearch
    if systemctl is-active opensearch >/dev/null 2>&1; then
        local opensearch_version=$(curl -s http://localhost:9200 2>/dev/null | grep -o '"number":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")
        echo -e "  ${CHECK_MARK} ${GREEN}OpenSearch${NC}: $opensearch_version"
    else
        echo -e "  ${CROSS_MARK} ${RED}OpenSearch${NC}: 未运行"
    fi
    
    # 10. Fail2ban
    check_version "fail2ban-server" "fail2ban-server --version | head -1" "Fail2ban"
    
    # 11. Webmin
    if [[ -f /usr/share/webmin/version ]]; then
        local webmin_version="Webmin $(cat /usr/share/webmin/version)"
        echo -e "  ${CHECK_MARK} ${GREEN}Webmin${NC}: $webmin_version"
    else
        echo -e "  ${CROSS_MARK} ${RED}Webmin${NC}: 未安装"
    fi
    
    # 12. phpMyAdmin
    if [[ -f /usr/share/phpmyadmin/README ]]; then
        local pma_version=$(grep -o "phpMyAdmin [0-9]*\.[0-9]*\.[0-9]*" /usr/share/phpmyadmin/README 2>/dev/null | head -1 || echo "phpMyAdmin")
        echo -e "  ${CHECK_MARK} ${GREEN}phpMyAdmin${NC}: $pma_version"
    elif [[ -d /usr/share/phpmyadmin ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}phpMyAdmin${NC}: 已安装"
    else
        echo -e "  ${CROSS_MARK} ${RED}phpMyAdmin${NC}: 未安装"
    fi
    
    # 13. Certbot
    check_version "certbot" "certbot --version" "Certbot"
    
    echo
}

show_services() {
    echo -e "${GEAR} ${CYAN}服务运行状态:${NC}"
    echo
    
    # 核心服务
    check_service "nginx" "Nginx" "80"
    check_service "php8.3-fpm" "PHP-FPM" ""
    check_service "mysql" "MySQL/Percona" "3306"
    check_service "opensearch" "OpenSearch" "9200"
    check_service "rabbitmq-server" "RabbitMQ" "5672"
    check_service "valkey" "Valkey" "6379"
    check_service "varnish" "Varnish" "6081"
    check_service "fail2ban" "Fail2ban" ""
    check_service "webmin" "Webmin" "10000"
    
    # 特殊检查
    if [[ -f /etc/nginx/sites-enabled/phpmyadmin.conf ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}phpMyAdmin${NC}: 已配置 (http://localhost/phpmyadmin)"
    else
        echo -e "  ${WARNING_MARK} ${YELLOW}phpMyAdmin${NC}: 未配置nginx站点"
    fi
    
    if command -v certbot >/dev/null 2>&1; then
        echo -e "  ${CHECK_MARK} ${GREEN}Certbot${NC}: 已安装并可用"
    else
        echo -e "  ${CROSS_MARK} ${RED}Certbot${NC}: 未安装"
    fi
    
    echo
}

show_quick_info() {
    echo -e "${INFO_MARK} ${CYAN}快速访问信息:${NC}"
    echo
    echo -e "  ${ROCKET} ${GREEN}Web服务${NC}:"
    echo -e "    • 主站: ${BLUE}http://localhost${NC}"
    echo -e "    • phpMyAdmin: ${BLUE}http://localhost/phpmyadmin${NC}"
    echo -e "    • Webmin: ${BLUE}https://localhost:10000${NC}"
    echo
    echo -e "  ${ROCKET} ${GREEN}API服务${NC}:"
    echo -e "    • OpenSearch: ${BLUE}http://localhost:9200${NC}"
    echo -e "    • RabbitMQ管理: ${BLUE}http://localhost:15672${NC}"
    echo
    echo -e "  ${ROCKET} ${GREEN}数据库${NC}:"
    echo -e "    • MySQL: ${BLUE}localhost:3306${NC} (用户: root, 密码: root_password_change_me)"
    echo -e "    • Valkey: ${BLUE}localhost:6379${NC}"
    echo
}

show_system_info() {
    echo -e "${INFO_MARK} ${CYAN}系统信息:${NC}"
    echo
    echo -e "  ${PACKAGE} 操作系统: $(lsb_release -d | cut -d: -f2 | xargs)"
    echo -e "  ${PACKAGE} 内核版本: $(uname -r)"
    echo -e "  ${PACKAGE} 内存使用: $(free -h | grep '^Mem:' | awk '{print $3"/"$2}')"
    echo -e "  ${PACKAGE} 磁盘使用: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" 已用)"}')"
    echo -e "  ${PACKAGE} 负载平均: $(uptime | grep -o 'load average.*' | cut -d: -f2 | xargs)"
    echo
}

get_summary() {
    local total=13
    local running=0
    local installed=0
    
    # 检查已安装的程序
    local programs=("ansible" "composer" "nginx" "php" "mysql" "rabbitmqctl" "varnishd" "fail2ban-server" "certbot")
    for prog in "${programs[@]}"; do
        if command -v "$prog" >/dev/null 2>&1; then
            ((installed++))
        fi
    done
    
    # 检查特殊安装
    [[ -L /usr/local/bin/valkey-cli ]] && ((installed++))
    [[ -f /usr/share/webmin/version ]] && ((installed++))
    [[ -d /usr/share/phpmyadmin ]] && ((installed++))
    [[ -d /opt/opensearch ]] && ((installed++))
    
    # 检查运行中的服务
    local services=("nginx" "php8.3-fpm" "mysql" "opensearch" "rabbitmq-server" "valkey" "varnish" "fail2ban" "webmin")
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            ((running++))
        fi
    done
    
    echo -e "${PURPLE}=========================================="
    echo -e "    环境状态摘要"
    echo -e "==========================================${NC}"
    echo -e "  📊 已安装程序: ${GREEN}$installed${NC}/$total"
    echo -e "  🔄 运行中服务: ${GREEN}$running${NC}/9"
    echo -e "  🎯 整体状态: $([ $installed -ge 10 ] && echo -e "${GREEN}良好${NC}" || echo -e "${YELLOW}部分安装${NC}")"
    echo
}

# 主程序
main() {
    case "${1:-a}" in
        "v"|"version")
            print_header
            show_versions
            ;;
        "s"|"status"|"service")
            print_header
            show_services
            show_quick_info
            ;;
        "h"|"help"|"--help")
            print_help
            ;;
        "a"|"all"|"")
            print_header
            get_summary
            show_versions
            show_services
            show_quick_info
            show_system_info
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            echo
            print_help
            exit 1
            ;;
    esac
}

# 检查依赖命令
check_dependencies() {
    local missing_deps=()
    
    for cmd in "systemctl" "netstat" "curl"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${WARNING_MARK} ${YELLOW}警告: 以下命令未找到，某些功能可能受限:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "  - $dep"
        done
        echo
    fi
}

# 运行程序
check_dependencies
main "$@"
