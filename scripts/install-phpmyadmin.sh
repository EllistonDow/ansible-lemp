#!/bin/bash
# phpMyAdmin 独立安装脚本

set -e

echo "=== phpMyAdmin 安装脚本 ==="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 检查必要服务
echo "检查必要服务..."
if ! systemctl is-active nginx >/dev/null 2>&1; then
    echo "错误: Nginx服务未运行，请先安装并启动Nginx"
    exit 1
fi

if ! systemctl is-active php*-fpm >/dev/null 2>&1; then
    echo "错误: PHP-FPM服务未运行，请先安装并启动PHP"
    exit 1
fi

# 安装phpMyAdmin
echo "安装phpMyAdmin..."
sudo apt update
sudo apt install -y phpmyadmin

# 创建nginx配置目录
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets

# 创建fastcgi-php配置
echo "创建fastcgi-php配置..."
sudo tee /etc/nginx/snippets/fastcgi-php.conf > /dev/null << 'EOF'
# regex to split $uri to $fastcgi_script_name and $fastcgi_path
fastcgi_split_path_info ^(.+?\.php)(/.*)$;

# Check that the PHP script exists before passing it
try_files $fastcgi_script_name =404;

# Bypass the fact that try_files resets $fastcgi_path_info
set $path_info $fastcgi_path_info;
fastcgi_param PATH_INFO $path_info;

fastcgi_index index.php;
include fastcgi_params;
EOF

# 创建phpMyAdmin nginx站点配置
echo "创建nginx站点配置..."
sudo tee /etc/nginx/sites-available/phpmyadmin.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name phpmyadmin.local localhost;
    root /usr/share/phpmyadmin;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # phpMyAdmin specific security
    location ~ ^/phpmyadmin/(doc|sql|setup)/ {
        deny all;
    }
}
EOF

# 启用站点
echo "启用phpMyAdmin站点..."
sudo ln -sf /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf

# 测试nginx配置
echo "测试nginx配置..."
if sudo nginx -t; then
    echo "重新加载nginx..."
    sudo systemctl reload nginx
    echo "phpMyAdmin安装成功！"
    echo ""
    echo "访问信息:"
    echo "URL: http://localhost/phpmyadmin"
    echo "或者: http://phpmyadmin.local"
    echo ""
    echo "数据库连接信息:"
    echo "服务器: localhost"
    echo "用户名: (MySQL用户名)"
    echo "密码: (对应的MySQL密码)"
    echo ""
    echo "注意: 请确保已配置MySQL用户权限"
else
    echo "nginx配置测试失败，请检查配置"
    exit 1
fi

echo "=== phpMyAdmin安装完成 ==="
echo "配置文件: /etc/nginx/sites-available/phpmyadmin.conf"
echo "网站根目录: /usr/share/phpmyadmin"
