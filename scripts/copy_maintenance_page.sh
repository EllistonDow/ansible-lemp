#!/bin/bash

# 复制2025维护页面到其他网站的脚本
# 用法: ./copy_maintenance_page.sh [目标网站1] [目标网站2] ...

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 源文件路径
SOURCE_FILE="/home/doge/hawk/pub/errors/2025/503.phtml"
SOURCE_CONFIG="/home/doge/hawk/pub/errors/local.xml"

# 检查源文件是否存在
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}❌ 源文件不存在: $SOURCE_FILE${NC}"
    exit 1
fi

if [ ! -f "$SOURCE_CONFIG" ]; then
    echo -e "${RED}❌ 源配置文件不存在: $SOURCE_CONFIG${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 2025维护页面复制工具${NC}"
echo "================================================"

# 如果没有提供参数，显示帮助
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}用法:${NC} $0 [网站1] [网站2] [网站3] ..."
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo " $0 ipwa sava bdgy ntca"
    echo " $0 papa ambi"
    echo ""
    echo -e "${CYAN}💡 说明:${NC}"
    echo " 此脚本会："
    echo " 1. 创建目标网站的 2025 错误页面目录"
    echo " 2. 复制维护页面文件"
    echo " 3. 更新错误页面配置"
    echo " 4. 设置正确的文件权限"
    exit 1
fi

# 处理每个目标网站
for SITE in "$@"; do
    echo ""
    echo -e "${CYAN}📁 处理网站: $SITE${NC}"
    
    # 检查网站目录是否存在
    SITE_PATH="/home/doge/$SITE"
    if [ ! -d "$SITE_PATH" ]; then
        echo -e "${RED}❌ 网站目录不存在: $SITE_PATH${NC}"
        continue
    fi
    
    # 检查是否为Magento网站
    if [ ! -f "$SITE_PATH/bin/magento" ]; then
        echo -e "${RED}❌ 不是Magento网站: $SITE_PATH${NC}"
        continue
    fi
    
    echo -e "${GREEN}✅ 找到Magento网站: $SITE_PATH${NC}"
    
    # 创建2025错误页面目录
    ERROR_DIR="$SITE_PATH/pub/errors/2025"
    echo -e "${YELLOW}📂 创建目录: $ERROR_DIR${NC}"
    mkdir -p "$ERROR_DIR"
    
    # 复制维护页面文件
    echo -e "${YELLOW}📋 复制维护页面...${NC}"
    cp "$SOURCE_FILE" "$ERROR_DIR/503.phtml"
    
    # 复制配置文件
    echo -e "${YELLOW}⚙️ 更新错误页面配置...${NC}"
    cp "$SOURCE_CONFIG" "$SITE_PATH/pub/errors/local.xml"
    
    # 设置文件权限
    echo -e "${YELLOW}🔐 设置文件权限...${NC}"
    chown -R www-data:www-data "$ERROR_DIR"
    chmod -R 755 "$ERROR_DIR"
    chown www-data:www-data "$SITE_PATH/pub/errors/local.xml"
    chmod 644 "$SITE_PATH/pub/errors/local.xml"
    
    # 验证文件
    if [ -f "$ERROR_DIR/503.phtml" ] && [ -f "$SITE_PATH/pub/errors/local.xml" ]; then
        echo -e "${GREEN}✅ $SITE 配置完成${NC}"
        
        # 显示配置信息
        echo -e "${BLUE}📋 配置信息:${NC}"
        echo "  维护页面: $ERROR_DIR/503.phtml"
        echo "  配置文件: $SITE_PATH/pub/errors/local.xml"
        echo "  主题设置: 2025"
        
        # 显示测试命令
        echo -e "${YELLOW}🧪 测试命令:${NC}"
        echo "  cd $SITE_PATH && php bin/magento maintenance:enable"
        echo "  cd $SITE_PATH && php bin/magento maintenance:disable"
        
    else
        echo -e "${RED}❌ $SITE 配置失败${NC}"
    fi
done

echo ""
echo -e "${BLUE}🎉 批量配置完成！${NC}"
echo "================================================"
echo -e "${YELLOW}💡 使用说明:${NC}"
echo "1. 启用维护模式: cd /home/doge/[网站名] && php bin/magento maintenance:enable"
echo "2. 禁用维护模式: cd /home/doge/[网站名] && php bin/magento maintenance:disable"
echo "3. 查看维护状态: cd /home/doge/[网站名] && php bin/magento maintenance:status"
echo ""
echo -e "${CYAN}🔧 维护页面特性:${NC}"
echo "• 暗黑模式设计"
echo "• 透明玻璃效果"
echo "• 动画效果"
echo "• 移动端适配"
echo "• 5分钟倒计时"
echo "• 联系邮箱: magento@tschenfeng.com"
