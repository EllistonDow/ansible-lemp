#!/bin/bash
# Valkey 8 独立安装脚本 (基于Redis)

set -e

echo "=== Valkey 8 安装脚本 ==="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 安装Redis作为基础
echo "安装Redis服务器..."
sudo apt update
sudo apt install -y redis-server

# 停止Redis服务
echo "停止Redis服务..."
sudo systemctl stop redis-server
sudo systemctl disable redis-server

# 创建Valkey用户和目录
echo "创建Valkey用户和目录..."
sudo groupadd -f valkey
sudo useradd -r -g valkey -s /bin/false -d /var/lib/valkey valkey || true
sudo mkdir -p /var/lib/valkey /etc/valkey /var/log/valkey
sudo chown -R valkey:valkey /var/lib/valkey /etc/valkey /var/log/valkey

# 创建Valkey二进制文件符号链接
echo "创建Valkey二进制文件..."
sudo ln -sf /usr/bin/redis-server /usr/local/bin/valkey-server
sudo ln -sf /usr/bin/redis-cli /usr/local/bin/valkey-cli

# 复制和修改配置文件
echo "配置Valkey..."
sudo cp /etc/redis/redis.conf /etc/valkey/valkey.conf
sudo chown valkey:valkey /etc/valkey/valkey.conf
sudo chmod 640 /etc/valkey/valkey.conf

# 更新配置文件路径
sudo sed -i 's|^dir /var/lib/redis|dir /var/lib/valkey|' /etc/valkey/valkey.conf
sudo sed -i 's|^logfile /var/log/redis/redis-server.log|logfile /var/log/valkey/valkey.log|' /etc/valkey/valkey.conf
sudo sed -i 's|^pidfile /run/redis/redis-server.pid|pidfile /run/valkey/valkey.pid|' /etc/valkey/valkey.conf

# 创建systemd服务
echo "创建Valkey systemd服务..."
sudo tee /etc/systemd/system/valkey.service > /dev/null << 'EOF'
[Unit]
Description=Advanced key-value store (Valkey)
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/valkey-server /etc/valkey/valkey.conf --daemonize yes
ExecStop=/usr/local/bin/valkey-cli shutdown
TimeoutStopSec=0
Restart=always
User=valkey
Group=valkey
RuntimeDirectory=valkey
RuntimeDirectoryMode=0755
WorkingDirectory=/var/lib/valkey

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo "启动Valkey服务..."
sudo systemctl daemon-reload
sudo systemctl enable valkey
sudo systemctl start valkey

# 测试连接
echo "测试Valkey连接..."
sleep 2
if /usr/local/bin/valkey-cli ping; then
    echo "Valkey安装成功！"
else
    echo "Valkey启动可能有问题，请检查日志"
fi

echo "=== Valkey安装完成 ==="
echo "连接测试: valkey-cli ping"
echo "状态检查: sudo systemctl status valkey"
echo "配置文件: /etc/valkey/valkey.conf"
