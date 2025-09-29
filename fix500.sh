#!/bin/bash
# ModSecurity CRS 500错误修复脚本

echo "🔧 修复ModSecurity CRS配置..."

# 1. 创建crs-setup.conf
if [[ ! -f "/etc/modsecurity/crs-setup.conf" ]]; then
    echo "创建crs-setup.conf文件..."
    sudo cp /etc/modsecurity/crs-setup.conf.example /etc/modsecurity/crs-setup.conf 2>/dev/null || \
    sudo tee /etc/modsecurity/crs-setup.conf > /dev/null << 'EOF'
SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off
SecAction "id:900000,phase:1,nolog,pass,t:none,setvar:tx.paranoia_level=1"
SecAction "id:900110,phase:1,nolog,pass,t:none,setvar:tx.inbound_anomaly_score_threshold=5,setvar:tx.outbound_anomaly_score_threshold=4"
SecAction "id:900990,phase:1,nolog,pass,t:none,setvar:tx.crs_setup_version=335"
EOF
fi

# 2. 修复main.conf文件
echo "修复main.conf包含顺序..."
sudo tee /etc/nginx/modsec/main.conf > /dev/null << 'EOF'
Include /etc/modsecurity/modsecurity.conf
Include /etc/modsecurity/crs-setup.conf
Include /etc/modsecurity/rules/*.conf
EOF

# 3. 测试并重启
echo "测试配置并重启nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "✅ 修复完成！"
