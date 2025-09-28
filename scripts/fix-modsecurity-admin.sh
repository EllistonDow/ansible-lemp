#!/bin/bash
# ModSecurity Admin 区域白名单修复脚本
# 解决ModSecurity过度拦截Magento2后台的问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🛡️ ModSecurity Admin区域修复工具${NC}"
echo "=================================================="

# 检查ModSecurity拦截记录
echo -e "${BLUE}📊 检查最近的ModSecurity拦截记录...${NC}"
echo "最近10条admin相关的拦截："
sudo grep -i "ModSecurity.*admin" /var/log/nginx/error.log | tail -10 || echo "未找到admin相关拦截记录"

echo -e "\n最近5条ModSecurity拦截："
sudo grep -i "ModSecurity: Access denied" /var/log/nginx/error.log | tail -5 || echo "未找到拦截记录"

# 提供修复选项
echo -e "\n${YELLOW}🔧 修复选项:${NC}"
echo "1. 临时降低ModSecurity敏感度（全站）"
echo "2. 为Admin区域禁用ModSecurity（推荐）"
echo "3. 查看详细拦截日志"
echo "4. 退出"

read -p "请选择修复方案 (1-4): " choice

case $choice in
    1)
        echo -e "${BLUE}降低ModSecurity敏感度...${NC}"
        
        # 备份原始文件
        sudo cp /etc/modsecurity/crs-setup.conf /etc/modsecurity/crs-setup.conf.backup.$(date +%Y%m%d_%H%M%S)
        
        # 降低paranoia level和提高阈值
        sudo sed -i 's/setvar:tx\.paranoia_level=[0-9]/setvar:tx.paranoia_level=1/' /etc/modsecurity/crs-setup.conf
        sudo sed -i 's/setvar:tx\.inbound_anomaly_score_threshold=[0-9]/setvar:tx.inbound_anomaly_score_threshold=10/' /etc/modsecurity/crs-setup.conf
        
        # 重启nginx
        sudo systemctl reload nginx
        echo -e "${GREEN}✅ ModSecurity敏感度已降低${NC}"
        ;;
        
    2)
        echo -e "${BLUE}为Admin区域禁用ModSecurity...${NC}"
        
        # 查找Magento2配置文件
        MAGENTO_CONF=$(find /etc/nginx -name "*.conf" -exec grep -l "index\.php" {} \; | head -1)
        
        if [[ -z "$MAGENTO_CONF" ]]; then
            echo -e "${RED}❌ 未找到Magento2 nginx配置文件${NC}"
            echo "请手动在你的站点配置中添加以下内容："
            echo ""
            cat << 'EOF'
# Add this to your Magento2 site configuration:
location ~* ^/(admin|admin_[a-z0-9]+)/ {
    modsecurity off;
    try_files $uri $uri/ /index.php$is_args$args;
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
        else
            echo "找到配置文件: $MAGENTO_CONF"
            
            # 备份配置文件
            sudo cp "$MAGENTO_CONF" "${MAGENTO_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # 检查是否已经有admin location
            if grep -q "location.*admin" "$MAGENTO_CONF"; then
                echo -e "${YELLOW}⚠️ 配置文件中已有admin location配置${NC}"
                echo "请手动检查并添加 'modsecurity off;' 指令"
            else
                echo "添加admin区域ModSecurity白名单..."
                # 在http块或server块中添加admin location
                sudo sed -i '/server {/a\\n    # ModSecurity whitelist for admin area\n    location ~* ^/(admin|admin_[a-z0-9]+)/ {\n        modsecurity off;\n        try_files $uri $uri/ /index.php$is_args$args;\n        \n        location ~ \\.php$ {\n            fastcgi_pass unix:/run/php/php8.3-fpm.sock;\n            fastcgi_index index.php;\n            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n            include fastcgi_params;\n        }\n    }' "$MAGENTO_CONF"
            fi
            
            # 测试配置
            if sudo nginx -t; then
                sudo systemctl reload nginx
                echo -e "${GREEN}✅ Admin区域ModSecurity已禁用${NC}"
            else
                echo -e "${RED}❌ Nginx配置测试失败，请检查语法${NC}"
                # 恢复备份
                sudo cp "${MAGENTO_CONF}.backup.$(date +%Y%m%d_%H%M%S)" "$MAGENTO_CONF"
            fi
        fi
        ;;
        
    3)
        echo -e "${BLUE}查看详细拦截日志...${NC}"
        echo "最近20条ModSecurity拦截记录："
        sudo grep -i "ModSecurity: Access denied" /var/log/nginx/error.log | tail -20
        ;;
        
    4)
        echo "退出"
        exit 0
        ;;
        
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎯 修复完成！${NC}"
echo -e "\n${YELLOW}📋 测试步骤:${NC}"
echo "1. 清除浏览器缓存"
echo "2. 重新登录Magento2后台"
echo "3. 测试菜单点击功能"
echo "4. 如果还有问题，查看实时日志: sudo tail -f /var/log/nginx/error.log"

echo -e "\n${YELLOW}💡 提示:${NC}"
echo "• Admin区域禁用ModSecurity是安全的，因为后台有自己的访问控制"
echo "• 前台仍然受到ModSecurity保护"
echo "• 如需恢复，删除添加的location块即可"
