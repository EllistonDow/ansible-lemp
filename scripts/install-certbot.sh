#!/bin/bash
# Certbot 独立安装脚本

set -e

echo "=== Certbot 安装脚本 ==="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 安装snapd
echo "安装snapd..."
sudo apt update
sudo apt install -y snapd

# 安装certbot
echo "通过snap安装Certbot..."
sudo snap install certbot --classic

# 创建符号链接
echo "创建符号链接..."
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# 验证安装
echo "验证Certbot安装..."
if certbot --version; then
    echo "Certbot安装成功！"
    echo ""
    echo "使用说明:"
    echo "1. 为nginx获取证书:"
    echo "   sudo certbot --nginx -d yourdomain.com"
    echo ""
    echo "2. 仅获取证书:"
    echo "   sudo certbot certonly --nginx -d yourdomain.com"
    echo ""
    echo "3. 自动续期测试:"
    echo "   sudo certbot renew --dry-run"
    echo ""
    echo "4. 查看已有证书:"
    echo "   sudo certbot certificates"
    echo ""
    echo "注意: 使用前请确保:"
    echo "- 域名已正确解析到服务器IP"
    echo "- nginx服务正在运行"
    echo "- 防火墙已开放80和443端口"
else
    echo "Certbot安装失败"
    exit 1
fi

echo "=== Certbot安装完成 ==="
echo "命令位置: /usr/bin/certbot"
echo "配置目录: /etc/letsencrypt/"
