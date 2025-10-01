#!/bin/bash
# Magento2 权限和所有者管理脚本
# 支持自定义用户和安全的权限配置
# Usage: ./magento-permissions.sh [用户名] [网站路径]
#        ./magento-permissions.sh restore

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"

# 默认配置
NGINX_USER="www-data"
NGINX_GROUP="www-data"
DEFAULT_SITE_USER="doge"
NGINX_CONFIG="/etc/nginx/nginx.conf"
PHP_FPM_POOL="/etc/php/8.3/fpm/pool.d/www.conf"

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 权限管理工具"
    echo -e "    安全的文件权限和所有者配置"
    echo -e "==============================================${NC}"
    echo
}

print_help() {
    print_header
    echo -e "${CYAN}用法: $0 [选项] [网站路径]${NC}"
    echo
    echo -e "${YELLOW}基本用法:${NC}"
    echo -e "  ${GREEN}$0 setup [用户名] [网站路径]${NC}"
    echo -e "    为 Magento2 网站设置安全权限"
    echo -e "    用户名: 文件所有者（如 doge）"
    echo -e "    网站路径: Magento2 根目录"
    echo
    echo -e "  ${GREEN}$0 quick [网站路径]${NC}"
    echo -e "    快速设置权限（使用当前用户）"
    echo
    echo -e "  ${GREEN}$0 restore${NC}"
    echo -e "    还原 Nginx 和 PHP-FPM 为默认配置"
    echo
    echo -e "  ${GREEN}$0 check [网站路径]${NC}"
    echo -e "    检查网站权限配置"
    echo
    echo -e "${YELLOW}安全建议:${NC}"
    echo -e "  ${INFO_MARK} Nginx 用户保持 ${NGINX_USER}（不要改为个人用户）"
    echo -e "  ${INFO_MARK} 文件所有者设为个人用户（如 doge）"
    echo -e "  ${INFO_MARK} 文件组设为 ${NGINX_GROUP}（Nginx 可读）"
    echo -e "  ${INFO_MARK} 目录权限 755，文件权限 644"
    echo -e "  ${INFO_MARK} 可写目录（var/, pub/media/）权限 775/664"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}# 为 doge 用户设置 /home/doge/hawk 网站权限${NC}"
    echo -e "  $0 setup doge /home/doge/hawk"
    echo
    echo -e "  ${CYAN}# 快速设置当前目录权限${NC}"
    echo -e "  cd /home/doge/tank && $0 quick ."
    echo
    echo -e "  ${CYAN}# 检查权限配置${NC}"
    echo -e "  $0 check /home/doge/hawk"
    echo
    echo -e "  ${CYAN}# 还原默认配置${NC}"
    echo -e "  $0 restore"
    echo
}

# 检查是否为 Magento2 目录
check_magento_dir() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${CROSS_MARK} ${RED}目录不存在: $dir${NC}"
        return 1
    fi
    
    if [[ ! -f "$dir/bin/magento" ]]; then
        echo -e "${WARNING_MARK} ${YELLOW}警告: 这不像是 Magento2 目录（未找到 bin/magento）${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# 设置 Magento2 权限
