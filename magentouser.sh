#!/bin/bash
# Magento2 用户权限快捷脚本
# 这是 magento-permissions.sh 的简化版本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/scripts/magento-permissions.sh"

# 颜色定义
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "错误: 找不到主脚本 $MAIN_SCRIPT"
    exit 1
fi

# 快捷方式
case "${1}" in
    "restore")
        # 还原默认配置
        "$MAIN_SCRIPT" restore
        ;;
    
    *)
        if [[ -z "$1" ]]; then
            echo -e "${CYAN}Magento2 用户权限快捷脚本${NC}"
            echo
            echo "用法："
            echo -e "  ${GREEN}./magentouser.sh [用户名]${NC}           - 为当前目录设置权限"
            echo -e "  ${GREEN}./magentouser.sh [用户名] [路径]${NC}   - 为指定目录设置权限"
            echo -e "  ${GREEN}./magentouser.sh restore${NC}            - 还原默认配置"
            echo
            echo "示例："
            echo -e "  ${CYAN}cd /home/doge/hawk && ./magentouser.sh doge${NC}"
            echo -e "  ${CYAN}./magentouser.sh doge /home/doge/tank${NC}"
            echo -e "  ${CYAN}./magentouser.sh restore${NC}"
            echo
            echo "完整功能请使用："
            echo -e "  ${GREEN}$MAIN_SCRIPT --help${NC}"
            exit 0
        fi
        
        # 设置权限
        if [[ -z "$2" ]]; then
            # 使用当前目录
            "$MAIN_SCRIPT" setup "$1" "$(pwd)"
        else
            # 使用指定目录
            "$MAIN_SCRIPT" setup "$1" "$2"
        fi
        ;;
esac
