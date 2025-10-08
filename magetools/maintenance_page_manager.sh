#!/bin/bash

# Magento维护页面管理系统
# 用法: ./maintenance_page_manager.sh [命令] [参数]

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目路径
PROJECT_ROOT="/home/doge/ansible-lemp"
MAINTENANCE_DIR="$PROJECT_ROOT/magetools/maintenance-page-design"
TEMPLATE_DIR="$MAINTENANCE_DIR/2025"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}🎨 Magento维护页面管理系统${NC}"
    echo "================================================"
    echo ""
    echo -e "${YELLOW}用法:${NC}"
    echo " $0 [命令] [参数]"
    echo ""
    echo -e "${YELLOW}命令:${NC}"
    echo "  install [网站名]           - 安装维护页面到指定网站"
    echo "  install-all               - 安装到所有网站"
    echo "  enable [网站名]           - 启用维护模式"
    echo "  disable [网站名]          - 禁用维护模式"
    echo "  status [网站名]            - 查看维护模式状态"
    echo "  list                      - 列出所有网站"
    echo "  template-info             - 显示模板信息"
    echo "  update-template           - 从hawk更新模板"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo " $0 install ipwa"
    echo " $0 install-all"
    echo " $0 enable ipwa"
    echo " $0 disable ipwa"
    echo " $0 status ipwa"
    echo ""
    echo -e "${CYAN}💡 说明:${NC}"
    echo " 此工具管理Magento网站的维护页面"
    echo " 支持暗黑模式、动画效果、移动端适配"
}

# 检查模板是否存在
check_template() {
    if [ ! -f "$TEMPLATE_DIR/503.phtml" ]; then
        echo -e "${RED}❌ 模板文件不存在: $TEMPLATE_DIR/503.phtml${NC}"
        echo -e "${YELLOW}💡 请先运行: $0 update-template${NC}"
        return 1
    fi
    return 0
}

# 获取所有网站列表
get_sites() {
    find /home/doge -maxdepth 1 -type d -name "*" | grep -v "^/home/doge$" | sed 's|/home/doge/||' | sort
}

# 检查网站是否为Magento
is_magento_site() {
    local site_path="/home/doge/$1"
    [ -f "$site_path/bin/magento" ]
}

# 安装维护页面到指定网站
install_maintenance_page() {
    local site="$1"
    local site_path="/home/doge/$site"
    
    echo -e "${CYAN}📁 安装维护页面到: $site${NC}"
    
    # 检查网站是否存在
    if [ ! -d "$site_path" ]; then
        echo -e "${RED}❌ 网站目录不存在: $site_path${NC}"
        return 1
    fi
    
    # 检查是否为Magento网站
    if ! is_magento_site "$site"; then
        echo -e "${RED}❌ 不是Magento网站: $site${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ 找到Magento网站: $site_path${NC}"
    
    # 创建错误页面目录
    local error_dir="$site_path/pub/errors/2025"
    echo -e "${YELLOW}📂 创建目录: $error_dir${NC}"
    mkdir -p "$error_dir"
    
    # 复制维护页面文件
    echo -e "${YELLOW}📋 复制维护页面...${NC}"
    cp "$TEMPLATE_DIR/503.phtml" "$error_dir/503.phtml"
    
    # 创建配置文件
    echo -e "${YELLOW}⚙️ 创建配置文件...${NC}"
    cat > "$site_path/pub/errors/local.xml" << 'EOF'
<?xml version="1.0"?>
<!--
/**
 * Copyright © Magento, Inc. All rights reserved.
 * See COPYING.txt for license details.
 */
-->
<config>
    <skin>2025</skin>
    <report>
        <action>print</action>
        <subject>Store Debug Information</subject>
        <email_address></email_address>
        <trash>leave</trash>
        <dir_nesting_level>0</dir_nesting_level>
    </report>
</config>
EOF
    
    # 设置文件权限
    echo -e "${YELLOW}🔐 设置文件权限...${NC}"
    chown -R www-data:www-data "$error_dir"
    chmod -R 755 "$error_dir"
    chown www-data:www-data "$site_path/pub/errors/local.xml"
    chmod 644 "$site_path/pub/errors/local.xml"
    
    # 验证安装
    if [ -f "$error_dir/503.phtml" ] && [ -f "$site_path/pub/errors/local.xml" ]; then
        echo -e "${GREEN}✅ $site 维护页面安装完成${NC}"
        
        # 显示配置信息
        echo -e "${BLUE}📋 配置信息:${NC}"
        echo "  维护页面: $error_dir/503.phtml"
        echo "  配置文件: $site_path/pub/errors/local.xml"
        echo "  主题设置: 2025"
        
        return 0
    else
        echo -e "${RED}❌ $site 安装失败${NC}"
        return 1
    fi
}

# 安装到所有网站
install_all() {
    echo -e "${BLUE}🚀 批量安装维护页面${NC}"
    echo "================================================"
    
    local sites=($(get_sites))
    local success_count=0
    local total_count=0
    
    for site in "${sites[@]}"; do
        if is_magento_site "$site"; then
            total_count=$((total_count + 1))
            echo ""
            if install_maintenance_page "$site"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    echo ""
    echo -e "${BLUE}📊 安装统计:${NC}"
    echo "  成功: $success_count"
    echo "  失败: $((total_count - success_count))"
    echo "  总计: $total_count"
}

