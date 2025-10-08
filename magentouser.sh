#!/bin/bash
# Magento2 权限设置简化脚本
# 自动选择最优的权限设置方法
# Usage: ./magentouser.sh [用户名] [网站路径]

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 符号定义
ROCKET="🚀"
INFO_MARK="ℹ️"

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 权限设置工具"
    echo -e "    ${ROCKET} 自动选择最优方法"
    echo -e "==============================================${NC}"
    echo
}

print_help() {
    print_header
    echo -e "${YELLOW}用法: $0 [用户名] [网站路径]${NC}"
    echo
    echo -e "${YELLOW}基本用法:${NC}"
    echo -e "  ${GREEN}$0 [用户名]${NC}                    # 为当前目录设置权限"
    echo -e "  ${GREEN}$0 [用户名] [网站路径]${NC}          # 为指定目录设置权限"
    echo -e "  ${GREEN}$0 restore${NC}                     # 还原默认配置"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${INFO_MARK} cd /home/doge/hawk && $0 doge"
    echo -e "  ${INFO_MARK} $0 doge /home/doge/tank"
    echo -e "  ${INFO_MARK} $0 restore"
    echo
    echo -e "${YELLOW}特性:${NC}"
    echo -e "  ${ROCKET} 自动选择高性能方法"
    echo -e "  ${ROCKET} 支持并行处理"
    echo -e "  ${ROCKET} 智能权限检查"
    echo
}

# 检查文件数量来决定使用哪种方法
get_file_count() {
    local path="$1"
    if [[ -d "$path" ]]; then
        find "$path" -type f 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# 主程序
main() {
    case "${1:-help}" in
        "restore")
            echo -e "${INFO_MARK} 还原默认配置..."
            echo -e "${WARNING_MARK} ${YELLOW}注意: 请手动还原 Nginx 和 PHP-FPM 配置${NC}"
            echo -e "${INFO_MARK} 运行: sudo systemctl restart nginx php8.3-fpm"
            ;;
        
        "help"|"--help"|"-h")
            print_help
            ;;
        
        *)
            if [[ -z "$1" ]]; then
                echo -e "${YELLOW}错误: 请指定用户名${NC}"
                echo
                print_help
                exit 1
            fi
            
            local site_user="$1"
            local site_path="${2:-.}"
            
            # 检查目录
            if [[ ! -d "$site_path" ]]; then
                echo -e "${YELLOW}错误: 目录不存在: $site_path${NC}"
                exit 1
            fi
            
            # 获取文件数量
            local file_count=$(get_file_count "$site_path")
            
            print_header
            echo -e "${INFO_MARK} 配置信息:"
            echo -e "  用户: $site_user"
            echo -e "  路径: $site_path"
            echo -e "  文件数量: $file_count"
            echo
            
            # 根据文件数量选择方法
            if [[ $file_count -gt 10000 ]]; then
                echo -e "${ROCKET} 检测到大型项目，使用高性能方法..."
                ~/ansible-lemp/magetools/magento-permissions-fast.sh fast "$site_user" "$site_path"
            else
                echo -e "${INFO_MARK} 使用高性能方法（推荐）..."
                ~/ansible-lemp/magetools/magento-permissions-fast.sh fast "$site_user" "$site_path"
            fi
            ;;
    esac
}

main "$@"
