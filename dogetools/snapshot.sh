#!/bin/bash
# snapshot.sh
# 用法:
#   ./snapshot.sh <SITE_NAME> [RETENTION_DAYS]
# 示例:
#   ./snapshot.sh papa        # 默认保留 30 天
#   ./snapshot.sh ambi 15     # 保留 15 天

SITE_NAME=$1                # 站点名称
RETENTION_DAYS=${2:-30}     # 保留天数，默认 30

# ---------- 配置根目录 ----------
ROOT_DIR="/home/doge/Dropbox"   # 修改为你的备份存放位置

# ---------- 站点根目录 ----------
SITE_ROOT="/home/doge/${SITE_NAME}"

# ---------- 备份目录 ----------
BACKUP_DIR="${ROOT_DIR}/${SITE_NAME}/snapshot"
mkdir -p "$BACKUP_DIR"

# ---------- 时间戳 ----------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${SITE_NAME}_${TIMESTAMP}.tar.gz"

echo "开始备份站点: $SITE_NAME"
echo "源目录: $SITE_ROOT"
echo "备份文件: $BACKUP_FILE"
echo "保留天数: $RETENTION_DAYS"

# ---------- 检查工具 pv ----------
if ! command -v pv &>/dev/null; then
    echo "pv 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y pv || { echo "请手动安装 pv"; exit 1; }
fi

# ---------- 执行全量备份 ----------
TOTAL_SIZE=$(du -sb "$SITE_ROOT" | awk '{print $1}')
tar -cf - -C "$SITE_ROOT" . | pv -s "$TOTAL_SIZE" | gzip > "$BACKUP_FILE"

# ---------- 完成 ----------
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "备份完成: $BACKUP_FILE (大小: $BACKUP_SIZE)"

# ---------- 更新最新符号链接 ----------
ln -sf "$BACKUP_FILE" "${BACKUP_DIR}/latest.tar.gz"

# ---------- 清理过期备份 ----------
find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.tar.gz" -mtime +$RETENTION_DAYS | while read -r OLD; do
    echo "删除过期备份: $OLD"
    rm -f "$OLD"
done
