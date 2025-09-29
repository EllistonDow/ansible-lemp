#!/bin/bash

# Complete nginx cleanup script for mixed installation scenarios
# This script handles both package-manager and source-compiled nginx installations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Nginx Complete Cleanup Script${NC}"
echo -e "${BLUE}=================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
    exit 1
fi

echo -e "${YELLOW}🔍 检测当前nginx安装状态...${NC}"

# Check current nginx installation
if command -v nginx >/dev/null 2>&1; then
    NGINX_VERSION=$(nginx -v 2>&1)
    echo "当前nginx版本: $NGINX_VERSION"
    NGINX_LOCATION=$(which nginx)
    echo "nginx位置: $NGINX_LOCATION"
else
    echo "nginx命令不可用"
fi

# Check nginx processes
NGINX_PROCESSES=$(ps aux | grep nginx | grep -v grep | wc -l)
if [ $NGINX_PROCESSES -gt 0 ]; then
    print_warning "发现 $NGINX_PROCESSES 个nginx进程正在运行"
    ps aux | grep nginx | grep -v grep
fi

echo -e "\n${YELLOW}🛑 停止nginx服务...${NC}"

# Stop nginx service
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
print_status "nginx服务已停止"

# Kill any remaining nginx processes
pkill nginx 2>/dev/null || true
killall nginx 2>/dev/null || true
print_status "所有nginx进程已终止"

echo -e "\n${YELLOW}🗑️  删除nginx二进制文件...${NC}"

# Remove nginx binaries
rm -f /usr/sbin/nginx
rm -f /usr/sbin/nginx-debug
rm -f /usr/local/bin/nginx-test
print_status "nginx二进制文件已删除"

echo -e "\n${YELLOW}🗂️  删除配置和数据目录...${NC}"

# Remove configuration and data directories
rm -rf /etc/nginx
rm -rf /var/log/nginx
rm -rf /var/cache/nginx
rm -rf /etc/modsecurity
print_status "配置和数据目录已删除"

echo -e "\n${YELLOW}⚙️  删除systemd服务文件...${NC}"

# Remove systemd service files
rm -f /etc/systemd/system/nginx.service
rm -rf /etc/systemd/system/nginx.service.d
rm -f /var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/nginx.service
rm -f /var/lib/systemd/deb-systemd-helper-enabled/nginx-debug.service.dsh-also
rm -f /var/lib/systemd/deb-systemd-helper-enabled/nginx.service.dsh-also
systemctl daemon-reload
print_status "systemd服务文件已删除"

echo -e "\n${YELLOW}📦 删除包管理器安装的nginx...${NC}"

# Remove nginx packages
apt-get remove --purge -y nginx nginx-common nginx-core nginx-full nginx-light nginx-extras 2>/dev/null || true
apt-get remove --purge -y libmodsecurity3 modsecurity-crs 2>/dev/null || true
print_status "nginx包已卸载"

echo -e "\n${YELLOW}📁 删除源码编译目录...${NC}"

# Remove source compilation directories
rm -rf /usr/local/src/nginx-1.29.1
rm -rf /usr/local/src/nginx-1.28.0
rm -f /usr/local/src/nginx-*.tar.gz*
rm -rf /usr/local/src/ModSecurity-nginx
print_status "源码目录已删除"

echo -e "\n${YELLOW}🧼 清理运行时文件...${NC}"

# Remove runtime files
rm -f /run/nginx.pid
rm -f /run/nginx.lock
print_status "运行时文件已清理"

echo -e "\n${YELLOW}🔧 清理包管理器缓存...${NC}"

# Clean package manager
apt-get autoremove -y
apt-get autoclean
print_status "包管理器缓存已清理"

echo -e "\n${YELLOW}🔍 验证清理结果...${NC}"

# Verify cleanup
REMAINING_FILES=$(find / -name "*nginx*" 2>/dev/null | grep -v "/home/" | grep -v "/proc/" | grep -v "/snap/" | head -20)

if [ -z "$REMAINING_FILES" ]; then
    print_status "所有nginx文件已完全清理"
    echo -e "\n${GREEN}🎉 Nginx完全卸载成功！${NC}"
    echo -e "\n${BLUE}📋 清理总结：${NC}"
    echo "✅ 停止并禁用了nginx服务"
    echo "✅ 删除了所有nginx二进制文件"
    echo "✅ 清理了配置和数据目录"
    echo "✅ 移除了systemd服务文件"
    echo "✅ 卸载了包管理器中的nginx包"
    echo "✅ 删除了源码编译目录"
    echo "✅ 清理了运行时和缓存文件"
    echo -e "\n${GREEN}🔄 建议重启系统以确保完全清理！${NC}"
else
    print_warning "发现一些残留文件："
    echo "$REMAINING_FILES" | head -10
    echo -e "\n${YELLOW}💡 这些文件可能是：${NC}"
    echo "- 用户配置文件 (可忽略)"
    echo "- 其他应用的nginx配置样本"
    echo "- 系统日志引用"
    echo -e "\n${GREEN}主要的nginx安装已完全清理！${NC}"
fi

echo -e "\n${BLUE}🔧 下一步操作：${NC}"
echo "1. 重启系统: sudo reboot"
echo "2. 重新安装nginx: cd /home/doge/ansible-lemp && ansible-playbook playbooks/nginx.yml"
echo "3. 检查清理状态: sudo find / -name '*nginx*' 2>/dev/null | grep -v home"

echo -e "\n${GREEN}✨ 清理脚本执行完成！${NC}"
