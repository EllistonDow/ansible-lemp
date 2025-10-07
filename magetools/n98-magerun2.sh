#!/bin/bash

# n98-magerun2 Composer 安装和卸载脚本
# 用于管理 n98-magerun2 工具的安装和卸载（使用 Composer）
# 作者: Ansible LEMP Project
# 版本: 2.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
N98_PACKAGE="n98/magerun2"
N98_BINARY_NAME="n98-magerun2"
N98_CONFIG_DIR="$HOME/.composer/vendor/n98/magerun2"
N98_CACHE_DIR="$HOME/.cache/n98-magerun2"

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

# 检查并配置 PATH
configure_path() {
    COMPOSER_BIN_DIR=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
    
    if [[ ":$PATH:" != *":$COMPOSER_BIN_DIR:"* ]]; then
        log_warning "Composer 全局 bin 目录不在 PATH 中: $COMPOSER_BIN_DIR"
        
        # 检测用户的 shell
        SHELL_NAME=$(basename "$SHELL")
        CONFIG_FILE=""
        
        case "$SHELL_NAME" in
            bash)
                CONFIG_FILE="$HOME/.bashrc"
                ;;
            zsh)
                CONFIG_FILE="$HOME/.zshrc"
                ;;
            fish)
                CONFIG_FILE="$HOME/.config/fish/config.fish"
                ;;
            *)
                log_warning "未识别的 shell: $SHELL_NAME，请手动配置 PATH"
                return 1
                ;;
        esac
        
        if [[ -n "$CONFIG_FILE" ]]; then
            log_info "检测到 shell: $SHELL_NAME"
            log_info "配置文件: $CONFIG_FILE"
            
            # 检查是否已经配置过
            if grep -q "composer.*bin.*PATH" "$CONFIG_FILE" 2>/dev/null; then
                log_info "PATH 配置已存在，但可能未生效"
            else
                log_info "自动添加 PATH 配置到 $CONFIG_FILE"
                
                # 添加 PATH 配置
                echo "" >> "$CONFIG_FILE"
                echo "# Composer global bin directory" >> "$CONFIG_FILE"
                echo "export PATH=\"\$PATH:$COMPOSER_BIN_DIR\"" >> "$CONFIG_FILE"
                
                log_success "PATH 配置已添加到 $CONFIG_FILE"
            fi
            
            # 提供重新加载选项
            log_info "请选择以下操作之一:"
            echo "  1) 自动重新加载配置 (推荐)"
            echo "  2) 手动重新加载"
            echo "  3) 跳过"
            
            read -p "请选择 (1-3): " -n 1 -r
            echo
            
            case $REPLY in
                1)
                    log_info "自动重新加载 shell 配置..."
                    if [[ "$SHELL_NAME" == "bash" ]]; then
                        # 尝试多种方式重新加载
                        if source "$CONFIG_FILE" 2>/dev/null; then
                            log_success "Shell 配置已重新加载"
                        elif exec bash -l; then
                            log_success "已启动新的 bash 会话"
                        else
                            log_warning "无法自动重新加载，请手动运行: source ~/.bashrc"
                        fi
                    elif [[ "$SHELL_NAME" == "zsh" ]]; then
                        if source "$CONFIG_FILE" 2>/dev/null; then
                            log_success "Shell 配置已重新加载"
                        elif exec zsh -l; then
                            log_success "已启动新的 zsh 会话"
                        else
                            log_warning "无法自动重新加载，请手动运行: source ~/.zshrc"
                        fi
                    fi
                    
                    # 验证 PATH 是否生效
                    if command -v n98-magerun2 &> /dev/null; then
                        log_success "n98-magerun2 现在可以在任何目录下使用！"
                        log_info "测试命令: n98-magerun2 --version"
                    else
                        log_warning "PATH 可能还未生效，请重新打开终端或运行: source $CONFIG_FILE"
                    fi
                    ;;
                2)
                    log_info "请手动运行以下命令重新加载配置:"
                    echo "  source $CONFIG_FILE"
                    ;;
                3)
                    log_info "跳过重新加载，请稍后手动重新加载配置"
                    ;;
                *)
                    log_info "无效选择，请稍后手动重新加载配置"
                    ;;
            esac
        fi
    else
        log_success "PATH 配置正确"
    fi
}

