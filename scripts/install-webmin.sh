#!/bin/bash
# Webmin 独立安装脚本

set -e

echo "=== Webmin 安装脚本 ==="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 安装依赖
echo "安装依赖包..."
sudo apt update
sudo apt install -y wget apt-transport-https

# 下载最新版本Webmin
echo "下载Webmin..."
WEBMIN_VERSION="2.200"
cd /tmp
wget -q "http://prdownloads.sourceforge.net/webadmin/webmin_${WEBMIN_VERSION}_all.deb"

# 安装Webmin
echo "安装Webmin..."
sudo apt install -y "./webmin_${WEBMIN_VERSION}_all.deb"

# 启动服务
echo "启动Webmin服务..."
sudo systemctl enable webmin
sudo systemctl start webmin

# 检查状态
sleep 3
if sudo systemctl is-active webmin >/dev/null 2>&1; then
    echo "Webmin安装成功！"
    echo ""
    echo "访问信息:"
    echo "URL: https://localhost:10000"
    echo "用户名: root"
    echo "密码: 系统root密码"
    echo ""
    echo "注意: 首次访问时浏览器会提示SSL证书不受信任，这是正常的。"
else
    echo "Webmin启动可能有问题，请检查日志"
    sudo systemctl status webmin
fi

# 清理下载文件
rm -f "/tmp/webmin_${WEBMIN_VERSION}_all.deb"

echo "=== Webmin安装完成 ==="
echo "状态检查: sudo systemctl status webmin"
echo "配置文件: /etc/webmin/"
