#!/bin/bash
# Magento 2 部署脚本
# 自动处理权限问题
# Usage: ./magento-deploy.sh [网站路径]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 符号定义
CHECK_MARK="✅"
INFO_MARK="ℹ️"
GEAR="⚙️"

# 获取网站路径
SITE_PATH="${1:-$(pwd)}"
SITE_USER=$(stat -c "%U" "$SITE_PATH")
NGINX_GROUP="www-data"

echo -e "${CYAN}=============================================="
echo -e "    Magento2 部署脚本"
echo -e "    自动处理权限问题"
echo -e "==============================================${NC}"
echo

# 检查是否在 Magento 根目录
if [[ ! -f "$SITE_PATH/bin/magento" ]]; then
    echo -e "${RED}错误: 不是 Magento2 根目录${NC}"
    echo -e "当前路径: $SITE_PATH"
    exit 1
fi

cd "$SITE_PATH"

echo -e "${INFO_MARK} 网站路径: $SITE_PATH"
echo -e "${INFO_MARK} 文件所有者: $SITE_USER"
echo -e "${INFO_MARK} Nginx 组: $NGINX_GROUP"
echo

# 显示当前模式
echo -e "${INFO_MARK} ${CYAN}当前 Magento 模式:${NC}"
php bin/magento deploy:mode:show
echo

# 1. 启用维护模式
echo -e "${GEAR} ${CYAN}启用维护模式...${NC}"
php bin/magento maintenance:enable
echo -e "${CHECK_MARK} 维护模式已启用"
echo

# 2. 清理缓存和生成文件
echo -e "${GEAR} ${CYAN}清理缓存和生成文件...${NC}"

# 清理 var 目录（保留目录结构）
echo -e "${INFO_MARK} 清理 var 目录..."
rm -rf var/cache/* var/page_cache/* var/view_preprocessed/* var/di/* 2>/dev/null || true

# 清理 pub/static（保留 .htaccess）
echo -e "${INFO_MARK} 清理 pub/static..."
find pub/static -mindepth 1 ! -name '.htaccess' -delete 2>/dev/null || true

# 清理 pub/media/catalog/product/cache
echo -e "${INFO_MARK} 清理产品图片缓存..."
rm -rf pub/media/catalog/product/cache/* 2>/dev/null || true

# 清理并重建 generated 目录（关键部分）
echo -e "${INFO_MARK} 清理 generated 目录..."
if [[ -d "generated" ]]; then
    # 方法1: 尝试清空内容
    if rm -rf generated/* 2>/dev/null; then
        echo -e "  ${CHECK_MARK} 清空成功（保留目录）"
    else
        # 方法2: 删除并重建（需要重新设置权限）
        echo -e "  ${YELLOW}⚠️  无法清空，尝试删除重建...${NC}"
        sudo rm -rf generated
        mkdir -p generated
        # 立即设置正确的所有者和权限
        sudo chown "${SITE_USER}:${NGINX_GROUP}" generated
        sudo chmod 775 generated
        echo -e "  ${CHECK_MARK} 已重建并设置权限"
    fi
else
    # 目录不存在，创建它
    mkdir -p generated
    sudo chown "${SITE_USER}:${NGINX_GROUP}" generated
    sudo chmod 775 generated
    echo -e "  ${CHECK_MARK} 已创建 generated 目录"
fi

echo -e "${CHECK_MARK} 清理完成"
echo

# 3. 运行 Magento 升级
echo -e "${GEAR} ${CYAN}运行数据库升级...${NC}"
php bin/magento setup:upgrade
echo -e "${CHECK_MARK} 数据库升级完成"
echo

# 4. 编译依赖注入
echo -e "${GEAR} ${CYAN}编译依赖注入...${NC}"
php bin/magento setup:di:compile
echo -e "${CHECK_MARK} DI 编译完成"
echo

# 5. 部署静态内容
echo -e "${GEAR} ${CYAN}部署静态内容...${NC}"
php bin/magento setup:static-content:deploy -f -j 4
echo -e "${CHECK_MARK} 静态内容部署完成"
echo

# 6. 重建索引
echo -e "${GEAR} ${CYAN}重建索引...${NC}"
php bin/magento indexer:reindex
echo -e "${CHECK_MARK} 索引重建完成"
echo

# 7. 修复权限（确保所有新生成的文件权限正确）
echo -e "${GEAR} ${CYAN}修复文件权限...${NC}"

# 设置 generated 目录权限（递归）
if [[ -d "generated" ]]; then
    sudo chown -R "${SITE_USER}:${NGINX_GROUP}" generated
    sudo find generated -type d -exec chmod 775 {} \;
    sudo find generated -type f -exec chmod 664 {} \;
    echo -e "  ${CHECK_MARK} generated 目录权限已修复"
fi

# 设置 var 目录权限
sudo chown -R "${SITE_USER}:${NGINX_GROUP}" var
sudo find var -type d -exec chmod 775 {} \;
sudo find var -type f -exec chmod 664 {} \; 2>/dev/null || true
echo -e "  ${CHECK_MARK} var 目录权限已修复"

# 设置 pub/static 权限
sudo chown -R "${SITE_USER}:${NGINX_GROUP}" pub/static
sudo find pub/static -type d -exec chmod 775 {} \;
sudo find pub/static -type f -exec chmod 664 {} \; 2>/dev/null || true
echo -e "  ${CHECK_MARK} pub/static 目录权限已修复"

# 设置 pub/media 权限
sudo chown -R "${SITE_USER}:${NGINX_GROUP}" pub/media
sudo find pub/media -type d -exec chmod 775 {} \;
sudo find pub/media -type f -exec chmod 664 {} \; 2>/dev/null || true
echo -e "  ${CHECK_MARK} pub/media 目录权限已修复"

echo -e "${CHECK_MARK} 所有权限已修复"
echo

# 8. 禁用维护模式
echo -e "${GEAR} ${CYAN}禁用维护模式...${NC}"
php bin/magento maintenance:disable
echo -e "${CHECK_MARK} 维护模式已禁用"
echo

# 9. 清理 Magento 缓存
echo -e "${GEAR} ${CYAN}清理 Magento 缓存...${NC}"
php bin/magento cache:clean
echo -e "${CHECK_MARK} 缓存已清理"
echo

# 10. 显示磁盘使用情况
echo -e "${INFO_MARK} ${CYAN}磁盘使用情况:${NC}"
du -h --max-depth=1 | sort -hr | head -10
echo

echo -e "${CHECK_MARK} ${GREEN}部署完成！${NC}"
echo -e "${INFO_MARK} 网站应该可以正常访问了"
echo

# 再次显示当前模式
echo -e "${INFO_MARK} ${CYAN}部署后 Magento 模式:${NC}"
php bin/magento deploy:mode:show
echo

# 可选：显示生成目录的权限
echo -e "${INFO_MARK} ${CYAN}关键目录权限检查:${NC}"
ls -ld generated var pub/static pub/media | awk '{print "  " $1, $3, $4, $9}'
echo

