#!/bin/bash
# Magento 维护脚本（干净版 - 不使用 sudo）
# 前提：用户必须在 www-data 组中
# 用法: ./magento-maintenance-clean.sh hourly|daily|weekly SITE_NAME

FREQ="$1"
SITE_NAME="$2"

if [[ -z "$FREQ" || -z "$SITE_NAME" ]]; then
    echo "Usage: $0 hourly|daily|weekly SITE_NAME"
    exit 1
fi

BASE_DIR="/home/doge"
SITE_DIR="${BASE_DIR}/${SITE_NAME}"
LOG_DIR="$HOME/Dropbox/cronscripts/logs"
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

# 检查用户是否在 www-data 组中
if ! id -nG "$(whoami)" | grep -q "www-data"; then
    echo "⚠️  警告: 用户 $(whoami) 不在 www-data 组中"
    echo "   请运行: sudo usermod -a -G www-data $(whoami)"
    echo "   然后重新登录或运行: newgrp www-data"
fi

case "$FREQ" in
    hourly)
        echo "Starting async.operations.all consumer in background..."
        $PHP_BIN bin/magento queue:consumers:start async.operations.all --single-thread > /dev/null 2>&1 &
        
        echo "Cleaning old sessions..."
        if [ -d "var/session" ]; then
            find var/session -type f -mtime +1 -delete 2>/dev/null || echo "  ⚠️  Some files could not be deleted"
        fi
        ;;
        
    daily)
        echo "Running Magento cron..."
        $PHP_BIN bin/magento cron:run

        echo "Starting async.operations.all consumer in background..."
        $PHP_BIN bin/magento queue:consumers:start async.operations.all --single-thread > /dev/null 2>&1 &

        echo "Cleaning old sessions and logs..."
        [ -d "var/session" ] && find var/session -type f -mtime +1 -delete 2>/dev/null
        [ -d "var/log" ] && find var/log -type f -mtime +7 -delete 2>/dev/null

        echo "Checking indexer status..."
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
        echo "=== Weekly Deep Maintenance ==="
        
        echo "Step 1: Enabling maintenance mode..."
        $PHP_BIN bin/magento maintenance:enable
        echo "  ✓ Maintenance mode enabled"
        
        echo "Step 2: Running full reindex..."
        $PHP_BIN bin/magento indexer:reindex
        
        echo "Step 3: Cleaning Magento cache via CLI..."
        $PHP_BIN bin/magento cache:clean
        $PHP_BIN bin/magento cache:flush
        
        echo "Step 4: Removing cache directories..."
        rm -rf var/cache/* var/page_cache/* 2>/dev/null || echo "  ⚠️  Some cache files could not be deleted"
        rm -rf pub/static/_cache/* var/view_preprocessed/* 2>/dev/null || echo "  ⚠️  Some static cache could not be deleted"
        
        echo "Step 5: Cleaning product image cache..."
        if [ -d "pub/media/catalog/product/cache" ]; then
            FILE_COUNT=$(find pub/media/catalog/product/cache -type f 2>/dev/null | wc -l)
            echo "  Found $FILE_COUNT cached images"
            
            if [ "$FILE_COUNT" -gt 0 ]; then
                echo "  Deleting $FILE_COUNT cached images..."
                
                # 直接删除所有缓存文件
                find pub/media/catalog/product/cache -type f -delete 2>/dev/null
                find pub/media/catalog/product/cache -type d -empty -delete 2>/dev/null
                
                # 统计剩余文件
                REMAINING=$(find pub/media/catalog/product/cache -type f 2>/dev/null | wc -l)
                DELETED=$((FILE_COUNT - REMAINING))
                
                if [ "$REMAINING" -eq 0 ]; then
                    echo "  ✓ Successfully deleted all $FILE_COUNT images"
                else
                    echo "  ✓ Deleted: $DELETED images"
                    echo "  ⚠️  Remaining: $REMAINING images"
                    echo "     Run: echo 'y' | ~/ansible-lemp/scripts/magento-permissions.sh setup doge $SITE_DIR"
                fi
            else
                echo "  ✓ No cached images to clean"
            fi
        fi

        echo "Step 6: Cleaning very old logs..."
        [ -d "var/log" ] && find var/log -type f -mtime +30 -delete 2>/dev/null
        
        echo "Step 7: Disabling maintenance mode..."
        $PHP_BIN bin/magento maintenance:disable
        echo "  ✓ Maintenance mode disabled - Site is now live"
        
        echo "=== Weekly Maintenance Complete ==="
        ;;
        
    *)
        echo "Invalid argument: $FREQ"
        exit 1
        ;;
esac

DATE_END="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[$DATE_END] FINISHED $FREQ maintenance for site: $SITE_NAME"

