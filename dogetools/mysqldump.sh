#!/bin/bash
# dumpdb.sh
# 用法:
#   ./dumpdb.sh <SITE_NAME> <DB_NAME> [RETENTION_DAYS]
# 示例:
#   ./dumpdb.sh hawk hawkmage         # 默认保留 30 天
#   ./dumpdb.sh sava savamage 60      # 保留 60 天

SITE_NAME=$1
DB_NAME=$2
RETENTION_DAYS=${3:-30}   # 保留天数，默认 30

# ---------- 配置根目录 ----------
BACKUP_ROOT="/home/doge/Dropbox"   # 手动修改即可

# ---------- 站点数据库备份目录 ----------
SITE_BACKUP_DIR="${BACKUP_ROOT}/${SITE_NAME}/database"

# ---------- 时间戳 ----------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SITE_BACKUP_DIR}/${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

# ---------- 备份文件 ----------
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

# ---------- 执行备份 ----------
mysqldump --defaults-group-suffix="$SITE_NAME" --single-transaction --routines --triggers --events "$DB_NAME" | gzip > "$BACKUP_FILE"

# ---------- 获取备份大小 ----------
BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)

# ---------- 更新最新备份符号链接 ----------
ln -sf "$BACKUP_DIR" "${SITE_BACKUP_DIR}/latest"

# ---------- 清理过期备份 ----------
find "$SITE_BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS | while read -r OLD; do
    echo "删除过期备份: $OLD"
    rm -rf "$OLD"
done

# ---------- 输出结果 ----------
echo "备份完成: $BACKUP_FILE"
echo "数据大小: $BACKUP_SIZE"
echo "保留天数: $RETENTION_DAYS"
