#!/bin/bash
# dumpdb.sh - 优化版本
# 用法: ./dumpdb.sh <SITE_NAME> <DB_NAME> [RETENTION_DAYS]

set -e  # 遇到错误立即退出

SITE_NAME=$1
DB_NAME=$2
RETENTION_DAYS=${3:-30}

# 参数验证
if [ -z "$SITE_NAME" ] || [ -z "$DB_NAME" ]; then
    echo "❌ 用法: $0 <SITE_NAME> <DB_NAME> [RETENTION_DAYS]"
    exit 1
fi

# 配置
BACKUP_ROOT="/home/doge/Dropbox"
SITE_BACKUP_DIR="${BACKUP_ROOT}/${SITE_NAME}/database"

# 权限检查
if [ ! -w "$BACKUP_ROOT" ]; then
    echo "❌ 备份目录无写权限: $BACKUP_ROOT"
    exit 1
fi

# 创建备份目录
DATESTAMP=$(date +"%Y%m%d")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SITE_BACKUP_DIR}/${DATESTAMP}"
mkdir -p "$BACKUP_DIR"

# 备份文件
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

# 执行备份（带错误检查）
echo "🔄 开始备份: $DB_NAME"
if ! mysqldump --defaults-group-suffix="$SITE_NAME" --single-transaction --routines --triggers --events "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    echo "❌ 备份失败: $DB_NAME"
    exit 1
fi

# 获取备份大小
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)

# 更新符号链接
ln -sf "$BACKUP_DIR" "${SITE_BACKUP_DIR}/latest"

# 清理过期备份
echo "🧹 清理过期备份..."
find "$SITE_BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS | while read -r OLD; do
    echo "🗑️ 删除过期备份: $OLD"
    rm -rf "$OLD"
done

# 输出结果
echo "✅ 备份完成: $BACKUP_FILE"
echo "📊 数据大小: $BACKUP_SIZE"
echo "⏰ 保留天数: $RETENTION_DAYS"