# 自动重新加载配置
auto_reload_config() {
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        bash)
            if source ~/.bashrc 2>/dev/null; then
                log_success "Bash 配置已重新加载"
                return 0
            fi
            ;;
        zsh)
            if source ~/.zshrc 2>/dev/null; then
                log_success "Zsh 配置已重新加载"
                return 0
            fi
            ;;
    esac
    return 1
}

# 检查 Composer 是否安装
check_composer() {
    if ! command -v composer &> /dev/null; then
        log_error "Composer 未安装，请先安装 Composer"
        log_info "安装方法: curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
        exit 1
    fi
    
    log_success "Composer 已安装"
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查 Composer
    check_composer
    
    # 检查 PHP
    if ! command -v php &> /dev/null; then
        log_error "PHP 未安装，请先安装 PHP"
        exit 1
    fi
    
    # 检查 PHP 版本
    PHP_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
    if (( $(echo "$PHP_VERSION < 7.4" | bc -l) )); then
        log_warning "PHP 版本 $PHP_VERSION 可能不兼容，建议使用 PHP 7.4 或更高版本"
    fi
    
    log_success "系统要求检查通过"
}

# 获取 n98-magerun2 的安装路径
get_n98_path() {
    COMPOSER_BIN_DIR=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
    echo "$COMPOSER_BIN_DIR/$N98_BINARY_NAME"
}

# 检查 n98-magerun2 是否已安装
is_n98_installed() {
    N98_PATH=$(get_n98_path)
    [[ -f "$N98_PATH" && -x "$N98_PATH" ]]
}

# 安装 n98-magerun2
install_n98() {
    log_info "开始安装 n98-magerun2..."
    
    # 检查是否已安装
    if is_n98_installed; then
        log_warning "n98-magerun2 已安装"
        read -p "是否要重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
        # 先卸载旧版本
        uninstall_n98_silent
    fi
    
    # 使用 Composer 全局安装
    log_info "使用 Composer 全局安装 n98-magerun2..."
    if composer global require "$N98_PACKAGE" --no-interaction; then
        log_success "n98-magerun2 安装成功"
        
        # 验证安装
        if is_n98_installed; then
            N98_PATH=$(get_n98_path)
            log_info "安装路径: $N98_PATH"
            
            # 显示版本信息
            log_info "版本信息:"
            "$N98_PATH" --version
            
            # 显示使用说明
            log_info "使用说明:"
            echo "  - 查看帮助: $N98_BINARY_NAME --help"
            echo "  - 查看命令列表: $N98_BINARY_NAME list"
            echo "  - 在 Magento 项目目录中运行命令"
            
            # 自动配置 PATH
            log_info "检查并配置 PATH..."
            configure_path
            
            # 尝试自动重新加载配置
            if auto_reload_config; then
                if command -v n98-magerun2 &> /dev/null; then
                    log_success "n98-magerun2 现在可以在任何目录下使用！"
                    log_info "测试命令: n98-magerun2 --version"
                fi
            else
                log_info "请重新打开终端或运行: source ~/.bashrc"
            fi
        else
            log_error "安装验证失败"
            exit 1
        fi
    else
        log_error "安装失败"
        exit 1
    fi
}

# 静默卸载（用于重新安装时）
uninstall_n98_silent() {
    if composer global remove "$N98_PACKAGE" --no-interaction 2>/dev/null; then
        log_info "已卸载旧版本"
    fi
}

# 卸载 n98-magerun2
uninstall_n98() {
    log_info "开始卸载 n98-magerun2..."
    
    # 检查是否已安装
    if ! is_n98_installed; then
        log_warning "n98-magerun2 未安装"
        exit 0
    fi
    
    # 确认卸载
    read -p "确定要卸载 n98-magerun2? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "卸载已取消"
        exit 0
    fi
    
    # 使用 Composer 全局卸载
    log_info "使用 Composer 全局卸载 n98-magerun2..."
    if composer global remove "$N98_PACKAGE" --no-interaction; then
        log_success "n98-magerun2 卸载成功"
        
        # 删除配置目录（可选）
        if [[ -d "$N98_CONFIG_DIR" ]]; then
            read -p "是否删除配置目录 $N98_CONFIG_DIR? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$N98_CONFIG_DIR"
                log_success "已删除配置目录"
            fi
        fi
        
        # 删除缓存目录（可选）
        if [[ -d "$N98_CACHE_DIR" ]]; then
            read -p "是否删除缓存目录 $N98_CACHE_DIR? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$N98_CACHE_DIR"
                log_success "已删除缓存目录"
            fi
        fi
        
    else
        log_error "卸载失败"
        exit 1
    fi
}

