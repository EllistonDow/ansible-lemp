#!/bin/bash

#####################################################################
# Codazon Infinit Theme Uninstaller
# 
# Description: 完全卸载和清空 Codazon Infinit 主题及相关文件
# Author: DogeTools
# Version: 1.2.0
# Date: 2025-10-02
# Features: 支持两种数据库清理方式（Magento命令 + 直接数据库）
# Fix: 修复 env.php 配置读取 + 模块记录清理 + EAV 属性引用清理 + CMS 内容清理
#####################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项] <Magento根目录>

选项:
    -h, --help          显示此帮助信息
    -d, --dry-run       演练模式，只显示将要删除的文件，不实际删除
    -y, --yes           跳过确认提示，自动确认
    -b, --backup        在删除前备份主题文件
    --db-only           仅清理数据库配置，不删除文件
    --files-only        仅删除文件，不清理数据库
    --direct-db         使用直接数据库清理（更彻底，需要 mysql 客户端）
    --show-db           显示数据库配置信息（从 env.php 读取）

示例:
    $0 /var/www/magento2                    # 交互式卸载
    $0 -y /var/www/magento2                 # 自动确认卸载
    $0 -d /var/www/magento2                 # 演练模式
    $0 -b /var/www/magento2                 # 备份后卸载
    $0 --db-only /var/www/magento2          # 仅清理数据库
    $0 --files-only /var/www/magento2       # 仅删除文件
    $0 --direct-db /var/www/magento2        # 直接数据库深度清理
    $0 --show-db /var/www/magento2          # 显示数据库配置

EOF
    exit 0
}

# 参数解析
DRY_RUN=0
AUTO_YES=0
BACKUP=0
DB_ONLY=0
FILES_ONLY=0
DIRECT_DB=0
SHOW_DB=0
MAGENTO_ROOT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -d|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        -b|--backup)
            BACKUP=1
            shift
            ;;
        --db-only)
            DB_ONLY=1
            shift
            ;;
        --files-only)
            FILES_ONLY=1
            shift
            ;;
        --direct-db)
            DIRECT_DB=1
            shift
            ;;
        --show-db)
            SHOW_DB=1
            shift
            ;;
        *)
            MAGENTO_ROOT="$1"
            shift
            ;;
    esac
done

# 检查 Magento 根目录
if [ -z "$MAGENTO_ROOT" ]; then
    log_error "请指定 Magento 根目录"
    echo "使用 -h 或 --help 查看帮助信息"
    exit 1
fi

if [ ! -d "$MAGENTO_ROOT" ]; then
    log_error "目录不存在: $MAGENTO_ROOT"
    exit 1
fi

if [ ! -f "$MAGENTO_ROOT/bin/magento" ]; then
    log_error "这不是一个有效的 Magento 根目录: $MAGENTO_ROOT"
    exit 1
fi

# 切换到 Magento 根目录
cd "$MAGENTO_ROOT"
log_info "Magento 根目录: $(pwd)"

# 定义要删除的路径
THEME_PATHS=(
    "app/design/frontend/Codazon"
    "app/code/Codazon"
    "pub/static/frontend/Codazon"
    "var/view_preprocessed/pub/static/frontend/Codazon"
    "var/cache"
    "generated/code/Codazon"
    "generated/metadata/Codazon"
)

# 显示将要删除的路径
show_paths() {
    log_info "将要删除以下路径:"
    echo ""
    local found=0
    for path in "${THEME_PATHS[@]}"; do
        if [ -e "$path" ]; then
            if [ "$path" == "var/cache" ]; then
                echo "  📂 $path (缓存目录)"
            else
                echo "  📂 $path"
            fi
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        log_warning "没有找到 Codazon 主题文件"
    fi
    echo ""
}

# 备份函数
backup_theme() {
    log_info "开始备份 Codazon 主题..."
    
    BACKUP_DIR="backup/codazon-theme-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    for path in "${THEME_PATHS[@]}"; do
        if [ -e "$path" ] && [ "$path" != "var/cache" ]; then
            log_info "备份: $path"
            parent_dir=$(dirname "$path")
            mkdir -p "$BACKUP_DIR/$parent_dir"
            cp -r "$path" "$BACKUP_DIR/$parent_dir/"
        fi
    done
    
    log_success "备份完成: $BACKUP_DIR"
}

# 删除文件
remove_files() {
    log_info "开始删除 Codazon 主题文件..."
    
    for path in "${THEME_PATHS[@]}"; do
        if [ -e "$path" ]; then
            if [ $DRY_RUN -eq 1 ]; then
                log_info "[演练] 将删除: $path"
            else
                log_info "删除: $path"
                rm -rf "$path"
                log_success "已删除: $path"
            fi
        fi
    done
}

