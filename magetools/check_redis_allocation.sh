#!/bin/bash

# Redis数据库分配查看脚本

# 用于查看Magento多站点的Redis数据库分配情况

# 用法: ./check_redis_allocation.sh [站点名|all]

  

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

BLUE='\033[0;34m'

NC='\033[0m' # No Color

  

# 显示帮助信息

show_help() {

echo -e "${BLUE}🔍 Magento多站点Redis数据库分配查看脚本${NC}"

echo "================================================"

echo ""

echo -e "${YELLOW}用法:${NC}"

echo " $0 [选项] [站点名]"

echo ""

echo -e "${YELLOW}选项:${NC}"

echo " all 查看所有站点"

echo " <站点名> 查看指定站点"

echo " --help 显示此帮助信息"

echo ""

echo -e "${YELLOW}示例:${NC}"

echo " $0 all # 查看所有站点"

echo " $0 ntca # 查看ntca站点"

echo " $0 sava # 查看sava站点"

echo " $0 bdgy # 查看bdgy站点"

echo ""

echo -e "${YELLOW}环境变量:${NC}"

echo " MAGENTO_BASE_PATH Magento站点基础路径 (默认: /home/doge)"

echo " REDIS_HOST Redis主机 (默认: 127.0.0.1)"

echo " REDIS_PORT Redis端口 (默认: 6379)"

echo ""

echo -e "${YELLOW}配置文件:${NC}"

echo " 支持 valkey_sites.conf 配置文件"

echo " 格式: 站点名=路径"

echo ""

}

  

# 检查参数

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then

show_help

exit 0

fi

  

# 设置默认值

MAGENTO_BASE_PATH=${MAGENTO_BASE_PATH:-"/home/doge"}

REDIS_HOST=${REDIS_HOST:-"127.0.0.1"}

REDIS_PORT=${REDIS_PORT:-"6379"}

  

# 检查Redis连接
if ! redis-cli -h $REDIS_HOST -p $REDIS_PORT ping >/dev/null 2>&1; then
    echo -e "${RED}❌ 无法连接到Redis服务器 ($REDIS_HOST:$REDIS_PORT)${NC}"
    echo -e "${YELLOW}💡 请检查:${NC}"
    echo "  - Redis服务是否运行: systemctl status redis"
    echo "  - 端口是否正确: netstat -tlnp | grep $REDIS_PORT"
    echo "  - 防火墙设置: ufw status"
    exit 1
fi

  

echo -e "${BLUE}🔍 Magento多站点Redis数据库分配查看${NC}"

echo "================================================"

echo -e "${YELLOW}Redis服务器:${NC} $REDIS_HOST:$REDIS_PORT"

echo -e "${YELLOW}基础路径:${NC} $MAGENTO_BASE_PATH"

  

# 获取站点路径

get_site_path() {

local site_name=$1

local site_path=""

# 1. 检查配置文件

if [ -f "valkey_sites.conf" ]; then

site_path=$(grep "^$site_name=" valkey_sites.conf | cut -d'=' -f2)

fi

# 2. 检查默认路径

if [ -z "$site_path" ] && [ -d "$MAGENTO_BASE_PATH/$site_name" ]; then

site_path="$MAGENTO_BASE_PATH/$site_name"

fi

# 3. 检查当前目录

if [ -z "$site_path" ] && [ -d "./$site_name" ]; then

site_path="./$site_name"

fi

echo "$site_path"

}

  

# 检查单个站点

check_site() {

local site_name=$1

local site_path=$(get_site_path $site_name)

if [ -z "$site_path" ]; then

echo -e "${RED}❌ 未找到站点: $site_name${NC}"

echo -e "${YELLOW}💡 提示: 检查站点路径或创建配置文件${NC}"

return 1

fi

if [ ! -d "$site_path" ]; then

echo -e "${RED}❌ 站点目录不存在: $site_path${NC}"

return 1

fi

echo -e "\n${GREEN}📁 $site_name站点 ($site_path):${NC}"

if [ -f "$site_path/app/etc/env.php" ]; then

cd "$site_path"

# 获取缓存配置 - 使用更精确的方法

cache_db=$(grep -A 20 "'default' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

page_db=$(grep -A 20 "'page_cache' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

session_db=$(grep -A 20 "'session' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

cache_prefix=$(grep -A 20 "'default' => \[" app/etc/env.php | grep "id_prefix" | head -1 | sed "s/.*'id_prefix' => '\([^']*\)'.*/\1/")

page_prefix=$(grep -A 20 "'page_cache' => \[" app/etc/env.php | grep "id_prefix" | head -1 | sed "s/.*'id_prefix' => '\([^']*\)'.*/\1/")

session_prefix=$(grep -A 20 "'session' => \[" app/etc/env.php | grep "id_prefix" | head -1 | sed "s/.*'id_prefix' => '\([^']*\)'.*/\1/")

# 显示配置信息

echo -e " 默认缓存: DB $cache_db (前缀: $cache_prefix)"

echo -e " 页面缓存: DB $page_db (前缀: $cache_prefix)"

if [ -n "$session_db" ]; then

echo -e " 会话存储: DB $session_db (前缀: $session_prefix)"

fi

# 检查Redis中的实际数据

if [ -n "$cache_db" ] && [ "$cache_db" != "" ]; then
    cache_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $cache_db dbsize 2>/dev/null || echo "0")
    cache_expires=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $cache_db info keyspace 2>/dev/null | grep "db$cache_db:" | cut -d, -f2 | sed 's/expires=//' || echo "0")
    echo -e " 默认缓存键数: $cache_keys (过期: $cache_expires)"
fi

if [ -n "$page_db" ] && [ "$page_db" != "" ]; then
    page_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $page_db dbsize 2>/dev/null || echo "0")
    page_expires=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $page_db info keyspace 2>/dev/null | grep "db$page_db:" | cut -d, -f2 | sed 's/expires=//' || echo "0")
    echo -e " 页面缓存键数: $page_keys (过期: $page_expires)"