# 检查安装状态
check_status() {
    log_info "检查 n98-magerun2 安装状态..."
    
    if is_n98_installed; then
        N98_PATH=$(get_n98_path)
        log_success "n98-magerun2 已安装"
        echo "  安装路径: $N98_PATH"
        echo "  版本信息:"
        "$N98_PATH" --version | sed 's/^/    /'
        
        # 检查 Composer 包信息
        if composer global show "$N98_PACKAGE" &>/dev/null; then
            echo "  Composer 包信息:"
            composer global show "$N98_PACKAGE" | sed 's/^/    /'
        fi
        
        if [[ -d "$N98_CONFIG_DIR" ]]; then
            echo "  配置目录: $N98_CONFIG_DIR"
        fi
        
        if [[ -d "$N98_CACHE_DIR" ]]; then
            echo "  缓存目录: $N98_CACHE_DIR"
        fi
        
        # 检查 PATH 配置
        COMPOSER_BIN_DIR=$(composer global config bin-dir --absolute 2>/dev/null || echo "$HOME/.composer/vendor/bin")
        if [[ ":$PATH:" != *":$COMPOSER_BIN_DIR:"* ]]; then
            log_warning "Composer 全局 bin 目录不在 PATH 中: $COMPOSER_BIN_DIR"
            log_info "运行以下命令自动配置 PATH:"
            echo "  $0 configure-path"
        else
            log_success "PATH 配置正确"
        fi
    else
        log_warning "n98-magerun2 未安装"
        log_info "使用以下命令安装: $0 install"
    fi
}

# 更新 n98-magerun2
update_n98() {
    log_info "更新 n98-magerun2..."
    
    if ! is_n98_installed; then
        log_error "n98-magerun2 未安装，无法更新"
        log_info "请先运行: $0 install"
        exit 1
    fi
    
    # 使用 Composer 全局更新
    log_info "使用 Composer 全局更新 n98-magerun2..."
    if composer global update "$N98_PACKAGE" --no-interaction; then
        log_success "n98-magerun2 更新成功"
        
        # 验证更新
        if is_n98_installed; then
            N98_PATH=$(get_n98_path)
            log_info "更新后的版本信息:"
            "$N98_PATH" --version
        else
            log_error "更新验证失败"
            exit 1
        fi
    else
        log_error "更新失败"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
n98-magerun2 Composer 管理脚本

用法:
    $0 [命令]

命令:
    install         使用 Composer 全局安装 n98-magerun2
    uninstall       使用 Composer 全局卸载 n98-magerun2
    update          使用 Composer 全局更新 n98-magerun2 到最新版本
    status          检查安装状态和配置
    configure-path  自动配置 PATH 环境变量
    help            显示此帮助信息

示例:
    $0 install          # 使用 Composer 安装 n98-magerun2
    $0 status           # 检查安装状态
    $0 update           # 更新到最新版本
    $0 uninstall        # 卸载 n98-magerun2
    $0 configure-path   # 自动配置 PATH

说明:
    - n98-magerun2 是一个强大的 Magento 2 命令行工具
    - 使用 Composer 全局安装，便于版本管理和依赖处理
    - 安装后可以在任何 Magento 2 项目目录中使用
    - 需要 PHP 7.4 或更高版本
    - 需要 Composer 已安装
    - 不需要 root 权限（使用用户级 Composer 全局安装）

安装位置:
    - Composer 全局 bin 目录: ~/.composer/vendor/bin/ (默认)
    - 配置目录: ~/.composer/vendor/n98/magerun2
    - 缓存目录: ~/.cache/n98-magerun2

PATH 配置:
    脚本会自动检测并配置 PATH，无需手动操作
    如需手动配置，运行: $0 configure-path

更多信息:
    https://github.com/netz98/n98-magerun2
    https://packagist.org/packages/n98/magerun2

EOF
}

# 主函数
main() {
    # 检查参数
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        install)
            check_requirements
            install_n98
            ;;
        uninstall)
            uninstall_n98
            ;;
        update)
            check_requirements
            update_n98
            ;;
        status)
            check_status
            ;;
        configure-path)
            configure_path
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
