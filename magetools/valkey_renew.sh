#!/bin/bash

# 整合的Valkey配置和更新工具

# 错误处理：确保维护模式被禁用
cleanup() {
    if [ -n "$MAINTENANCE_ENABLED" ]; then
        echo -e "\n${YELLOW}🔓 脚本中断，正在禁用维护模式...${NC}"
        php bin/magento maintenance:disable 2>/dev/null || true
        echo -e "${GREEN}✅ 维护模式已禁用${NC}"
    fi
}

# 设置陷阱，确保脚本退出时执行清理
trap cleanup EXIT INT TERM

# 使用方法：./valkey_renew.sh <站点名称> <默认缓存DB> <页面缓存DB> <会话存储DB> [--restart-valkey]

# 示例：./valkey_renew.sh sava 10 11 12
# 示例：./valkey_renew.sh bdgy 20 21 22
# 示例：./valkey_renew.sh ntca 30 31 32
# 示例：./valkey_renew.sh ipwa 40 41 42
# 示例：./valkey_renew.sh hawk 50 51 52
# 示例：./valkey_renew.sh ambi 60 61 62
# 示例：./valkey_renew.sh papa 70 71 72
# 示例：./valkey_renew.sh ipwa 40 41 42 --restart-valkey
  

# 颜色定义

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

CYAN='\033[0;36m'

NC='\033[0m'

  

# 检查参数
RESTART_VALKEY=false

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo -e "${RED}❌ 参数错误${NC}"
    echo -e "${YELLOW}使用方法:${NC} $0 <站点名称> <默认缓存DB> <页面缓存DB> <会话存储DB> [--restart-valkey]"
    echo -e "${YELLOW}示例:${NC} $0 sava 10 11 12"
    echo -e "${YELLOW}示例:${NC} $0 ipwa 40 41 42 --restart-valkey"
    echo ""
    echo -e "${CYAN}💡 说明:${NC}"
    echo " 此工具会："
    echo " 1. 自定义数据库配置"
    echo " 2. 执行完整的renew流程"
    echo " 3. 可选重启Valkey服务"
    exit 1
fi

# 解析参数
if [ $# -eq 5 ] && [ "$5" = "--restart-valkey" ]; then
    RESTART_VALKEY=true
fi

  

SITE_NAME="$1"

CACHE_DB="$2"

PAGE_DB="$3"

SESSION_DB="$4"

# 验证站点名称安全性
if [[ "$SITE_NAME" =~ [^a-zA-Z0-9_-] ]]; then
    echo -e "${RED}❌ 站点名称包含非法字符: $SITE_NAME${NC}"
    echo -e "${YELLOW}只允许字母、数字、下划线和连字符${NC}"
    exit 1
fi

  

# 验证数据库编号

for db in "$CACHE_DB" "$PAGE_DB" "$SESSION_DB"; do

if ! [[ "$db" =~ ^[0-9]+$ ]]; then

echo -e "${RED}❌ 数据库编号必须是数字: $db${NC}"

exit 1

fi

done

  

# 检查数据库编号是否重复

if [ "$CACHE_DB" = "$PAGE_DB" ] || [ "$CACHE_DB" = "$SESSION_DB" ] || [ "$PAGE_DB" = "$SESSION_DB" ]; then

echo -e "${RED}❌ 数据库编号不能重复${NC}"

exit 1

fi

  

echo -e "${BLUE}🎯 整合配置站点: $SITE_NAME${NC}"

echo "================================================"

  

# 检查站点路径

SITE_PATH="/home/doge/$SITE_NAME"

if [ ! -d "$SITE_PATH" ]; then

echo -e "${RED}❌ 站点路径不存在: $SITE_PATH${NC}"

exit 1

fi

  

echo -e "${GREEN}📁 站点路径: $SITE_PATH${NC}"

echo -e "${GREEN}📊 数据库分配:${NC}"

echo -e " 默认缓存: DB $CACHE_DB"

echo -e " 页面缓存: DB $PAGE_DB"

echo -e " 会话存储: DB $SESSION_DB"

echo ""

  

# 切换到站点目录

cd "$SITE_PATH" || {

echo -e "${RED}❌ 无法切换到站点目录${NC}"

exit 1

}

  

# 检查env.php文件

if [ ! -f "app/etc/env.php" ]; then

echo -e "${RED}❌ 找不到 app/etc/env.php 文件${NC}"

exit 1

fi

  

echo -e "${YELLOW}🔧 开始整合配置...${NC}"

  

# 备份原文件

cp app/etc/env.php app/etc/env.php.backup.$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}✅ 已备份原配置文件${NC}"

  

# 第一步：自定义数据库配置

echo -e "${CYAN}📝 第一步：自定义数据库配置...${NC}"

  

