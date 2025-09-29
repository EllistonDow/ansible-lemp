#!/bin/bash
# ModSecurity CRS 紧急修复脚本
# 解决 crs_setup_version 错误

set -e

echo "🚨 ModSecurity CRS 紧急修复"
echo "================================"

# 1. 备份现有配置
echo "📦 备份现有配置..."
sudo cp /etc/modsecurity/crs-setup.conf /etc/modsecurity/crs-setup.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
sudo cp /etc/nginx/modsec/main.conf /etc/nginx/modsec/main.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# 2. 创建正确的crs-setup.conf
echo "🔧 创建正确的CRS设置文件..."
sudo tee /etc/modsecurity/crs-setup.conf > /dev/null << 'EOF'
# OWASP ModSecurity Core Rule Set Configuration
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off

# Set paranoia level (1 = least strict, good for production)
SecAction \
  "id:900000,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.paranoia_level=1"

# Set anomaly scores
SecAction \
  "id:900110,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.inbound_anomaly_score_threshold=5,\
   setvar:tx.outbound_anomaly_score_threshold=4"

# CRITICAL: Set CRS version to fix the error
SecAction \
  "id:900990,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.crs_setup_version=335"

# Allow common HTTP methods
SecAction \
  "id:900100,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE"
EOF

# 3. 修复main.conf包含顺序
echo "📋 修复main.conf包含顺序..."
sudo tee /etc/nginx/modsec/main.conf > /dev/null << 'EOF'
# ModSecurity configuration
Include /etc/modsecurity/modsecurity.conf

# Include CRS setup BEFORE rules (CRITICAL)
Include /etc/modsecurity/crs-setup.conf

# Include CRS rules AFTER setup
Include /etc/modsecurity/rules/*.conf
EOF

# 4. 为admin区域禁用ModSecurity（临时解决方案）
echo "🛡️ 查找并配置admin区域..."
SITE_CONF=$(find /etc/nginx -name "*.conf" -exec grep -l "nucleartattooca.com" {} \; 2>/dev/null | head -1)

if [[ -n "$SITE_CONF" ]]; then
    echo "找到站点配置: $SITE_CONF"
    
    # 检查是否已有admin配置
    if ! grep -q "location.*admin_tattoo" "$SITE_CONF"; then
        echo "添加admin区域ModSecurity禁用配置..."
        
        # 在server块中添加admin location
        sudo sed -i '/server_name.*nucleartattooca\.com/a\\n    # Disable ModSecurity for admin area\n    location /admin_tattoo/ {\n        modsecurity off;\n        try_files $uri $uri/ /index.php$is_args$args;\n        \n        location ~ \\.php$ {\n            fastcgi_pass unix:/run/php/php8.3-fpm.sock;\n            fastcgi_index index.php;\n            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n            include fastcgi_params;\n        }\n    }' "$SITE_CONF"
    else
        echo "Admin配置已存在，跳过..."
    fi
else
    echo "⚠️ 未找到站点配置文件，请手动添加admin区域配置"
fi

# 5. 测试配置
echo "🧪 测试nginx配置..."
if sudo nginx -t; then
    echo "✅ 配置测试通过"
    
    # 重启nginx
    echo "🔄 重启nginx..."
    sudo systemctl restart nginx
    
    echo "✅ Nginx重启成功"
else
    echo "❌ 配置测试失败，恢复备份..."
    sudo cp /etc/modsecurity/crs-setup.conf.backup.* /etc/modsecurity/crs-setup.conf 2>/dev/null || true
    sudo cp /etc/nginx/modsec/main.conf.backup.* /etc/nginx/modsec/main.conf 2>/dev/null || true
    exit 1
fi

# 6. 验证修复
echo "🔍 验证修复..."
sleep 2

# 测试主站
echo "测试主站..."
curl -s -o /dev/null -w "%{http_code}" http://www.nucleartattooca.com/ || echo "主站测试失败"

# 测试admin
echo "测试admin区域..."
curl -s -o /dev/null -w "%{http_code}" http://www.nucleartattooca.com/admin_tattoo/ || echo "Admin测试失败"

echo ""
echo "🎉 修复完成！"
echo ""
echo "📋 验证步骤："
echo "1. 访问 https://www.nucleartattooca.com/"
echo "2. 访问 https://www.nucleartattooca.com/admin_tattoo/"
echo "3. 检查后台菜单是否正常工作"
echo ""
echo "📊 监控日志："
echo "sudo tail -f /var/log/nginx/error.log | grep -v 'crs_setup_version'"
echo ""
echo "💡 如果还有问题："
echo "• 检查 /etc/modsecurity/crs-setup.conf 文件权限"
echo "• 确认 /etc/modsecurity/rules/ 目录存在"
echo "• 考虑临时完全禁用ModSecurity进行测试"