# 从 env.php 读取数据库配置
get_db_config() {
    if [ ! -f "app/etc/env.php" ]; then
        log_error "找不到 app/etc/env.php"
        return 1
    fi
    
    # 使用 PHP 读取数据库配置
    DB_HOST=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['connection']['default']['host'] ?? 'localhost';")
    DB_NAME=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['connection']['default']['dbname'] ?? '';")
    DB_USER=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['connection']['default']['username'] ?? '';")
    DB_PASS=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['connection']['default']['password'] ?? '';")
    DB_PREFIX=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['table_prefix'] ?? '';")
    
    if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
        log_error "无法从 env.php 读取数据库配置"
        return 1
    fi
    
    return 0
}

# 显示数据库配置
show_db_config() {
    log_info "数据库配置信息:"
    echo "  Host: $DB_HOST"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Password: ${DB_PASS:0:3}***"
    if [ -n "$DB_PREFIX" ]; then
        echo "  Table Prefix: $DB_PREFIX"
    fi
}

# 直接清理数据库中的主题数据
clean_database_direct() {
    log_info "使用直接数据库清理模式..."
    
    # 读取数据库配置
    if ! get_db_config; then
        log_error "无法获取数据库配置"
        return 1
    fi
    
    show_db_config
    echo ""
    
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[演练] 将执行以下 SQL 操作:"
        echo "  - 删除 ${DB_PREFIX}theme 表中 Codazon 相关记录"
        echo "  - 删除 ${DB_PREFIX}setup_module 表中 Codazon 模块记录"
        echo "  - 清空 ${DB_PREFIX}eav_attribute 中的 Codazon 模型引用"
        echo "  - 删除 ${DB_PREFIX}core_config_data 中主题配置"
        echo "  - 清理 ${DB_PREFIX}design_config_grid_flat 中的记录"
        echo "  - 删除 ${DB_PREFIX}cms_block 中的 Codazon 块"
        echo "  - 删除 ${DB_PREFIX}cms_page 中的 Codazon 页面"
        return 0
    fi
    
    # 构建 SQL 命令
    local SQL_CLEAN="
        -- 删除主题记录
        DELETE FROM ${DB_PREFIX}theme WHERE theme_path LIKE 'Codazon/%';
        
        -- 删除模块记录（关键！）
        DELETE FROM ${DB_PREFIX}setup_module WHERE module LIKE 'Codazon_%';
        
        -- 清空属性中的 Codazon backend_model 引用（避免索引错误）
        UPDATE ${DB_PREFIX}eav_attribute SET backend_model = NULL WHERE backend_model LIKE '%Codazon%';
        UPDATE ${DB_PREFIX}eav_attribute SET frontend_model = NULL WHERE frontend_model LIKE '%Codazon%';
        UPDATE ${DB_PREFIX}eav_attribute SET source_model = NULL WHERE source_model LIKE '%Codazon%';
        
        -- 删除主题配置
        DELETE FROM ${DB_PREFIX}core_config_data WHERE path LIKE '%codazon%';
        DELETE FROM ${DB_PREFIX}core_config_data WHERE path LIKE '%infinit%';
        
        -- 清理设计配置
        DELETE FROM ${DB_PREFIX}design_config_grid_flat WHERE theme_theme_id IN (
            SELECT theme_id FROM ${DB_PREFIX}theme WHERE theme_path LIKE 'Codazon/%'
        );
        
        -- 设置为默认主题（Luma, ID=2）
        UPDATE ${DB_PREFIX}core_config_data SET value='2' WHERE path='design/theme/theme_id';
        
        -- 清理 CMS 内容中的 Codazon 引用（第4层清理）
        DELETE FROM ${DB_PREFIX}cms_block WHERE content LIKE '%Codazon%';
        DELETE FROM ${DB_PREFIX}cms_page WHERE content LIKE '%Codazon%';
        
        SELECT 'Database cleanup completed' AS status;
    "
    
    log_info "执行数据库清理..."
    
    if [ -n "$DB_PASS" ]; then
        echo "$SQL_CLEAN" | mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" 2>/dev/null
    else
        echo "$SQL_CLEAN" | mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        log_success "数据库直接清理完成"
    else
        log_error "数据库清理失败，尝试使用 Magento 命令..."
        return 1
    fi
}

