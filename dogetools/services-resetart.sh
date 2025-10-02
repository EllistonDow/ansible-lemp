#!/bin/bash
# magento-services-restart.sh
# 重启 Magento 相关服务，日志保存在 /home/doge/cron/logs，并自动清理30天以上日志

LOG_DIR="/home/doge/Dropbox/croncripts/logs"
mkdir -p "$LOG_DIR"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
LOG_FILE="$LOG_DIR/services_restart_$(date +%Y%m%d_%H%M%S).log"

# 输出到日志和终端
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$DATE] START Magento services restart"

# ---------- 判断服务是否存在 ----------
SERVICES=("mysql" "rabbitmq-server" "php8.3-fpm" "opensearch")
if systemctl list-units --type=service | grep -q redis-server; then
    SERVICES+=("redis-server")
elif systemctl list-units --type=service | grep -q valkey; then
    SERVICES+=("valkey")
fi

# ---------- 重启服务 ----------
for svc in "${SERVICES[@]}"; do
    echo "重启服务: $svc"
    systemctl restart "$svc"
    sleep 2  # 等待服务完全启动
    systemctl is-active --quiet "$svc" && echo "$svc 已启动" || echo "警告: $svc 未能启动"
done

echo "[$DATE] FINISHED Magento services restart"

# ---------- 清理30天以上日志 ----------
find "$LOG_DIR" -type f -mtime +30 -name "*.log" -exec rm -f {} \;
echo "已清理30天以上日志"