fi

if [ -n "$session_db" ] && [ "$session_db" != "" ]; then
    session_keys=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $session_db dbsize 2>/dev/null || echo "0")
    session_expires=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT -n $session_db info keyspace 2>/dev/null | grep "db$session_db:" | cut -d, -f2 | sed 's/expires=//' || echo "0")
    echo -e " 会话存储键数: $session_keys (过期: $session_expires)"
fi

# 检查Magento状态

if [ -f "bin/magento" ]; then

echo -e " Magento版本: $(php bin/magento --version 2>/dev/null | head -1 || echo '未知')"

fi

else

echo -e " ${RED}❌ 未找到env.php文件${NC}"

fi

}

  

# 1. 查看Redis数据库使用情况

echo -e "\n${YELLOW}📊 Redis数据库使用情况:${NC}"

redis-cli -h $REDIS_HOST -p $REDIS_PORT info keyspace | grep -E "db[0-9]+" | while read line; do

db_num=$(echo $line | cut -d: -f1 | sed 's/db//')

keys=$(echo $line | cut -d: -f2 | cut -d, -f1 | sed 's/keys=//')

expires=$(echo $line | cut -d: -f2 | cut -d, -f2 | sed 's/expires=//')

if [ "$keys" -gt 0 ]; then

echo -e " DB $db_num: $keys 个键, $expires 个过期"

fi

done

  

# 主逻辑

if [ "$1" = "all" ] || [ -z "$1" ]; then

echo -e "\n${YELLOW}🏢 各站点配置详情:${NC}"

# 获取所有站点

sites=()

# 从配置文件获取站点列表

if [ -f "valkey_sites.conf" ]; then

while IFS='=' read -r site_name site_path; do

# 跳过注释行和空行

if [[ ! "$site_name" =~ ^[[:space:]]*# ]] && [ -n "$site_name" ] && [ -n "$site_path" ]; then

sites+=("$site_name")

fi

done < valkey_sites.conf

fi

# 从默认路径获取站点列表

if [ -d "$MAGENTO_BASE_PATH" ]; then

for dir in "$MAGENTO_BASE_PATH"/*; do

if [ -d "$dir" ] && [ -f "$dir/app/etc/env.php" ]; then

site_name=$(basename "$dir")

if [[ ! " ${sites[@]} " =~ " ${site_name} " ]]; then

sites+=("$site_name")

fi

fi

done

fi

# 检查所有站点

if [ ${#sites[@]} -eq 0 ]; then

echo -e "${YELLOW}⚠️ 未找到任何Magento站点${NC}"

echo -e "${YELLOW}💡 提示: 检查路径或创建配置文件${NC}"

else

for site in "${sites[@]}"; do

check_site "$site"

done

fi

elif [ -n "$1" ]; then

# 检查指定站点

check_site "$1"

else

show_help

fi

  

# 显示总结

if [ "$1" = "all" ] || [ -z "$1" ]; then

echo -e "\n${BLUE}📋 数据库分配总结:${NC}"

echo "================================================"

echo -e "${YELLOW}📊 各站点数据库使用情况:${NC}"

echo ""

echo -e "${GREEN}站点名称${NC} ${GREEN}默认缓存${NC} ${GREEN}页面缓存${NC} ${GREEN}会话存储${NC} ${GREEN}状态${NC}"

echo "------------------------------------------------"

# 重新收集所有站点的数据库信息

for site in "${sites[@]}"; do

site_path=$(get_site_path $site)

if [ -f "$site_path/app/etc/env.php" ]; then

cd "$site_path"

cache_db=$(grep -A 20 "'default' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

page_db=$(grep -A 20 "'page_cache' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

session_db=$(grep -A 20 "'session' => \[" app/etc/env.php | grep "database" | head -1 | sed "s/.*'database' => '\([0-9]*\)'.*/\1/")

# 格式化显示

printf "%-12s %-12s %-12s %-12s" "$site" "DB $cache_db" "DB $page_db" "DB $session_db"

echo -e " ${GREEN}✅${NC}"

fi

done

echo ""

echo -e "${YELLOW}💡 提示:${NC}"

echo " - 每个站点使用独立的Redis数据库，避免数据冲突"

echo " - 使用不同的缓存前缀，进一步隔离数据"

echo " - 可以通过 'redis-cli -n <db_number> keys *' 查看具体键"

echo " - 可以通过 'redis-cli -n <db_number> flushdb' 清空特定数据库"

echo ""

echo -e "${YELLOW}🔧 环境变量:${NC}"

echo " MAGENTO_BASE_PATH=$MAGENTO_BASE_PATH"

echo " REDIS_HOST=$REDIS_HOST"

echo " REDIS_PORT=$REDIS_PORT"

fi