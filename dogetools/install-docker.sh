#!/bin/bash
# Docker & Docker Compose 安装脚本
# 适用于 Ubuntu 24.04 LTS
# 作者: Ansible LEMP Project
# 版本: 2.2.2

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
ROCKET="🚀"
GEAR="⚙️"

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

# 检查系统版本
check_system() {
    log_info "检查系统版本..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测系统版本"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    if [[ "$VERSION_ID" != "24.04" ]]; then
        log_warning "此脚本专为 Ubuntu 24.04 设计，当前版本: $VERSION_ID"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
    
    log_success "系统检查通过: $PRETTY_NAME"
}

# 检查是否已安装 Docker
check_docker_installed() {
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_warning "Docker 已安装: $docker_version"
        
        if command -v docker compose &> /dev/null; then
            local compose_version=$(docker compose version --short)
            log_warning "Docker Compose 已安装: $compose_version"
        fi
        
        read -p "是否重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "安装已取消"
            exit 0
        fi
    fi
}

# 卸载旧版本 Docker
remove_old_docker() {
    log_info "卸载旧版本 Docker..."
    
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    log_success "旧版本 Docker 已卸载"
}

# 安装依赖包
install_dependencies() {
    log_info "安装依赖包..."
    
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common
    
    log_success "依赖包安装完成"
}

# 添加 Docker GPG 密钥
add_docker_gpg_key() {
    log_info "添加 Docker GPG 密钥..."
    
    # 创建目录
    sudo mkdir -p /etc/apt/keyrings
    
    # 下载并添加 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 设置权限
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    log_success "Docker GPG 密钥添加完成"
}

# 添加 Docker 仓库
add_docker_repository() {
    log_info "添加 Docker 仓库..."
    
    local arch=$(dpkg --print-architecture)
    local codename=$(lsb_release -cs)
    
    echo \
        "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_success "Docker 仓库添加完成"
}

# 安装 Docker Engine
install_docker_engine() {
    log_info "安装 Docker Engine..."
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker Engine 安装完成"
}

# 启动 Docker 服务
start_docker_service() {
    log_info "启动 Docker 服务..."
    
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker 服务已启动并设置开机自启"
}

# 检查用户权限
check_user_permissions() {
    log_info "检查用户权限..."
    
    # 检查当前用户是否已经在 docker 组中
    if groups $USER | grep -q '\bdocker\b'; then
        log_warning "用户 $USER 已经在 docker 组中"
        return 0
    fi
    
    # 检查 docker 组是否存在
    if ! getent group docker > /dev/null 2>&1; then
        log_error "docker 组不存在，请先安装 Docker"
        return 1
    fi
    
    return 1
}

# 配置用户组
configure_user_group() {
    log_info "配置用户组..."
    
    # 检查当前用户权限
    if check_user_permissions; then
        log_success "用户 $USER 权限已正确配置"
        return 0
    fi
    
    # 添加用户到 docker 组
    sudo usermod -aG docker $USER
    
    log_success "用户 $USER 已添加到 docker 组"
    
    # 提示用户重新登录或使用 newgrp
    log_warning "权限更改需要重新登录才能生效"
    log_info "或者运行: ${CYAN}newgrp docker${NC} 来立即应用新权限"
}

# 测试无 sudo 权限的 Docker 访问
test_docker_permissions() {
    log_info "测试 Docker 权限..."
    
    # 检查是否可以直接使用 docker 命令（无需 sudo）
    if docker --version > /dev/null 2>&1; then
        log_success "✅ Docker 权限测试通过 - 无需 sudo"
        
        # 测试运行容器
        if docker run --rm hello-world > /dev/null 2>&1; then
            log_success "✅ Docker 容器运行测试通过 - 无需 sudo"
            return 0
        else
            log_warning "⚠️ Docker 命令可用但无法运行容器，可能需要重新登录"
            return 1
        fi
    else
        log_warning "⚠️ Docker 权限测试失败 - 仍需要 sudo"
        log_info "请运行: ${CYAN}newgrp docker${NC} 或重新登录"
        return 1
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查 Docker 版本
    local docker_version=$(sudo docker --version)
    log_success "Docker 版本: $docker_version"
    
    # 检查 Docker Compose 版本
    local compose_version=$(sudo docker compose version)
    log_success "Docker Compose 版本: $compose_version"
    
    # 测试 Docker 运行（使用 sudo）
    log_info "测试 Docker 运行..."
    if sudo docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker 运行测试通过"
    else
        log_error "Docker 运行测试失败"
        return 1
    fi
    
    # 显示 Docker 信息
    log_info "Docker 系统信息:"
    sudo docker system info --format "{{.ServerVersion}}" | head -1
    
    # 测试无 sudo 权限的 Docker 访问
    test_docker_permissions
}

