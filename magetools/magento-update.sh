#!/bin/bash

# Magento 2 完整更新脚本
# 包含维护模式管理的完整更新流程
# 作者: Ansible LEMP Project
# 版本: 1.0.0

set -e

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

# 检查是否在 Magento 2 目录中
check_magento_dir() {
    if [[ ! -f "bin/magento" ]]; then
        log_error "请在 Magento 2 项目根目录中运行此脚本"
        exit 1
    fi
    log_success "检测到 Magento 2 项目"
}

# 检查 n98-magerun2 是否可用
check_n98() {
    if ! command -v n98-magerun2 &> /dev/null; then
        log_error "n98-magerun2 未安装或不在 PATH 中"
        log_info "请先安装: ./magetools/n98-magerun2.sh install"
        exit 1
    fi
    log_success "n98-magerun2 可用"
}

# 检查当前模式
check_mode() {
    MODE=$(php bin/magento deploy:mode:show | grep "Application mode" | awk '{print $3}')
    log_info "当前模式: $MODE"
    
    if [[ "$MODE" == "production" ]]; then
        log_warning "生产模式检测到，将跳过 dev:asset:clear"
        SKIP_ASSET_CLEAR="--skip-dev-asset-clear"
    else
        log_info "开发模式，将执行完整更新"
        SKIP_ASSET_CLEAR=""
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Magento 2 完整更新脚本

用法:
    $0 [选项]

选项:
    --with-maintenance    启用维护模式（默认）
    --no-maintenance      不启用维护模式
    --skip-asset-clear    跳过静态资源清理
    --help               显示此帮助信息

示例:
    $0                    # 标准更新（启用维护模式）
    $0 --no-maintenance   # 不启用维护模式
    $0 --skip-asset-clear # 跳过静态资源清理

说明:
    - 自动检测 Magento 2 项目目录
    - 自动检测当前运行模式
    - 智能处理维护模式
    - 使用 n98-magerun2 dev:keep-calm 进行更新

EOF
}

# 主更新函数
magento_update() {
    log_info "开始 Magento 2 更新流程..."
    
    # 检查环境
    check_magento_dir
    check_n98
    check_mode
    
    # 启用维护模式（如果指定）
    if [[ "$ENABLE_MAINTENANCE" == "true" ]]; then
        log_info "启用维护模式..."
        n98-magerun2 sys:maintenance --on
        log_success "维护模式已启用"
    fi
    
    # 执行更新
    log_info "执行 n98-magerun2 dev:keep-calm..."
    if n98-magerun2 dev:keep-calm $SKIP_ASSET_CLEAR; then
        log_success "更新完成！"
    else
        log_error "更新过程中出现错误"
        if [[ "$ENABLE_MAINTENANCE" == "true" ]]; then
            log_warning "更新失败，但维护模式仍处于启用状态"
            log_info "请手动禁用维护模式: n98-magerun2 sys:maintenance --off"
        fi
        exit 1
    fi
    
    # 显示完成信息
    log_success "🎉 Magento 2 更新完成！"
    log_info "所有服务已恢复正常运行"
}

# 解析命令行参数
ENABLE_MAINTENANCE="true"
SKIP_ASSET_CLEAR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-maintenance)
            ENABLE_MAINTENANCE="true"
            shift
            ;;
        --no-maintenance)
            ENABLE_MAINTENANCE="false"
            shift
            ;;
        --skip-asset-clear)
            SKIP_ASSET_CLEAR="--skip-dev-asset-clear"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
magento_update
