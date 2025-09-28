#!/bin/bash
# Magento2 Admin 后台 ModSecurity 白名单配置脚本

set -e

echo "🛡️ Magento2 Admin ModSecurity 白名单配置"
echo "=========================================="

# 查找站点配置文件
SITE_CONF=$(find /etc/nginx -name "*.conf" -exec grep -l "nucleartattooca.com\|admin_tattoo" {} \; 2>/dev/null | head -1)

if [[ -z "$SITE_CONF" ]]; then
    echo "❌ 未找到站点配置文件"
    echo "请手动配置以下内容到你的nginx站点配置中："
    cat << 'EOF'

# 添加到你的server块中：
location /admin_tattoo/ {
    # 完全禁用ModSecurity for admin
    modsecurity off;
    
    # 增加超时和buffer
    fastcgi_read_timeout 600;
    fastcgi_send_timeout 600;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 8 128k;
    
    # 禁用缓存
    fastcgi_cache_bypass 1;
    fastcgi_no_cache 1;
    
    try_files $uri $uri/ /index.php$is_args$args;
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 600;
        fastcgi_cache_bypass 1;
        fastcgi_no_cache 1;
    }
}

# Admin静态资源
location ~* ^/admin_tattoo/.*\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    modsecurity off;
    expires 1y;
    add_header Cache-Control "public";
    try_files $uri @magento_admin_static;
}

location @magento_admin_static {
    rewrite ^/admin_tattoo/(.*)$ /static.php?resource=$1 last;
}

EOF
    exit 1
fi

echo "找到配置文件: $SITE_CONF"

# 备份配置文件
sudo cp "$SITE_CONF" "${SITE_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ 配置文件已备份"

# 检查是否已有admin配置
if grep -q "location.*admin_tattoo" "$SITE_CONF"; then
    echo "⚠️ 检测到已有admin_tattoo配置，请手动检查并更新"
    echo "建议手动添加 'modsecurity off;' 到现有的admin location块中"
    exit 0
fi

echo "🔧 添加admin区域ModSecurity白名单配置..."

# 创建临时配置文件
TEMP_CONF="/tmp/admin_config_$$"
cat > "$TEMP_CONF" << 'EOF'

    # Magento2 Admin 后台优化配置 - 完全禁用ModSecurity
    location /admin_tattoo/ {
        modsecurity off;
        
        # 优化超时设置
        fastcgi_read_timeout 600;
        fastcgi_send_timeout 600;
        fastcgi_connect_timeout 60;
        
        # 优化buffer设置
        fastcgi_buffer_size 128k;
        fastcgi_buffers 8 128k;
        fastcgi_busy_buffers_size 256k;
        
        # 禁用缓存（admin不需要缓存）
        fastcgi_cache_bypass 1;
        fastcgi_no_cache 1;
        
        try_files $uri $uri/ /index.php$is_args$args;
        
        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.3-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
            
            # PHP超时优化
            fastcgi_read_timeout 600;
            fastcgi_send_timeout 600;
            
            # 禁用PHP缓存
            fastcgi_cache_bypass 1;
            fastcgi_no_cache 1;
        }
    }
    
    # Admin静态资源优化
    location ~* ^/admin_tattoo/.*\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        modsecurity off;
        expires 1y;
        add_header Cache-Control "public";
        add_header Access-Control-Allow-Origin "*";
        try_files $uri @magento_admin_static;
    }
    
    location @magento_admin_static {
        rewrite ^/admin_tattoo/(.*)$ /static.php?resource=$1 last;
    }

EOF

# 在server块的开始处插入admin配置
sudo sed -i '/server {/r '"$TEMP_CONF" "$SITE_CONF"

# 清理临时文件
rm "$TEMP_CONF"

echo "✅ Admin配置已添加"

# 测试配置
echo "🧪 测试nginx配置..."
if sudo nginx -t; then
    echo "✅ 配置测试通过"
    
    echo "🔄 重新加载nginx..."
    sudo systemctl reload nginx
    
    echo "✅ Nginx重新加载成功"
else
    echo "❌ 配置测试失败，恢复备份..."
    sudo cp "${SITE_CONF}.backup.$(date +%Y%m%d_%H%M%S)" "$SITE_CONF"
    exit 1
fi

echo ""
echo "🎉 配置完成！"
echo ""
echo "📋 测试步骤："
echo "1. 清除浏览器缓存和cookies"
echo "2. 重新登录后台: https://www.nucleartattooca.com/admin_tattoo/"
echo "3. 检查incoming message弹窗是否恢复"
echo "4. 测试菜单点击是否正常"
echo "5. 检查dashboard通知是否显示"
echo ""
echo "📊 监控日志："
echo "sudo tail -f /var/log/nginx/error.log | grep -v 'admin_tattoo'"
echo ""
echo "💡 说明："
echo "• Admin区域(/admin_tattoo/)已完全禁用ModSecurity"
echo "• 前台仍然受到ModSecurity保护"
echo "• 如需回滚，使用备份文件恢复配置"

# 显示备份文件位置
echo ""
echo "📦 备份文件位置："
ls -la "${SITE_CONF}.backup."* 2>/dev/null | tail -1