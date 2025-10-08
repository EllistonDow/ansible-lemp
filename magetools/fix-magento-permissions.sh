#!/bin/bash

# Magento 权限自动修复脚本（高性能版本）
# 用于解决 generated 目录权限反复变化的问题

SITE_PATH="$1"
NGINX_GROUP="www-data"

if [ -z "$SITE_PATH" ]; then
    echo "用法: $0 <站点路径>"
    echo "示例: $0 /home/doge/sava"
    exit 1
fi

if [ ! -d "$SITE_PATH" ]; then
    echo "错误: 站点目录不存在: $SITE_PATH"
    exit 1
fi

echo "🔧 修复 $SITE_PATH 的权限（高性能模式）..."

# 性能配置
MAX_PARALLEL_JOBS=8
BATCH_SIZE=1000

# 1. 批量设置目录所有者（一次性处理整个目录）
echo "设置目录所有者..."
sudo chown -R "$(whoami):$NGINX_GROUP" "$SITE_PATH"

# 2. 并行设置目录权限
echo "设置目录权限（并行处理）..."
find "$SITE_PATH" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 775 2>/dev/null || true

# 3. 并行设置文件权限
echo "设置文件权限（并行处理）..."
find "$SITE_PATH" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 664 2>/dev/null || true

# 4. 并行设置 setgid 位（确保新文件继承组）
echo "设置 setgid 位（并行处理）..."
find "$SITE_PATH" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod g+s 2>/dev/null || true

# 5. 特殊处理关键目录（使用高性能方法）
echo "特殊处理关键目录..."

# 定义需要特殊处理的目录
SPECIAL_DIRS=("generated" "var" "pub/static" "pub/media")

for dir in "${SPECIAL_DIRS[@]}"; do
    if [ -d "$SITE_PATH/$dir" ]; then
        echo "  处理 $dir 目录..."
        
        # 批量设置所有者
        sudo chown -R "$(whoami):$NGINX_GROUP" "$SITE_PATH/$dir"
        
        # 并行设置目录权限
        find "$SITE_PATH/$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 775 2>/dev/null || true
        
        # 并行设置文件权限
        find "$SITE_PATH/$dir" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 664 2>/dev/null || true
        
        # 并行设置 setgid 位
        find "$SITE_PATH/$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod g+s 2>/dev/null || true
    fi
done

echo "✅ 权限修复完成（高性能模式）！"
echo ""
echo "📋 修复内容:"
echo "  • 设置所有者为: $(whoami):$NGINX_GROUP"
echo "  • 设置 setgid 位确保新文件继承组"
echo "  • 目录权限: 775"
echo "  • 文件权限: 664"
echo "  • 特殊处理: generated, var, pub/static, pub/media"
echo "  • 性能优化: 并行处理 + 批量操作"
echo ""
echo "💡 建议: 将此脚本添加到 crontab 中定期运行"
echo "   例如: */5 * * * * $0 $SITE_PATH"
