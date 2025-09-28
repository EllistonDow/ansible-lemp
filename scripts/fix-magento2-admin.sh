#!/bin/bash
# Magento2后台菜单无响应修复脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Magento2后台菜单修复工具${NC}"
echo "=================================================="

# 检查是否在Magento2目录
if [[ ! -f "bin/magento" ]]; then
    echo -e "${RED}❌ 错误: 请在Magento2根目录运行此脚本${NC}"
    exit 1
fi

echo -e "${BLUE}📊 诊断当前状态...${NC}"

# 1. 检查Magento2模式
echo "当前Magento2模式:"
php bin/magento deploy:mode:show

# 2. 检查PHP设置
echo -e "\n当前PHP关键设置:"
php -r "
echo 'memory_limit: ' . ini_get('memory_limit') . PHP_EOL;
echo 'max_execution_time: ' . ini_get('max_execution_time') . PHP_EOL;
echo 'max_input_vars: ' . ini_get('max_input_vars') . PHP_EOL;
echo 'max_input_time: ' . ini_get('max_input_time') . PHP_EOL;
"

# 3. 检查缓存状态
echo -e "\n缓存状态:"
php bin/magento cache:status

echo -e "\n${YELLOW}🚀 开始修复...${NC}"

# 修复1: 优化PHP设置
echo -e "${BLUE}1. 优化PHP设置...${NC}"
if grep -q "max_input_vars.*1000" /etc/php/8.3/fpm/php.ini; then
    echo "  ⚡ 增加max_input_vars到10000..."
    sudo sed -i 's/max_input_vars = .*/max_input_vars = 10000/' /etc/php/8.3/fpm/php.ini
fi

if grep -q "max_execution_time.*30" /etc/php/8.3/fpm/php.ini; then
    echo "  ⚡ 增加max_execution_time到3600..."
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 3600/' /etc/php/8.3/fpm/php.ini
fi

# 修复2: 清理缓存
echo -e "${BLUE}2. 清理所有缓存...${NC}"
php bin/magento cache:flush
php bin/magento cache:clean

# 修复3: 重新编译
echo -e "${BLUE}3. 重新编译DI和生成静态文件...${NC}"
php bin/magento setup:di:compile

# 检查是否为production模式
MODE=$(php bin/magento deploy:mode:show)
if [[ "$MODE" == *"production"* ]]; then
    echo "  ⚡ 生产模式，部署静态内容..."
    php bin/magento setup:static-content:deploy -f
else
    echo "  ℹ️ 开发模式，跳过静态内容部署"
fi

# 修复4: 优化Session配置
echo -e "${BLUE}4. 优化Session配置...${NC}"
php bin/magento config:set web/session/use_remote_addr 0
php bin/magento config:set web/session/use_http_via 0
php bin/magento config:set web/session/use_http_x_forwarded_for 0

# 修复5: 清理nginx缓存
echo -e "${BLUE}5. 清理nginx FastCGI缓存...${NC}"
if [[ -d "/var/cache/nginx/fastcgi" ]]; then
    sudo rm -rf /var/cache/nginx/fastcgi/*
    echo "  ✅ nginx缓存已清理"
fi

# 修复6: 重启服务
echo -e "${BLUE}6. 重启相关服务...${NC}"
sudo systemctl restart php8.3-fpm
sudo systemctl reload nginx

# 修复7: 权限检查
echo -e "${BLUE}7. 检查关键目录权限...${NC}"
find var generated pub/static pub/media app/etc -type f -exec chmod g+w {} + 2>/dev/null || true
find var generated pub/static pub/media app/etc -type d -exec chmod g+ws {} + 2>/dev/null || true
chown -R :www-data . 2>/dev/null || true
chmod u+x bin/magento

echo -e "\n${GREEN}✅ 修复完成！${NC}"
echo -e "\n${YELLOW}📋 建议的测试步骤:${NC}"
echo "1. 清除浏览器缓存"
echo "2. 尝试登录后台"
echo "3. 测试菜单点击响应"
echo "4. 检查浏览器开发者工具Console面板"
echo "5. 如果还有问题，查看: sudo tail -f /var/log/nginx/error.log"

echo -e "\n${YELLOW}⚠️ 如果问题持续:${NC}"
echo "• 切换到developer模式: php bin/magento deploy:mode:set developer"
echo "• 禁用ModSecurity: 在nginx admin location中添加 'modsecurity off;'"
echo "• 检查JavaScript错误: 浏览器F12 → Console"
