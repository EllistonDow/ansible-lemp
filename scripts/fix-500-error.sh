#!/bin/bash
# 500错误快速修复脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🚨 500错误快速诊断和修复脚本${NC}"
echo "=================================================="

# 1. 检查服务状态
echo -e "${BLUE}📊 检查服务状态...${NC}"
echo "Nginx状态:"
sudo systemctl is-active nginx || echo "❌ Nginx未运行"
echo "PHP-FPM状态:"
sudo systemctl is-active php8.3-fpm || echo "❌ PHP-FPM未运行"

# 2. 检查nginx配置
echo -e "\n${BLUE}🔧 检查Nginx配置...${NC}"
if sudo nginx -t 2>/dev/null; then
    echo "✅ Nginx配置语法正确"
else
    echo "❌ Nginx配置语法错误:"
    sudo nginx -t
fi

# 3. 查看错误日志
echo -e "\n${BLUE}📝 最新错误日志:${NC}"
echo "=== Nginx错误日志 ==="
sudo tail -10 /var/log/nginx/error.log 2>/dev/null || echo "无法读取nginx错误日志"

echo -e "\n=== PHP-FPM错误日志 ==="
sudo tail -10 /var/log/php8.3-fpm.log 2>/dev/null || echo "无法读取PHP-FPM错误日志"

# 4. 检查权限
echo -e "\n${BLUE}🔒 检查关键目录权限...${NC}"
ls -la /var/cache/nginx/ 2>/dev/null || echo "缓存目录不存在"
ls -la /var/www/html/ 2>/dev/null || echo "网站目录问题"

# 5. 检查ModSecurity
echo -e "\n${BLUE}🛡️ 检查ModSecurity状态...${NC}"
if grep -q "load_module.*modsecurity" /etc/nginx/nginx.conf; then
    echo "✅ ModSecurity模块已加载"
    if grep -q "modsecurity on" /etc/nginx/nginx.conf; then
        echo "✅ ModSecurity已启用"
    else
        echo "⚠️ ModSecurity已加载但未启用"
    fi
else
    echo "ℹ️ ModSecurity未配置"
fi

# 6. 提供修复建议
echo -e "\n${YELLOW}🔧 修复建议:${NC}"
echo "1. 如果是ModSecurity问题，运行:"
echo "   sudo sed -i 's/^load_module/#load_module/' /etc/nginx/nginx.conf"
echo "   sudo systemctl reload nginx"
echo ""
echo "2. 如果是权限问题，运行:"
echo "   sudo chown -R www-data:www-data /var/cache/nginx/"
echo "   sudo chmod -R 755 /var/cache/nginx/"
echo ""
echo "3. 如果是PHP内存问题，运行:"
echo "   sudo sed -i 's/memory_limit = .*/memory_limit = 4G/' /etc/php/8.3/fpm/php.ini"
echo "   sudo systemctl restart php8.3-fpm"
echo ""
echo "4. 恢复备份配置:"
echo "   sudo cp /opt/lemp-backups/magento2-optimizer/nginx.conf.original /etc/nginx/nginx.conf"
echo "   sudo systemctl reload nginx"

echo -e "\n${GREEN}✅ 诊断完成！请根据上述信息进行修复。${NC}"