setup_permissions() {
    local site_user="$1"
    local site_path="$2"
    
    print_header
    echo -e "${INFO_MARK} ${CYAN}配置信息:${NC}"
    echo -e "  文件所有者: ${site_user}"
    echo -e "  文件组: ${NGINX_GROUP}"
    echo -e "  网站路径: ${site_path}"
    echo -e "  Nginx 用户: ${NGINX_USER} (保持不变)"
    echo
    
    # 确认
    read -p "确认执行? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${INFO_MARK} 操作已取消"
        exit 0
    fi
    
    echo -e "${INFO_MARK} ${CYAN}开始设置权限...${NC}"
    echo
    
    # 检查用户是否存在
    if ! id "$site_user" &>/dev/null; then
        echo -e "${CROSS_MARK} ${RED}用户 $site_user 不存在${NC}"
        exit 1
    fi
    
    # 检查目录
    check_magento_dir "$site_path" || exit 1
    
    # 检查并修复主目录权限（常见问题）
    local parent_dir=$(dirname "$site_path")
    while [[ "$parent_dir" != "/" && "$parent_dir" =~ ^/home/ ]]; do
        local current_perms=$(stat -c "%a" "$parent_dir" 2>/dev/null)
        local other_perms=${current_perms: -1}
        
        if [[ "$other_perms" == "0" ]]; then
            echo -e "${WARNING_MARK} ${YELLOW}检测到主目录权限问题: $parent_dir (${current_perms})${NC}"
            echo -e "${INFO_MARK} Nginx 需要执行权限才能访问网站目录"
            echo -e "${INFO_MARK} 建议设置为 711 (drwx--x--x)：所有者完全控制，其他用户只能通过"
            echo
            read -p "是否修复主目录权限? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                chmod 711 "$parent_dir"
                echo -e "${CHECK_MARK} ${GREEN}已修复: $parent_dir → 711${NC}"
                # 验证修复
                if sudo -u www-data test -x "$parent_dir"; then
                    echo -e "${CHECK_MARK} ${GREEN}验证成功: Nginx 现在可以访问此目录${NC}"
                else
                    echo -e "${WARNING_MARK} ${YELLOW}警告: 仍可能存在权限问题${NC}"
                fi
            else
                echo -e "${WARNING_MARK} ${YELLOW}跳过修复，这可能导致 404 错误${NC}"
            fi
            echo
            break
        fi
        
        # 检查上一级目录
        parent_dir=$(dirname "$parent_dir")
    done
    
    cd "$site_path" || exit 1
    
    # 1. 设置基础所有者和组
    echo -e "${INFO_MARK} 设置文件所有者: ${site_user}:${NGINX_GROUP}"
    sudo chown -R "${site_user}:${NGINX_GROUP}" .
    
    # 2. 设置基础权限
    echo -e "${INFO_MARK} 设置基础权限（目录 755，文件 644）"
    sudo find . -type d -exec chmod 755 {} \;
    sudo find . -type f -exec chmod 644 {} \;
    
    # 3. 设置可写目录权限
    echo -e "${INFO_MARK} 设置可写目录权限（775 + setgid）"
    local writable_dirs=(
        "var"
        "generated"
        "pub/media"
        "pub/static"
    )
    
    for dir in "${writable_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "  ${CHECK_MARK} $dir"
            sudo find "$dir" -type d -exec chmod 775 {} \;
            sudo find "$dir" -type f -exec chmod 664 {} \;
            # 设置 setgid 位，确保新文件自动继承组
            sudo find "$dir" -type d -exec chmod g+s {} \;
        fi
    done
    
    # 4. 设置可执行文件权限
    echo -e "${INFO_MARK} 设置可执行文件权限（755）"
    if [[ -f "bin/magento" ]]; then
        sudo chmod 755 bin/magento
        echo -e "  ${CHECK_MARK} bin/magento"
    fi
    
    # 5. 确保 Nginx 用户在组内
    if ! groups "$NGINX_USER" | grep -q "$NGINX_GROUP"; then
        echo -e "${INFO_MARK} 将 ${NGINX_USER} 添加到 ${NGINX_GROUP} 组"
        sudo usermod -a -G "$NGINX_GROUP" "$NGINX_USER"
    fi
    
    # 6. 添加用户到 www-data 组
    if ! groups "$site_user" | grep -q "$NGINX_GROUP"; then
        echo -e "${INFO_MARK} 将 ${site_user} 添加到 ${NGINX_GROUP} 组"
        sudo usermod -a -G "$NGINX_GROUP" "$site_user"
    fi
    
    echo
    echo -e "${CHECK_MARK} ${GREEN}权限设置完成！${NC}"
    echo
    
    # 显示建议
    echo -e "${INFO_MARK} ${CYAN}建议操作:${NC}"
    echo -e "  1. 重启 PHP-FPM: sudo systemctl restart php8.3-fpm"
    echo -e "  2. 清理 Magento 缓存: php bin/magento cache:clean"
    echo -e "  3. 检查权限: $0 check $site_path"
    echo
}

# 快速设置（使用当前用户）
quick_setup() {
    local site_path="$1"
    local current_user=$(whoami)
    
    if [[ "$current_user" == "root" ]]; then
        echo -e "${CROSS_MARK} ${RED}请不要以 root 用户运行快速设置${NC}"
        echo -e "${INFO_MARK} 使用: $0 setup [用户名] [路径]"
        exit 1
    fi
    
    setup_permissions "$current_user" "$site_path"
}

