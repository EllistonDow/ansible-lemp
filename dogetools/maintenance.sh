#!/bin/bash
# Magento 维护脚本（单站点版 + 锁机制 + 日志轮转）
# 用法:
# ./magento-maintenance.sh hourly SITE_NAME
# ./magento-maintenance.sh daily SITE_NAME
# ./magento-maintenance.sh weekly SITE_NAME

FREQ="$1"
SITE_NAME="$2"

if [[ -z "$FREQ" || -z "$SITE_NAME" ]]; then
    echo "Usage: $0 hourly|daily|weekly SITE_NAME"
    exit 1
fi

BASE_DIR="/home/doge"
SITE_DIR="${BASE_DIR}/${SITE_NAME}"
LOG_DIR="$HOME/Dropbox/logs"
PHP_BIN="/usr/bin/php"
mkdir -p "$LOG_DIR"

# ---------- 日志轮转 ----------
LOG_FILE="$LOG_DIR/magento-${SITE_NAME}-${FREQ}.log"
MAX_LOG_LINES=1000
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LOG_LINES" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

# ---------- 锁机制 ----------
LOCK_FILE="/tmp/magento_${SITE_NAME}_${FREQ}.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "Another $FREQ maintenance is running for $SITE_NAME, exiting."
    exit 0
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

DATE="$(date '+%Y-%m-%d %H:%M:%S')"

# 输出到日志和终端
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$DATE] START $FREQ maintenance for site: $SITE_NAME"

if [ ! -d "$SITE_DIR" ]; then
    echo "Site directory $SITE_DIR not found, exiting..."
    exit 1
fi
cd "$SITE_DIR" || exit 1

case "$FREQ" in
    hourly)
        echo "Starting async.operations.all consumer in background..."
        $PHP_BIN bin/magento queue:consumers:start async.operations.all --single-thread > /dev/null 2>&1 &
        find var/session/ -type f -mtime +1 -delete
        ;;
    daily)
        echo "Running Magento cron..."
        $PHP_BIN bin/magento cron:run

        echo "Starting async.operations.all consumer in background..."
        $PHP_BIN bin/magento queue:consumers:start async.operations.all --single-thread > /dev/null 2>&1 &

        find var/session/ -type f -mtime +1 -delete
        find var/log/ -type f -mtime +7 -delete

        INDEXER_STATUS=$($PHP_BIN bin/magento indexer:status)
        if echo "$INDEXER_STATUS" | grep -qiE 'require|invalid|reindex'; then
            echo "Invalid indexers found, running reindex..."
            $PHP_BIN bin/magento indexer:reindex
            echo "Refreshing invalidated cache..."
            $PHP_BIN bin/magento cache:flush
        else
            echo "All indexers OK, skipping reindex"
        fi
        ;;
    weekly)
        echo "Cleaning and flushing cache..."
        $PHP_BIN bin/magento cache:clean
        $PHP_BIN bin/magento cache:flush
        rm -rf var/cache/* var/page_cache/* pub/static/_cache/* var/view_preprocessed/*
        rm -rf pub/media/catalog/product/cache/*

        find var/log/ -type f -mtime +30 -delete

        echo "Running full reindex..."
        $PHP_BIN bin/magento indexer:reindex
        echo "Refreshing invalidated cache..."
        $PHP_BIN bin/magento cache:flush
        ;;
    *)
        echo "Invalid argument: $FREQ"
        exit 1
        ;;
esac

DATE_END="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[$DATE_END] FINISHED $FREQ maintenance for site: $SITE_NAME"