# 修改env.php文件 - 使用更精确的替换

# 替换默认缓存的数据库

sed -i "/'default' => \[/,/\]/ s/'database' => '[0-9]*'/'database' => '$CACHE_DB'/g" app/etc/env.php

  

# 替换页面缓存的数据库

sed -i "/'page_cache' => \[/,/\]/ s/'database' => '[0-9]*'/'database' => '$PAGE_DB'/g" app/etc/env.php

  

# 替换会话存储的数据库

sed -i "/'session' => \[/,/\]/ s/'database' => '[0-9]*'/'database' => '$SESSION_DB'/g" app/etc/env.php

# 替换会话存储的前缀

sed -i "/'session' => \[/,/\]/ s/'id_prefix' => '[^']*'/'id_prefix' => '${SITE_NAME}_session_'/g" app/etc/env.php

  

# 设置缓存前缀 - 使用更可靠的方法

# 先替换会话存储的前缀（避免被后续替换影响）
sed -i "/'session' => \[/,/^[[:space:]]*\],/ s/'id_prefix' => '[^']*'/'id_prefix' => '${SITE_NAME}_session_'/g" app/etc/env.php

# 然后替换所有其他缓存的前缀为统一前缀
sed -i "s/'id_prefix' => '[^']*'/'id_prefix' => '${SITE_NAME}_cache_'/g" app/etc/env.php

# 最后重新设置会话存储的前缀（确保正确）
sed -i "/'session' => \[/,/^[[:space:]]*\],/ s/'id_prefix' => '[^']*'/'id_prefix' => '${SITE_NAME}_session_'/g" app/etc/env.php

  

echo -e "${GREEN}✅ 数据库配置完成${NC}"

  

# 第二步：执行renew流程

echo -e "${CYAN}🔨 第二步：执行renew流程...${NC}"

# 启用维护模式
echo -e "${YELLOW}🔒 启用维护模式...${NC}"
if ! php bin/magento maintenance:enable 2>/dev/null; then
    echo -e "${YELLOW}⚠ 维护模式启用失败，继续执行...${NC}"
else
    echo -e "${GREEN}✅ 维护模式已启用${NC}"
    MAINTENANCE_ENABLED=1
fi

  

# 检查Redis/Valkey服务

if ! redis-cli ping >/dev/null 2>&1; then

echo -e "${RED}❌ Redis/Valkey服务未运行${NC}"

exit 1

fi

echo -e "${GREEN}✅ Redis/Valkey服务正常运行${NC}"

  

# 清理缓存和生成文件

echo -e "${YELLOW}🧹 清理缓存和生成文件...${NC}"

  

# 清理缓存

if ! php bin/magento cache:clean 2>/dev/null; then
    echo -e "${YELLOW}⚠ 缓存清理失败，继续执行...${NC}"
fi

if ! php bin/magento cache:flush 2>/dev/null; then
    echo -e "${YELLOW}⚠ 缓存刷新失败，继续执行...${NC}"
fi

  

# 清理生成文件