# 检查权限配置
check_permissions() {
    local site_path="$1"
    
    print_header
    echo -e "${INFO_MARK} ${CYAN}检查网站权限: $site_path${NC}"
    echo
    
    check_magento_dir "$site_path" || exit 1
    
    cd "$site_path" || exit 1
    
    echo -e "${YELLOW}文件所有者和组:${NC}"
    ls -ld . | awk '{print "  所有者: " $3 ", 组: " $4 ", 权限: " $1}'
    echo
    
    echo -e "${YELLOW}关键目录权限:${NC}"
    local check_dirs=(
        "var"
        "generated"
        "pub/media"
        "pub/static"
        "bin"
    )
    
    # 需要 setgid 的可写目录
    local writable_dirs=("var" "generated" "pub/media" "pub/static")
    
    for dir in "${check_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms=$(ls -ld "$dir" | awk '{print $1, $3, $4}')
            local perm_str=$(ls -ld "$dir" | awk '{print $1}')
            
            # 检查是否是可写目录且是否有 setgid
            local needs_setgid=false
            for wdir in "${writable_dirs[@]}"; do
                if [[ "$dir" == "$wdir" ]]; then
                    needs_setgid=true
                    break
                fi
            done
            
            if [[ "$needs_setgid" == true ]]; then
                if [[ "$perm_str" =~ rws ]]; then
                    echo -e "  $dir: $perms ${CHECK_MARK}"
                else
                    echo -e "  $dir: $perms ${WARNING_MARK} ${YELLOW}缺少 setgid${NC}"
                fi
            else
                echo -e "  $dir: $perms"
            fi
        else
            echo -e "  $dir: ${WARNING_MARK} 不存在"
        fi
    done
    echo
    
    echo -e "${YELLOW}Nginx 配置:${NC}"
    local nginx_user=$(grep "^user " "$NGINX_CONFIG" | awk '{print $2}' | sed 's/;//')
    echo -e "  Nginx 运行用户: ${nginx_user}"
    echo
    
    echo -e "${YELLOW}PHP-FPM 配置:${NC}"
    if [[ -f "$PHP_FPM_POOL" ]]; then
        local fpm_user=$(grep "^user = " "$PHP_FPM_POOL" | awk '{print $3}')
        local fpm_group=$(grep "^group = " "$PHP_FPM_POOL" | awk '{print $3}')
        echo -e "  PHP-FPM 运行用户: ${fpm_user}"
        echo -e "  PHP-FPM 运行组: ${fpm_group}"
    fi
    echo
    
    # 检查主目录权限（常见404问题）
    echo -e "${YELLOW}主目录权限检查:${NC}"
    local parent_dir=$(dirname "$site_path")
    local has_home_issue=false
    
    while [[ "$parent_dir" != "/" && "$parent_dir" =~ ^/home/ ]]; do
        local current_perms=$(stat -c "%a" "$parent_dir" 2>/dev/null)
        local other_perms=${current_perms: -1}
        local dir_display=$(ls -ld "$parent_dir" | awk '{print $1}')
        
        if [[ "$other_perms" == "0" ]]; then
            echo -e "  ${CROSS_MARK} ${RED}$parent_dir (${dir_display}) - 其他用户无执行权限${NC}"
            echo -e "     ${INFO_MARK} 这将导致 Nginx 无法访问网站，引发 404 错误"
            echo -e "     ${INFO_MARK} 建议运行: chmod 711 $parent_dir"
            has_home_issue=true
        else
            echo -e "  ${CHECK_MARK} $parent_dir (${dir_display}) - 权限正常"
        fi
        
        parent_dir=$(dirname "$parent_dir")
    done
    
    if [[ "$has_home_issue" == false ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}主目录权限正常${NC}"
    fi
    echo
    
    # Setgid 位检查
    echo -e "${YELLOW}Setgid 位检查（确保新文件继承组）:${NC}"
    local setgid_issues=0
    for dir in "var" "generated" "pub/media" "pub/static"; do
        if [[ -d "$dir" ]]; then
            local perm_str=$(ls -ld "$dir" | awk '{print $1}')
            if [[ "$perm_str" =~ rws ]]; then
                echo -e "  ${CHECK_MARK} $dir - setgid 已设置 (drwxrws**r**-x)"
            else
                echo -e "  ${CROSS_MARK} ${RED}$dir - 缺少 setgid${NC} ($perm_str)"
                echo -e "     ${INFO_MARK} 运行: cd $site_path && sudo find $dir -type d -exec chmod g+s {} \;"
                ((setgid_issues++))
            fi
        fi
    done
    
    if [[ "$setgid_issues" -eq 0 ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}所有可写目录都已正确设置 setgid${NC}"
    else
        echo -e "  ${WARNING_MARK} ${YELLOW}发现 $setgid_issues 个目录缺少 setgid，可能导致权限问题${NC}"
    fi
    echo
    
    # 权限检查
    echo -e "${YELLOW}权限问题检查:${NC}"
    local issues=0
    
    # 检查可写目录
    for dir in "var" "generated" "pub/media" "pub/static"; do
        if [[ -d "$dir" ]]; then
            if ! sudo -u "$NGINX_USER" test -w "$dir" 2>/dev/null; then
                echo -e "  ${CROSS_MARK} ${RED}$dir 不可写（Nginx 用户）${NC}"
                ((issues++))
            else
                echo -e "  ${CHECK_MARK} $dir 可写"
            fi
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}未发现权限问题${NC}"
    else
        echo -e "  ${WARNING_MARK} ${YELLOW}发现 $issues 个权限问题${NC}"
    fi
    echo
}

# 还原默认配置
restore_config() {
    print_header
    echo -e "${WARNING_MARK} ${YELLOW}还原 Nginx 和 PHP-FPM 为默认配置${NC}"
    echo
    
    read -p "确认还原? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${INFO_MARK} 操作已取消"
        exit 0
    fi
    
    echo -e "${INFO_MARK} ${CYAN}还原配置中...${NC}"
    echo
    
    # 还原 Nginx 用户
    if grep -q "^user " "$NGINX_CONFIG"; then
        sudo sed -i "s/^user .*/user $NGINX_USER;/" "$NGINX_CONFIG"
        echo -e "${CHECK_MARK} Nginx 用户已还原为: $NGINX_USER"
    fi
    
    # 还原 PHP-FPM 用户
    if [[ -f "$PHP_FPM_POOL" ]]; then
        sudo sed -i "s/^user = .*/user = $NGINX_USER/" "$PHP_FPM_POOL"
        sudo sed -i "s/^group = .*/group = $NGINX_GROUP/" "$PHP_FPM_POOL"
        echo -e "${CHECK_MARK} PHP-FPM 用户已还原为: $NGINX_USER"
        echo -e "${CHECK_MARK} PHP-FPM 组已还原为: $NGINX_GROUP"
    fi
    
    echo
    echo -e "${INFO_MARK} ${YELLOW}重启服务...${NC}"
    sudo systemctl restart nginx
    sudo systemctl restart php8.3-fpm
    
    echo
    echo -e "${CHECK_MARK} ${GREEN}配置已还原！${NC}"
    echo
}

# 主程序
main() {
    case "${1:-help}" in
        "setup")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 setup [用户名] [网站路径]"
                exit 1
            fi
            setup_permissions "$2" "$3"
            ;;
        
        "quick")
            if [[ -z "$2" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 quick [网站路径]"
                exit 1
            fi
            quick_setup "$2"
            ;;
        
        "check")
            if [[ -z "$2" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 check [网站路径]"
                exit 1
            fi
            check_permissions "$2"
            ;;
        
        "restore")
            restore_config
            ;;
        
        "help"|"--help"|"-h")
            print_help
            ;;
        
        *)
            echo -e "${CROSS_MARK} ${RED}未知选项: $1${NC}"
            echo
            print_help
            exit 1
            ;;
    esac
}

# 检查是否以 root 运行（restore 命令需要）
if [[ "$1" == "restore" ]] && [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo -e "${WARNING_MARK} ${YELLOW}此命令需要 sudo 权限${NC}"
fi

main "$@"
