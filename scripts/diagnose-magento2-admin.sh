#!/bin/bash

# Magento2 Admin 后台问题诊断脚本
# 用于诊断ModSecurity与Magento2后台菜单的兼容性问题

echo "========================================"
echo "   Magento2 Admin 后台诊断工具"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查Magento2安装
echo -e "\n${BLUE}1. 检查Magento2配置${NC}"
MAGE_ROOT="/home/doge/hawk"
if [[ -f "$MAGE_ROOT/app/etc/env.php" ]]; then
    ADMIN_FRONT=$(grep -o "frontName.*=.*'[^']*'" "$MAGE_ROOT/app/etc/env.php" | cut -d"'" -f2)
    echo -e "✅ Magento2根目录: $MAGE_ROOT"
    echo -e "✅ Admin路径: /${ADMIN_FRONT:-admin}"
else
    echo -e "❌ 未找到Magento2配置文件"
    exit 1
fi

# 检查nginx配置
echo -e "\n${BLUE}2. 检查Nginx配置${NC}"
if nginx -t &>/dev/null; then
    echo -e "✅ Nginx配置语法正确"
else
    echo -e "❌ Nginx配置有错误"
    nginx -t
fi

# 检查nginx版本和模块
echo -e "\n${BLUE}3. 检查Nginx版本和ModSecurity模块${NC}"
NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
echo -e "✅ Nginx版本: $NGINX_VERSION"

if nginx -V 2>&1 | grep -q "modsecurity"; then
    echo -e "✅ ModSecurity模块已编译"
else
    echo -e "❌ ModSecurity模块未编译"
fi

# 检查ModSecurity状态
echo -e "\n${BLUE}4. 检查ModSecurity状态${NC}"
if [[ -f "/etc/modsecurity/crs-setup.conf" ]]; then
    PARANOIA_LEVEL=$(grep "tx.paranoia_level" /etc/modsecurity/crs-setup.conf | grep -v "^#" | head -1 | sed 's/.*=\([0-9]*\).*/\1/')
    INBOUND_THRESHOLD=$(grep "tx.inbound_anomaly_score_threshold" /etc/modsecurity/crs-setup.conf | grep -v "^#" | head -1 | sed 's/.*=\([0-9]*\).*/\1/')
    
    echo -e "📊 当前ModSecurity配置:"
    echo -e "   - Paranoia级别: ${PARANOIA_LEVEL:-未设置}"
    echo -e "   - 入站阈值: ${INBOUND_THRESHOLD:-未设置}"
    
    # 检查Admin排除规则
    if grep -q "beginsWith /admin" /etc/modsecurity/crs-setup.conf; then
        echo -e "✅ 发现Admin排除规则"
    else
        echo -e "⚠️  未发现Admin排除规则"
    fi
else
    echo -e "❌ ModSecurity配置文件不存在"
fi

# 检查nginx网站配置中的admin location
echo -e "\n${BLUE}5. 检查网站配置中的Admin Location${NC}"
SITE_CONFIG="/etc/nginx/sites-available/hawktattoosupply.com.conf"
if [[ -f "$SITE_CONFIG" ]]; then
    if grep -q "location.*admin" "$SITE_CONFIG"; then
        echo -e "✅ 发现Admin location配置"
        echo -e "📋 Admin location配置:"
        grep -A 8 "location.*admin" "$SITE_CONFIG" | sed 's/^/   /'
    else
        echo -e "❌ 未发现Admin location配置"
    fi
else
    echo -e "❌ 网站配置文件不存在"
fi