# 显示安装后说明
show_post_install_info() {
    echo
    log_success "🎉 Docker 和 Docker Compose 安装完成！"
    echo
    echo -e "${YELLOW}📋 安装后说明:${NC}"
    echo -e "  ${INFO_MARK} 当前用户已添加到 docker 组"
    echo -e "  ${INFO_MARK} 请重新登录或运行: ${CYAN}newgrp docker${NC}"
    echo -e "  ${INFO_MARK} 然后就可以使用: ${CYAN}docker${NC} 和 ${CYAN}docker compose${NC} 命令"
    echo
    echo -e "${YELLOW}🔐 权限说明:${NC}"
    echo -e "  ${CHECK_MARK} 如果看到 '权限测试通过 - 无需 sudo'，说明权限已正确配置"
    echo -e "  ${WARNING_MARK} 如果仍需要 sudo，请运行: ${CYAN}newgrp docker${NC}"
    echo -e "  ${INFO_MARK} 或者重新登录系统以应用新的组权限"
    echo
    echo -e "${YELLOW}🚀 常用命令:${NC}"
    echo -e "  ${CYAN}docker --version${NC}           # 查看 Docker 版本"
    echo -e "  ${CYAN}docker compose version${NC}      # 查看 Docker Compose 版本"
    echo -e "  ${CYAN}docker run hello-world${NC}      # 运行测试容器"
    echo -e "  ${CYAN}docker system info${NC}         # 查看 Docker 系统信息"
    echo -e "  ${CYAN}docker system prune${NC}        # 清理未使用的资源"
    echo
    echo -e "${YELLOW}🔧 权限故障排除:${NC}"
    echo -e "  ${CYAN}groups \$${NC}                  # 查看当前用户所属组"
    echo -e "  ${CYAN}newgrp docker${NC}              # 立即应用 docker 组权限"
    echo -e "  ${CYAN}sudo usermod -aG docker \$${NC} # 重新添加用户到 docker 组"
    echo
    echo -e "${YELLOW}📚 学习资源:${NC}"
    echo -e "  ${CYAN}https://docs.docker.com/${NC}   # Docker 官方文档"
    echo -e "  ${CYAN}https://docs.docker.com/compose/${NC} # Docker Compose 文档"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Docker & Docker Compose 安装脚本${NC}"
    echo
    echo -e "${YELLOW}功能:${NC}"
    echo -e "  • 自动安装 Docker Engine"
    echo -e "  • 自动安装 Docker Compose Plugin"
    echo -e "  • 智能配置用户组权限"
    echo -e "  • 权限检查和自动修复"
    echo -e "  • 无 sudo 权限测试"
    echo -e "  • 设置开机自启"
    echo -e "  • 验证安装结果"
    echo
    echo -e "${YELLOW}支持的安装方法:${NC}"
    echo -e "  ${GREEN}1. 官方仓库安装 (推荐)${NC} - 稳定可靠，自动更新"
    echo -e "  ${GREEN}2. 一键脚本安装${NC} - 简单快捷，适合快速部署"
    echo
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./install-docker.sh${NC}           # 使用官方仓库安装"
    echo -e "  ${CYAN}./install-docker.sh --quick${NC}  # 使用一键脚本安装"
    echo -e "  ${CYAN}./install-docker.sh --fix-perms${NC} # 修复 Docker 权限问题"
    echo -e "  ${CYAN}./install-docker.sh --help${NC}   # 显示帮助信息"
    echo
    echo -e "${YELLOW}系统要求:${NC}"
    echo -e "  • Ubuntu 24.04 LTS (推荐)"
    echo -e "  • 64位系统架构"
    echo -e "  • 至少 2GB 内存"
    echo -e "  • 至少 10GB 可用磁盘空间"
    echo
}

# 修复 Docker 权限问题
fix_docker_permissions() {
    log_info "修复 Docker 权限问题..."
    
    # 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先运行安装脚本"
        exit 1
    fi
    
    # 检查 docker 组是否存在
    if ! getent group docker > /dev/null 2>&1; then
        log_error "docker 组不存在，请重新安装 Docker"
        exit 1
    fi
    
    # 配置用户组权限
    configure_user_group
    
    # 测试权限
    echo
    log_info "测试修复后的权限..."
    if test_docker_permissions; then
        log_success "🎉 权限修复成功！现在可以无 sudo 使用 Docker"
    else
        log_warning "权限修复完成，但需要重新登录或运行 newgrp docker"
        echo
        log_info "请运行以下命令之一:"
        echo -e "  ${CYAN}newgrp docker${NC}  # 立即应用权限"
        echo -e "  ${CYAN}logout${NC}         # 重新登录系统"
    fi
}

# 一键脚本安装方法
quick_install() {
    log_info "使用一键脚本安装 Docker..."
    
    # 下载官方安装脚本
    curl -fsSL https://get.docker.com -o get-docker.sh
    
    # 执行安装脚本
    sudo sh get-docker.sh
    
    # 清理安装脚本
    rm get-docker.sh
    
    # 安装 Docker Compose Plugin
    sudo apt-get install -y docker-compose-plugin
    
    # 启动服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 配置用户组
    sudo usermod -aG docker $USER
    
    log_success "一键脚本安装完成"
}

# 主函数
main() {
    echo -e "${ROCKET} ${CYAN}Docker & Docker Compose 安装脚本${NC}"
    echo -e "${GEAR} 适用于 Ubuntu 24.04 LTS"
    echo
    
    case "${1:-}" in
        "--help"|"-h"|"help")
            show_help
            exit 0
            ;;
        "--quick"|"-q")
            log_info "使用一键脚本安装方法..."
            check_system
            check_docker_installed
            quick_install
            verify_installation
            show_post_install_info
            ;;
        "--fix-perms"|"-f")
            log_info "修复 Docker 权限问题..."
            fix_docker_permissions
            ;;
        "")
            log_info "使用官方仓库安装方法..."
            check_system
            check_docker_installed
            remove_old_docker
            install_dependencies
            add_docker_gpg_key
            add_docker_repository
            install_docker_engine
            start_docker_service
            configure_user_group
            verify_installation
            show_post_install_info
            ;;
        *)
            log_error "未知参数: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 检查是否以root身份运行
if [[ $EUID -eq 0 ]]; then
    log_warning "请不要以root身份直接运行此脚本"
    log_info "使用: ./install-docker.sh"
    exit 1
fi

# 执行主函数
main "$@"
