#!/bin/bash

# 内存监控服务管理脚本
# 用于安装、配置和管理内存监控服务
# 作者: Ansible LEMP Project
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="/opt/memory-monitor"
SCRIPT_PATH="$SCRIPT_DIR/memory-monitor.sh"
SERVICE_NAME="memory-monitor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CRON_FILE="/etc/cron.d/memory-monitor"

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

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0 $@"
        exit 1
    fi
}

# 安装内存监控服务
install_service() {
    log_info "安装内存监控服务..."
    
    # 创建目录
    mkdir -p "$SCRIPT_DIR"
    
    # 复制脚本
    cp "$(dirname "$0")/memory-monitor.sh" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    
    # 创建systemd服务文件
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Memory Monitor Service
After=network.target mysql.service php8.3-fpm.service nginx.service

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_PATH monitor
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

# 环境变量
Environment=MEMORY_THRESHOLD=85
Environment=SWAP_THRESHOLD=30
Environment=CPU_THRESHOLD=80

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$SERVICE_NAME"
    
    log_success "内存监控服务已安装"
    log_info "服务文件: $SERVICE_FILE"
    log_info "脚本路径: $SCRIPT_PATH"
}

# 启动服务
start_service() {
    log_info "启动内存监控服务..."
    
    if systemctl start "$SERVICE_NAME"; then
        log_success "内存监控服务已启动"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 停止服务
stop_service() {
    log_info "停止内存监控服务..."
    
    if systemctl stop "$SERVICE_NAME"; then
        log_success "内存监控服务已停止"
    else
        log_error "服务停止失败"
        exit 1
    fi
}

# 重启服务
restart_service() {
    log_info "重启内存监控服务..."
    
    if systemctl restart "$SERVICE_NAME"; then
        log_success "内存监控服务已重启"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        log_error "服务重启失败"
        exit 1
    fi
}

# 查看服务状态
status_service() {
    log_info "内存监控服务状态:"
    systemctl status "$SERVICE_NAME" --no-pager -l
    
    echo
    log_info "服务日志 (最近20行):"
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager
}

# 卸载服务
uninstall_service() {
    log_warning "卸载内存监控服务..."
    
    # 停止并禁用服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "$SERVICE_FILE"
    
    # 删除脚本目录
    rm -rf "$SCRIPT_DIR"
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "内存监控服务已卸载"
}

# 安装定时任务
install_cron() {
    log_info "安装内存监控定时任务..."
    
    # 创建定时任务文件
    cat > "$CRON_FILE" << EOF
# 内存监控定时任务
# 每5分钟检查一次内存使用率
*/5 * * * * root $SCRIPT_PATH check >/dev/null 2>&1

# 每天凌晨2点执行深度清理
0 2 * * * root $SCRIPT_PATH release >/dev/null 2>&1

# 每周日凌晨3点重启服务
0 3 * * 0 root systemctl restart $SERVICE_NAME >/dev/null 2>&1
EOF
    
    # 设置权限
    chmod 644 "$CRON_FILE"
    
    log_success "定时任务已安装"
    log_info "定时任务文件: $CRON_FILE"
    log_info "每5分钟检查一次内存使用率"
    log_info "每天凌晨2点执行深度清理"
    log_info "每周日凌晨3点重启服务"
}

# 卸载定时任务
uninstall_cron() {
    log_info "卸载定时任务..."
    
    rm -f "$CRON_FILE"
    
    log_success "定时任务已卸载"
}

# 查看日志
view_logs() {
    log_info "内存监控服务日志:"
    
    echo -e "${YELLOW}实时日志 (按Ctrl+C退出):${NC}"
    journalctl -u "$SERVICE_NAME" -f
}

# 配置服务参数
configure_service() {
    log_info "配置内存监控服务参数..."
    
    echo -e "${YELLOW}当前配置:${NC}"
    echo "内存阈值: ${MEMORY_THRESHOLD:-85}%"
    echo "Swap阈值: ${SWAP_THRESHOLD:-30}%"
    echo "CPU阈值: ${CPU_THRESHOLD:-80}%"
    
    echo
    read -p "是否要修改配置? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "内存阈值 (默认85): " new_memory_threshold
        read -p "Swap阈值 (默认30): " new_swap_threshold
        read -p "CPU阈值 (默认80): " new_cpu_threshold
        
        # 更新服务文件
        sed -i "s/Environment=MEMORY_THRESHOLD=.*/Environment=MEMORY_THRESHOLD=${new_memory_threshold:-85}/" "$SERVICE_FILE"
        sed -i "s/Environment=SWAP_THRESHOLD=.*/Environment=SWAP_THRESHOLD=${new_swap_threshold:-30}/" "$SERVICE_FILE"
        sed -i "s/Environment=CPU_THRESHOLD=.*/Environment=CPU_THRESHOLD=${new_cpu_threshold:-80}/" "$SERVICE_FILE"
        
        # 重新加载配置
        systemctl daemon-reload
        
        log_success "配置已更新"
        log_info "重启服务以应用新配置: systemctl restart $SERVICE_NAME"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
内存监控服务管理脚本

用法:
    $0 [命令]

命令:
    install       安装内存监控服务
    uninstall     卸载内存监控服务
    start         启动服务
    stop          停止服务
    restart       重启服务
    status        查看服务状态
    logs          查看服务日志
    cron-install  安装定时任务
    cron-uninstall 卸载定时任务
    configure     配置服务参数
    help          显示此帮助信息

示例:
    $0 install              # 安装服务
    $0 start                # 启动服务
    $0 status               # 查看状态
    $0 logs                 # 查看日志
    $0 cron-install          # 安装定时任务

服务特性:
    - 自动启动和重启
    - 系统重启后自动启动
    - 详细的日志记录
    - 可配置的阈值参数
    - 定时任务支持

EOF
}

# 主函数
main() {
    check_root
    
    case "${1:-help}" in
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            status_service
            ;;
        logs)
            view_logs
            ;;
        cron-install)
            install_cron
            ;;
        cron-uninstall)
            uninstall_cron
            ;;
        configure)
            configure_service
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