# 测试Admin URL访问
echo -e "\n${BLUE}6. 测试Admin URL访问${NC}"
if [[ ! -z "$ADMIN_FRONT" ]]; then
    echo -e "🔍 测试访问: https://hawktattoosupply.com/${ADMIN_FRONT}/"
    
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null "https://hawktattoosupply.com/${ADMIN_FRONT}/")
    case $RESPONSE in
        200)
            echo -e "✅ 访问正常 (HTTP 200)"
            ;;
        302|301)
            echo -e "✅ 重定向正常 (HTTP $RESPONSE)"
            ;;
        403)
            echo -e "❌ 访问被拒绝 (HTTP 403) - 可能是ModSecurity阻止"
            ;;
        404)
            echo -e "⚠️  页面未找到 (HTTP 404)"
            ;;
        503)
            echo -e "❌ 服务不可用 (HTTP 503) - 可能是PHP-FPM问题"
            ;;
        *)
            echo -e "⚠️  未知响应代码: $RESPONSE"
            ;;
    esac
fi

# 检查最近的ModSecurity日志
echo -e "\n${BLUE}7. 检查ModSecurity审计日志${NC}"
if [[ -f "/var/log/nginx/modsec_audit.log" ]]; then
    RECENT_BLOCKS=$(tail -50 /var/log/nginx/modsec_audit.log | grep -c "admin")
    if [[ $RECENT_BLOCKS -gt 0 ]]; then
        echo -e "⚠️  发现${RECENT_BLOCKS}条与admin相关的ModSecurity记录"
        echo -e "📋 最近的admin相关记录:"
        tail -20 /var/log/nginx/modsec_audit.log | grep -A2 -B2 "admin" | tail -10 | sed 's/^/   /'
    else
        echo -e "ℹ️  最近无admin相关的ModSecurity记录"
    fi
else
    echo -e "ℹ️  ModSecurity审计日志不存在"
fi

# 检查nginx错误日志
echo -e "\n${BLUE}8. 检查Nginx错误日志${NC}"
if [[ -f "/var/log/nginx/error.log" ]]; then
    RECENT_ERRORS=$(tail -20 /var/log/nginx/error.log | grep -i "admin\|modsec\|forbidden" | wc -l)
    if [[ $RECENT_ERRORS -gt 0 ]]; then
        echo -e "⚠️  发现${RECENT_ERRORS}条相关错误记录"
        echo -e "📋 最近的相关错误:"
        tail -20 /var/log/nginx/error.log | grep -i "admin\|modsec\|forbidden" | sed 's/^/   /'
    else
        echo -e "✅ 无相关错误记录"
    fi
else
    echo -e "ℹ️  Nginx错误日志不存在"
fi

# 给出建议
echo -e "\n${YELLOW}9. 诊断建议${NC}"
echo -e "📋 根据检查结果，建议尝试以下操作:"

if [[ -z "$ADMIN_FRONT" ]]; then
    echo -e "   ❗ 无法获取Admin路径，请检查Magento2配置"
elif [[ $RECENT_BLOCKS -gt 0 ]]; then
    echo -e "   1. ModSecurity正在阻止admin访问，建议:"
    echo -e "      - 降低ModSecurity级别: ./scripts/toggle-modsecurity.sh 1"
    echo -e "      - 或者在nginx配置中为admin路径禁用ModSecurity"
elif [[ $RESPONSE == "503" ]]; then
    echo -e "   1. PHP-FPM服务问题，检查:"
    echo -e "      - sudo systemctl status php8.3-fpm"
    echo -e "      - sudo tail -f /var/log/php8.3-fpm.log"
elif [[ $RESPONSE == "403" ]]; then
    echo -e "   1. 访问权限问题，检查:"
    echo -e "      - 文件权限: sudo chown -R www-data:www-data $MAGE_ROOT"
    echo -e "      - ModSecurity规则配置"
else
    echo -e "   1. 尝试以下步骤:"
    echo -e "      - 临时关闭ModSecurity测试: ./scripts/toggle-modsecurity.sh 0"
    echo -e "      - 重新加载nginx: sudo systemctl reload nginx"
    echo -e "      - 检查Magento2缓存: cd $MAGE_ROOT && php bin/magento cache:clean"
fi

echo -e "\n${GREEN}诊断完成！${NC}"
echo -e "如果问题仍然存在，请将此报告提供给技术支持。"
