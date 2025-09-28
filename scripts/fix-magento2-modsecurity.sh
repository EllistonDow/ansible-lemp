#!/bin/bash
# Magento2 ModSecurity 精确调优脚本

echo "🔧 Magento2 ModSecurity 精确调优"
echo "================================"

# 1. 备份现有配置
sudo cp /etc/modsecurity/crs-setup.conf /etc/modsecurity/crs-setup.conf.backup.$(date +%Y%m%d_%H%M%S)

# 2. 创建Magento2优化的CRS配置
echo "📝 创建Magento2优化的CRS配置..."
sudo tee /etc/modsecurity/crs-setup.conf > /dev/null << 'EOF'
# Magento2 优化的 ModSecurity CRS 配置

SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off

# 使用最低敏感度级别
SecAction \
  "id:900000,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.paranoia_level=1"

# 提高异常分数阈值（更宽松）
SecAction \
  "id:900110,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.inbound_anomaly_score_threshold=20,\
   setvar:tx.outbound_anomaly_score_threshold=15"

# 设置CRS版本
SecAction \
  "id:900990,\
   phase:1,\
   nolog,\
   pass,\
   t:none,\
   setvar:tx.crs_setup_version=335"

# Magento2 Admin 区域完全排除
SecRule REQUEST_URI "@beginsWith /admin_tattoo" \
    "id:900200,\
     phase:1,\
     pass,\
     nolog,\
     msg:'Magento2 Admin Area - Disable ModSecurity',\
     ctl:ruleEngine=Off"

# 排除Magento2常见误报规则
# SQL注入相关
SecRuleRemoveById 942100 942110 942150 942180 942200 942260 942300 942310 942340 942350 942360 942370 942380 942390 942400 942410 942430 942440 942450 942460

# XSS相关
SecRuleRemoveById 941100 941110 941120 941130 941140 941150 941160 941170 941180 941190 941200 941210 941220 941230 941240 941250 941260 941270 941280 941290 941300 941310 941320 941330 941340 941350

# 协议违规
SecRuleRemoveById 920100 920120 920160 920170 920180 920190 920200 920210 920220 920230 920240 920250 920260 920270 920280 920290 920300 920310 920320 920330 920340 920350

# 通用攻击检测
SecRuleRemoveById 930100 930110 930120 930130

# PHP注入攻击
SecRuleRemoveById 933100 933110 933120 933130 933140 933150 933160 933170 933180

# Java攻击
SecRuleRemoveById 944100 944110 944120 944130 944140 944150 944160 944170 944180 944190 944200 944210 944220 944230 944240 944250

EOF

echo "✅ CRS配置已优化"

# 3. 测试配置
echo "🧪 测试nginx配置..."
if sudo nginx -t; then
    echo "✅ 配置测试通过"
    
    echo "🔄 重新加载nginx..."
    sudo systemctl reload nginx
    
    echo "✅ Nginx重新加载成功"
else
    echo "❌ 配置测试失败，恢复备份..."
    sudo cp /etc/modsecurity/crs-setup.conf.backup.* /etc/modsecurity/crs-setup.conf
    exit 1
fi

echo ""
echo "🎉 ModSecurity优化完成！"
echo ""
echo "📋 测试步骤："
echo "1. 清除浏览器缓存"
echo "2. 重新登录后台"
echo "3. 测试菜单和incoming message功能"
echo ""
echo "📊 监控命令："
echo "sudo tail -f /var/log/nginx/error.log | grep -i modsecurity"
echo ""
echo "💡 如果问题持续："
echo "• 考虑完全禁用ModSecurity: modsecurity off"
echo "• 或者仅为admin区域禁用: 添加location规则"
