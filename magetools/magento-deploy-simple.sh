#!/bin/bash
# Magento 2 部署脚本（无需 sudo 版本）
# 前提：用户已加入 www-data 组
# Usage: ./magento-deploy-simple.sh [网站路径]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CHECK_MARK="✅"
INFO_MARK="ℹ️"
GEAR="⚙️"

# 获取网站路径
SITE_PATH="${1:-$(pwd)}"

echo -e "${CYAN}=============================================="
echo -e "    Magento2 快速部署脚本 (无需 sudo)"
echo -e "==============================================${NC}"
echo

# 检查是否在 Magento 根目录
if [[ ! -f "$SITE_PATH/bin/magento" ]]; then
    echo -e "${RED}错误: 不是 Magento2 根目录${NC}"
    exit 1
fi

cd "$SITE_PATH"

# 显示当前模式
echo -e "${INFO_MARK} ${CYAN}当前 Magento 模式:${NC}"
php bin/magento deploy:mode:show
echo

# 检查是否在 www-data 组
if ! groups | grep -q www-data; then
    echo -e "${YELLOW}⚠️  警告: 当前用户不在 www-data 组${NC}"
    echo -e "${INFO_MARK} 运行: sudo usermod -aG www-data \$USER"
    echo -e "${INFO_MARK} 然后重新登录"
    echo
    read -p "是否继续? (可能需要 sudo 权限) (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo -e "${INFO_MARK} 网站路径: $SITE_PATH"
echo

# 1. 启用维护模式
echo -e "${GEAR} ${CYAN}启用维护模式...${NC}"
php bin/magento maintenance:enable
echo

# 2. 清理缓存和生成文件
echo -e "${GEAR} ${CYAN}清理缓存和生成文件...${NC}"

# 清理 var 目录
rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* var/di/* 2>/dev/null || true

# 清理 pub/static（保留 .htaccess）
find pub/static -mindepth 1 ! -name '.htaccess' -delete 2>/dev/null || true

# 清理产品图片缓存
rm -rf pub/media/catalog/product/cache/* 2>/dev/null || true

# 清理 generated 目录（智能处理）
echo -e "${INFO_MARK} 清理 generated 目录..."
if [[ -d "generated" ]]; then
    # 先尝试清空内容
    if rm -rf generated/* 2>/dev/null; then
        echo -e "  ${CHECK_MARK} 清空成功"
    else
        # 删除并重建
        rm -rf generated
        mkdir -p generated
        # 设置正确的组（如果当前用户在 www-data 组，可以不用 sudo）
        if groups | grep -q www-data; then
            chgrp www-data generated 2>/dev/null || sudo chgrp www-data generated
        fi
        chmod 775 generated
        echo -e "  ${CHECK_MARK} 已重建"
    fi
else
    mkdir -p generated
    if groups | grep -q www-data; then
        chgrp www-data generated 2>/dev/null || true
    fi
    chmod 775 generated
fi

echo -e "${CHECK_MARK} 清理完成"
echo

# 3. 数据库升级
echo -e "${GEAR} ${CYAN}数据库升级...${NC}"
php bin/magento setup:upgrade
echo

# 4. 编译依赖注入
echo -e "${GEAR} ${CYAN}编译依赖注入...${NC}"
php bin/magento setup:di:compile
echo

# 5. 部署静态内容
echo -e "${GEAR} ${CYAN}部署静态内容...${NC}"
php bin/magento setup:static-content:deploy -f -j 4
echo

# 6. 重建索引
echo -e "${GEAR} ${CYAN}重建索引...${NC}"
php bin/magento indexer:reindex
echo

# 7. 修复权限（确保组权限正确）
echo -e "${GEAR} ${CYAN}修复权限...${NC}"

# 如果在 www-data 组，可以直接设置组
if groups | grep -q www-data; then
    echo -e "${INFO_MARK} 使用组权限（无需 sudo）"
    find generated var pub/static pub/media -type d -exec chmod 775 {} \; 2>/dev/null || true
    find generated var pub/static pub/media -type f -exec chmod 664 {} \; 2>/dev/null || true
    # 确保组是 www-data
    find generated var pub/static pub/media -exec chgrp www-data {} \; 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  不在 www-data 组，跳过权限修复${NC}"
fi

echo -e "${CHECK_MARK} 权限修复完成"
echo

# 8. 禁用维护模式
echo -e "${GEAR} ${CYAN}禁用维护模式...${NC}"
php bin/magento maintenance:disable
echo

# 9. 清理缓存
echo -e "${GEAR} ${CYAN}清理 Magento 缓存...${NC}"
php bin/magento cache:clean
echo

# 10. 磁盘使用
echo -e "${INFO_MARK} ${CYAN}磁盘使用情况:${NC}"
du -h --max-depth=1 | sort -hr | head -10
echo

echo -e "${CHECK_MARK} ${GREEN}部署完成！${NC}"
echo

# 再次显示当前模式
echo -e "${INFO_MARK} ${CYAN}部署后 Magento 模式:${NC}"
php bin/magento deploy:mode:show
echo

# 显示关键目录权限
echo -e "${INFO_MARK} ${CYAN}关键目录权限:${NC}"
ls -ld generated var pub/static pub/media 2>/dev/null | awk '{print "  " $1, $3, $4, $9}'
echo