rm -rf generated/* 2>/dev/null || true

rm -rf var/cache/* 2>/dev/null || true

rm -rf var/page_cache/* 2>/dev/null || true

rm -rf pub/static/* 2>/dev/null || true

  

# 强制清理generated/code

find generated/code -type f -delete 2>/dev/null || true

find generated/code -type d -empty -delete 2>/dev/null || true

  

echo -e "${GREEN}✅ 文件清理完成${NC}"

  

# 重新编译和部署

echo -e "${YELLOW}🔨 重新编译和部署...${NC}"

  

# 重新编译

if ! php bin/magento setup:di:compile 2>/dev/null; then
    echo -e "${YELLOW}⚠ 依赖注入编译失败，继续执行...${NC}"
fi

  

# 部署静态内容

if ! php bin/magento setup:static-content:deploy -f 2>/dev/null; then
    echo -e "${YELLOW}⚠ 静态内容部署失败，继续执行...${NC}"
fi

  

echo -e "${GREEN}✅ 编译和部署完成${NC}"

  

# 清空Valkey缓存

echo -e "${YELLOW}🗑️ 清空站点 $SITE_NAME 的Valkey缓存...${NC}"

  

# 清空指定数据库

if ! redis-cli -n $CACHE_DB flushdb 2>/dev/null; then
    echo -e "${YELLOW}⚠ 清空缓存数据库 $CACHE_DB 失败${NC}"
fi

if ! redis-cli -n $PAGE_DB flushdb 2>/dev/null; then
    echo -e "${YELLOW}⚠ 清空页面缓存数据库 $PAGE_DB 失败${NC}"
fi

if ! redis-cli -n $SESSION_DB flushdb 2>/dev/null; then
    echo -e "${YELLOW}⚠ 清空会话数据库 $SESSION_DB 失败${NC}"
fi

  

# 重启Valkey服务（可选，确保配置生效）
if [ "$RESTART_VALKEY" = true ]; then
    echo -e "${YELLOW}🔄 重启Valkey服务...${NC}"
    if sudo systemctl restart valkey 2>/dev/null; then
        echo -e "${GREEN}✅ Valkey服务已重启${NC}"
        # 等待服务启动
        sleep 2
        # 验证服务状态
        if redis-cli ping >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Valkey服务运行正常${NC}"
        else
            echo -e "${YELLOW}⚠ Valkey服务可能未正常启动，请检查${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Valkey服务重启失败，继续执行...${NC}"
    fi
else
    echo -e "${CYAN}💡 提示: 使用 --restart-valkey 参数可重启Valkey服务${NC}"
fi

  

# 确保必要目录存在

echo -e "${YELLOW}📁 确保必要目录存在...${NC}"

mkdir -p var/cache var/page_cache var/log var/session var/tmp 2>/dev/null || true

mkdir -p generated/code generated/metadata 2>/dev/null || true

mkdir -p pub/static pub/media 2>/dev/null || true

  

echo -e "${GREEN}✅ 目录检查完成${NC}"

  

# 验证配置

echo -e "${YELLOW}🔍 验证配置...${NC}"

  

# 检查缓存状态

if ! php bin/magento cache:status 2>/dev/null; then
    echo -e "${YELLOW}⚠ 无法获取缓存状态${NC}"
fi

  

# 检查Redis数据库使用情况

echo -e "${YELLOW}📊 Redis数据库使用情况:${NC}"

if ! redis-cli info keyspace 2>/dev/null | grep -E "db($CACHE_DB|$PAGE_DB|$SESSION_DB):"; then
    echo -e "${YELLOW}⚠ 无法获取Redis数据库信息${NC}"
fi

  

# 检查配置结果

echo -e "${YELLOW}🔍 验证配置结果...${NC}"

  

# 检查默认缓存配置

if grep -q "'database' => '$CACHE_DB'" app/etc/env.php; then

echo -e "${GREEN}✅ 默认缓存配置正确: DB $CACHE_DB${NC}"

else

echo -e "${RED}❌ 默认缓存配置失败${NC}"

fi

  

# 检查页面缓存配置

if grep -q "'database' => '$PAGE_DB'" app/etc/env.php; then

echo -e "${GREEN}✅ 页面缓存配置正确: DB $PAGE_DB${NC}"

else

echo -e "${RED}❌ 页面缓存配置失败${NC}"

fi

  

# 检查会话存储配置

if grep -q "'database' => '$SESSION_DB'" app/etc/env.php; then

echo -e "${GREEN}✅ 会话存储配置正确: DB $SESSION_DB${NC}"

else

echo -e "${RED}❌ 会话存储配置失败${NC}"

fi

  

echo ""

echo -e "${BLUE}🎉 站点 $SITE_NAME 的Valkey更新完成！${NC}"

  

echo -e "${BLUE}🔒 隔离信息:${NC}"

echo -e " 站点名称: $SITE_NAME"

echo -e " 站点路径: $SITE_PATH"

echo -e " 缓存前缀: ${SITE_NAME}_cache_, ${SITE_NAME}_session_"

echo -e " 使用数据库: $CACHE_DB, $PAGE_DB, $SESSION_DB"

  

# 禁用维护模式
echo -e "${YELLOW}🔓 禁用维护模式...${NC}"
if ! php bin/magento maintenance:disable 2>/dev/null; then
    echo -e "${YELLOW}⚠ 维护模式禁用失败，请手动检查${NC}"
else
    echo -e "${GREEN}✅ 维护模式已禁用${NC}"
    unset MAINTENANCE_ENABLED
fi

echo ""

echo -e "${YELLOW}💡 建议运行以下命令进行最终检查:${NC}"

echo " php bin/magento cache:status"

echo " php bin/magento setup:upgrade"

echo " php bin/magento indexer:reindex"

  

echo -e "${BLUE}📋 其他站点更新命令:${NC}"

echo " ./valkey_renew.sh sava 11 12 13"
echo " ./valkey_renew.sh bdgy 20 21 22"
echo " ./valkey_renew.sh ntca 30 31 32"
echo " ./valkey_renew.sh ipwa 40 41 42"
echo " ./valkey_renew.sh hawk 50 51 52"
echo " ./valkey_renew.sh ambi 60 61 62"
echo " ./valkey_renew.sh papa 70 71 72"


  

echo -e "${YELLOW}💡 提示: 可以在任何目录运行此脚本，支持任意路径结构${NC}"