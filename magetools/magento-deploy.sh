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
echo -e "    自动处理权限问题（高性能模式）"
echo -e "    🚀 并行处理 + 批量操作"
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

# 7. 修复权限（使用高性能并行方法）
echo -e "${GEAR} ${CYAN}修复文件权限（高性能模式）...${NC}"

# 性能配置
MAX_PARALLEL_JOBS=8
BATCH_SIZE=1000

# 定义需要修复权限的目录
PERMISSION_DIRS=("generated" "var" "pub/static" "pub/media")

# 统计文件数量
total_files=0
for dir in "${PERMISSION_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        count=$(find "$dir" -type f 2>/dev/null | wc -l)
        total_files=$((total_files + count))
    fi
done

echo -e "${INFO_MARK} 需要处理 $total_files 个文件"

# 高性能权限修复函数
fix_permissions_fast() {
    local dir="$1"
    local description="$2"
    
    if [[ ! -d "$dir" ]]; then
        return 0
    fi
    
    echo -e "  ${INFO_MARK} 处理 $description..."
    
    # 批量设置所有者（一次性处理整个目录）
    sudo chown -R "${SITE_USER}:${NGINX_GROUP}" "$dir"
    
    # 并行设置目录权限
    find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 775 2>/dev/null || true
    
    # 并行设置文件权限
    find "$dir" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 664 2>/dev/null || true
    
    # 并行设置 setgid 位（确保新文件继承组）
    find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod g+s 2>/dev/null || true
    
    echo -e "    ${CHECK_MARK} $description 权限已修复"
}

# 并行处理所有目录（真正的并行）
echo -e "  ${INFO_MARK} 启动并行权限修复..."

# 创建并行任务
for dir in "${PERMISSION_DIRS[@]}"; do
    case "$dir" in
        "generated")
            fix_permissions_fast "$dir" "generated 目录" &
            ;;
        "var")
            fix_permissions_fast "$dir" "var 目录" &
            ;;
        "pub/static")
            fix_permissions_fast "$dir" "pub/static 目录" &
            ;;
        "pub/media")
            fix_permissions_fast "$dir" "pub/media 目录" &
            ;;
    esac
done

# 等待所有并行任务完成
wait

echo -e "${CHECK_MARK} 所有权限已修复（高性能模式）"

# 显示性能统计
echo -e "${INFO_MARK} ${CYAN}权限修复性能统计:${NC}"
echo -e "  处理文件: $total_files 个"
echo -e "  并行任务: $MAX_PARALLEL_JOBS 个"
echo -e "  批处理大小: $BATCH_SIZE 个/批"
echo -e "  优化方法: 并行处理 + 批量操作"
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