# 启用维护模式
enable_maintenance() {
    local site="$1"
    local site_path="/home/doge/$site"
    
    if [ ! -d "$site_path" ]; then
        echo -e "${RED}❌ 网站目录不存在: $site_path${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔒 启用维护模式: $site${NC}"
    cd "$site_path"
    php bin/magento maintenance:enable
    echo -e "${GREEN}✅ 维护模式已启用${NC}"
}

# 禁用维护模式
disable_maintenance() {
    local site="$1"
    local site_path="/home/doge/$site"
    
    if [ ! -d "$site_path" ]; then
        echo -e "${RED}❌ 网站目录不存在: $site_path${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🔓 禁用维护模式: $site${NC}"
    cd "$site_path"
    php bin/magento maintenance:disable
    echo -e "${GREEN}✅ 维护模式已禁用${NC}"
}

# 查看维护模式状态
show_status() {
    local site="$1"
    local site_path="/home/doge/$site"
    
    if [ ! -d "$site_path" ]; then
        echo -e "${RED}❌ 网站目录不存在: $site_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 维护模式状态: $site${NC}"
    cd "$site_path"
    php bin/magento maintenance:status
}

# 列出所有网站
list_sites() {
    echo -e "${BLUE}📋 网站列表${NC}"
    echo "================================================"
    
    local sites=($(get_sites))
    local magento_count=0
    
    for site in "${sites[@]}"; do
        if is_magento_site "$site"; then
            magento_count=$((magento_count + 1))
            echo -e "${GREEN}✅ $site${NC} (Magento)"
        else
            echo -e "${YELLOW}⚠️  $site${NC} (非Magento)"
        fi
    done
    
    echo ""
    echo -e "${BLUE}📊 统计:${NC}"
    echo "  Magento网站: $magento_count"
    echo "  总网站数: ${#sites[@]}"
}

# 显示模板信息
show_template_info() {
    echo -e "${BLUE}🎨 维护页面模板信息${NC}"
    echo "================================================"
    
    if [ ! -f "$TEMPLATE_DIR/503.phtml" ]; then
        echo -e "${RED}❌ 模板文件不存在${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ 模板文件: $TEMPLATE_DIR/503.phtml${NC}"
    echo -e "${CYAN}📋 模板特性:${NC}"
    echo "  • 暗黑模式设计"
    echo "  • 透明玻璃效果"
    echo "  • 丰富的动画效果"
    echo "  • 移动端适配"
    echo "  • 5分钟倒计时"
    echo "  • 联系邮箱: magento@tschenfeng.com"
    echo "  • HTML5标准"
    echo "  • 响应式设计"
    
    echo ""
    echo -e "${YELLOW}📊 文件信息:${NC}"
    ls -lh "$TEMPLATE_DIR/503.phtml"
}

# 从hawk更新模板
update_template() {
    echo -e "${YELLOW}🔄 从hawk更新模板...${NC}"
    
    local hawk_template="/home/doge/hawk/pub/errors/2025/503.phtml"
    
    if [ ! -f "$hawk_template" ]; then
        echo -e "${RED}❌ Hawk模板不存在: $hawk_template${NC}"
        echo -e "${YELLOW}💡 请先在hawk网站创建2025维护页面${NC}"
        return 1
    fi
    
    # 创建目录
    mkdir -p "$TEMPLATE_DIR"
    
    # 复制模板
    cp "$hawk_template" "$TEMPLATE_DIR/503.phtml"
    
    # 设置权限
    chmod 644 "$TEMPLATE_DIR/503.phtml"
    
    echo -e "${GREEN}✅ 模板更新完成${NC}"
    echo -e "${BLUE}📋 模板位置: $TEMPLATE_DIR/503.phtml${NC}"
}

# 主逻辑
case "$1" in
    "install")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ 请指定网站名${NC}"
            echo -e "${YELLOW}用法: $0 install [网站名]${NC}"
            exit 1
        fi
        if ! check_template; then
            exit 1
        fi
        install_maintenance_page "$2"
        ;;
    "install-all")
        if ! check_template; then
            exit 1
        fi
        install_all
        ;;
    "enable")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ 请指定网站名${NC}"
            echo -e "${YELLOW}用法: $0 enable [网站名]${NC}"
            exit 1
        fi
        enable_maintenance "$2"
        ;;
    "disable")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ 请指定网站名${NC}"
            echo -e "${YELLOW}用法: $0 disable [网站名]${NC}"
            exit 1
        fi
        disable_maintenance "$2"
        ;;
    "status")
        if [ -z "$2" ]; then
            echo -e "${RED}❌ 请指定网站名${NC}"
            echo -e "${YELLOW}用法: $0 status [网站名]${NC}"
            exit 1
        fi
        show_status "$2"
        ;;
    "list")
        list_sites
        ;;
    "template-info")
        show_template_info
        ;;
    "update-template")
        update_template
        ;;
    *)
        show_help
        ;;
esac
