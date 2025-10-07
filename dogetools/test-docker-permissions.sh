#!/bin/bash
# Docker 权限测试脚本
# 用于测试 Docker 安装脚本的权限管理功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"

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

# 测试 Docker 权限
test_docker_permissions() {
    log_info "测试 Docker 权限..."
    
    # 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        return 1
    fi
    
    # 检查用户是否在 docker 组中
    if groups $USER | grep -q '\bdocker\b'; then
        log_success "用户 $USER 在 docker 组中"
    else
        log_warning "用户 $USER 不在 docker 组中"
        return 1
    fi
    
    # 测试无 sudo 权限的 Docker 访问
    if docker --version > /dev/null 2>&1; then
        log_success "✅ Docker 命令可用 - 无需 sudo"
        
        # 测试运行容器
        if docker run --rm hello-world > /dev/null 2>&1; then
            log_success "✅ Docker 容器运行测试通过 - 无需 sudo"
            return 0
        else
            log_warning "⚠️ Docker 命令可用但无法运行容器"
            return 1
        fi
    else
        log_error "❌ Docker 权限测试失败 - 仍需要 sudo"
        return 1
    fi
}

# 显示当前权限状态
show_permission_status() {
    echo
    log_info "当前权限状态:"
    echo -e "  用户: ${YELLOW}$USER${NC}"
    echo -e "  用户组: ${YELLOW}$(groups $USER)${NC}"
    
    if groups $USER | grep -q '\bdocker\b'; then
        echo -e "  Docker 组: ${GREEN}已加入${NC}"
    else
        echo -e "  Docker 组: ${RED}未加入${NC}"
    fi
    
    echo
}

# 主函数
main() {
    echo -e "${INFO_MARK} ${BLUE}Docker 权限测试脚本${NC}"
    echo
    
    show_permission_status
    test_docker_permissions
    
    echo
    if [ $? -eq 0 ]; then
        log_success "🎉 Docker 权限配置正确！"
    else
        log_warning "需要修复 Docker 权限"
        echo
        log_info "请运行以下命令修复权限:"
        echo -e "  ${YELLOW}./install-docker.sh --fix-perms${NC}"
        echo -e "  或者: ${YELLOW}sudo usermod -aG docker \$USER${NC}"
        echo -e "  然后: ${YELLOW}newgrp docker${NC}"
    fi
}

# 执行主函数
main "$@"