# 清理数据库配置（通过 Magento 命令）
clean_database() {
    log_info "开始清理数据库中的主题配置..."
    
    # 检查是否有 bin/magento 命令
    if [ ! -f "bin/magento" ]; then
        log_error "找不到 bin/magento 命令"
        return 1
    fi
    
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[演练] 将执行以下命令:"
        echo "  - php bin/magento theme:uninstall Codazon/InfinitPro"
        echo "  - php bin/magento config:set design/theme/theme_id 2"
        echo "  - php bin/magento app:config:import"
    else
        # 尝试卸载主题（可能会失败，不影响后续操作）
        log_info "卸载主题..."
        php bin/magento theme:uninstall Codazon/InfinitPro -c 2>/dev/null || log_warning "主题卸载命令失败（可能主题未在数据库中注册）"
        
        # 设置默认主题（Luma theme ID = 2）
        log_info "设置为默认 Luma 主题..."
        php bin/magento config:set design/theme/theme_id 2
        
        # 清理配置
        log_info "清理配置..."
        php bin/magento setup:upgrade
        php bin/magento app:config:import
        
        log_success "数据库配置清理完成"
    fi
}

# 清理缓存
clean_cache() {
    log_info "清理缓存..."
    
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[演练] 将清理所有缓存"
    else
        php bin/magento cache:clean
        php bin/magento cache:flush
        log_success "缓存清理完成"
    fi
}

# 重新编译
recompile() {
    log_info "重新编译和部署..."
    
    if [ $DRY_RUN -eq 1 ]; then
        log_info "[演练] 将执行重新编译"
    else
        php bin/magento setup:di:compile
        php bin/magento setup:static-content:deploy -f
        log_success "重新编译完成"
    fi
}

# 显示统计信息
show_statistics() {
    log_info "统计信息:"
    echo ""
    
    local total_size=0
    for path in "${THEME_PATHS[@]}"; do
        if [ -e "$path" ]; then
            size=$(du -sh "$path" 2>/dev/null | cut -f1)
            echo "  $path: $size"
        fi
    done
    echo ""
}

# 主函数
main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         Codazon Infinit Theme Uninstaller v1.2.0          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 如果只是显示数据库配置
    if [ $SHOW_DB -eq 1 ]; then
        log_info "读取数据库配置..."
        if get_db_config; then
            echo ""
            show_db_config
            echo ""
            log_success "数据库配置读取完成"
        else
            log_error "无法读取数据库配置"
            exit 1
        fi
        exit 0
    fi
    
    # 显示模式
    if [ $DRY_RUN -eq 1 ]; then
        log_warning "运行模式: 演练模式（不会实际删除文件）"
    fi
    
    if [ $BACKUP -eq 1 ]; then
        log_info "备份模式: 启用"
    fi
    
    if [ $DIRECT_DB -eq 1 ]; then
        log_info "数据库模式: 直接清理（需要 mysql 客户端）"
    fi
    
    echo ""
    
    # 显示将要删除的路径
    show_paths
    
    # 显示统计信息
    show_statistics
    
    # 确认提示
    if [ $AUTO_YES -eq 0 ] && [ $DRY_RUN -eq 0 ]; then
        echo ""
        log_warning "此操作将永久删除 Codazon Infinit 主题及相关文件！"
        read -p "确认继续吗？(yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    echo ""
    
    # 备份（如果启用）
    if [ $BACKUP -eq 1 ] && [ $DRY_RUN -eq 0 ]; then
        backup_theme
        echo ""
    fi
    
    # 执行清理
    if [ $DB_ONLY -eq 0 ]; then
        remove_files
        echo ""
    fi
    
    if [ $FILES_ONLY -eq 0 ]; then
        # 选择数据库清理方式
        if [ $DIRECT_DB -eq 1 ]; then
            clean_database_direct || clean_database
        else
            clean_database
        fi
        echo ""
        clean_cache
        echo ""
        
        if [ $DRY_RUN -eq 0 ]; then
            log_info "是否需要重新编译？(推荐)"
            read -p "重新编译？(y/n): " recompile_choice
            
            if [ "$recompile_choice" == "y" ] || [ "$recompile_choice" == "Y" ]; then
                recompile
            fi
        fi
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    if [ $DRY_RUN -eq 1 ]; then
        echo "║            演练模式完成 - 未做任何更改                      ║"
    else
        echo "║       Codazon Infinit 主题卸载完成！                      ║"
    fi
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ $DRY_RUN -eq 0 ]; then
        log_success "所有操作已完成"
        log_info "建议重启 PHP-FPM 和 Nginx 服务"
        echo ""
        echo "运行以下命令重启服务:"
        echo "  sudo systemctl restart php8.3-fpm"
        echo "  sudo systemctl restart nginx"
    fi
}

# 运行主函数
main

