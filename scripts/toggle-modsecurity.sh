#!/bin/bash
# ModSecurity 级别控制脚本 (0-10级别)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
FIRE="🔥"
SHIELD="🛡️"

NGINX_CONF="/etc/nginx/nginx.conf"
CRS_SETUP="/etc/modsecurity/crs-setup.conf"
BACKUP_DIR="/opt/modsecurity-backups"

# ModSecurity级别配置表
declare -A LEVELS=(
    # 级别 格式: "paranoia_level:inbound_threshold:outbound_threshold:description:color"
    [0]="off:0:0:完全关闭:${RED}"
    [1]="1:50:30:极低敏感度 (仅拦截明显攻击):${GREEN}"
    [2]="1:30:20:低敏感度 (适合生产环境):${GREEN}"
    [3]="1:20:15:中低敏感度 (推荐生产):${CYAN}"
    [4]="1:15:10:中等敏感度 (平衡安全性):${BLUE}"
    [5]="1:10:8:中高敏感度 (增强保护):${BLUE}"
    [6]="2:10:8:高敏感度 (严格模式):${YELLOW}"
    [7]="2:8:6:很高敏感度 (可能误报):${YELLOW}"
    [8]="3:8:6:极高敏感度 (测试环境):${PURPLE}"
    [9]="3:5:4:最高敏感度 (高误报风险):${RED}"
    [10]="4:5:4:超高敏感度 (实验性):${RED}"
)

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "    ModSecurity 级别控制工具 (0-10)"
    echo -e "==============================================${NC}"
    echo
}

show_levels_table() {
    echo -e "${INFO_MARK} ${BLUE}ModSecurity 安全级别说明:${NC}"
    echo
    printf "%-4s %-15s %-15s %-15s %s\n" "级别" "Paranoia" "入站阈值" "出站阈值" "说明"
    echo "────────────────────────────────────────────────────────────────────"
    
    for level in {0..10}; do
        IFS=':' read -r paranoia inbound outbound desc color <<< "${LEVELS[$level]}"
        if [[ $level -eq 0 ]]; then
            printf "%-4s %-15s %-15s %-15s %s\n" "$level" "关闭" "关闭" "关闭" "$desc"
        else
            printf "%-4s %-15s %-15s %-15s %s\n" "$level" "$paranoia" "$inbound" "$outbound" "$desc"
        fi
    done
    echo
}

get_current_level() {
    if ! grep -q "modsecurity on" "$NGINX_CONF" 2>/dev/null; then
        echo "0"
        return
    fi
    
    if [[ ! -f "$CRS_SETUP" ]]; then
        echo "unknown"
        return
    fi
    
    local paranoia=$(grep "setvar:tx.paranoia_level" "$CRS_SETUP" 2>/dev/null | sed -n 's/.*setvar:tx\.paranoia_level=\([0-9]\).*/\1/p' | head -1)
    local inbound=$(grep "setvar:tx.inbound_anomaly_score_threshold" "$CRS_SETUP" 2>/dev/null | sed -n 's/.*setvar:tx\.inbound_anomaly_score_threshold=\([0-9]\+\).*/\1/p' | head -1)
    
    # 根据参数匹配级别
    for level in {1..10}; do
        IFS=':' read -r p_level p_inbound p_outbound p_desc p_color <<< "${LEVELS[$level]}"
        if [[ "$paranoia" == "$p_level" && "$inbound" == "$p_inbound" ]]; then
            echo "$level"
            return
        fi
    done
    
    echo "custom"
}

show_current_status() {
    local current_level=$(get_current_level)
    
    echo -e "${INFO_MARK} ${BLUE}当前ModSecurity状态:${NC}"
    
    if [[ "$current_level" == "0" ]]; then
        echo -e "  ${CROSS_MARK} ${RED}级别 0 - 完全关闭${NC}"
    elif [[ "$current_level" == "unknown" ]]; then
        echo -e "  ${WARNING_MARK} ${YELLOW}未知状态 - 配置文件缺失${NC}"
    elif [[ "$current_level" == "custom" ]]; then
        echo -e "  ${WARNING_MARK} ${YELLOW}自定义配置 - 非标准级别${NC}"
        if [[ -f "$CRS_SETUP" ]]; then
            echo -e "  ${INFO_MARK} 当前参数:"
            grep -E "paranoia_level|anomaly_score_threshold" "$CRS_SETUP" 2>/dev/null | sed 's/^/    /'
        fi
    else
        IFS=':' read -r paranoia inbound outbound desc color <<< "${LEVELS[$current_level]}"
        echo -e "  ${CHECK_MARK} ${color}级别 $current_level - $desc${NC}"
        echo -e "  ${INFO_MARK} Paranoia: $paranoia, 入站阈值: $inbound, 出站阈值: $outbound"
    fi
    
    echo
}

create_backup() {
    sudo mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    sudo cp "$NGINX_CONF" "$BACKUP_DIR/nginx.conf.$timestamp" 2>/dev/null || true
    if [[ -f "$CRS_SETUP" ]]; then
        sudo cp "$CRS_SETUP" "$BACKUP_DIR/crs-setup.conf.$timestamp" 2>/dev/null || true
    fi
    echo -e "  ${CHECK_MARK} 配置已备份: $timestamp"
}

set_modsecurity_level() {
    local level=$1
    
    if [[ ! "${LEVELS[$level]+isset}" ]]; then
        echo -e "${CROSS_MARK} ${RED}错误: 无效级别 '$level'，请使用 0-10${NC}"
        return 1
    fi
    
    IFS=':' read -r paranoia inbound outbound desc color <<< "${LEVELS[$level]}"
    
    echo -e "${INFO_MARK} ${BLUE}设置ModSecurity到级别 $level...${NC}"
    echo -e "  ${INFO_MARK} $desc"
    
    create_backup
    
    if [[ $level -eq 0 ]]; then
        # 级别0：完全关闭
        if grep -q "modsecurity on" "$NGINX_CONF" 2>/dev/null; then
            sudo sed -i 's/modsecurity on/modsecurity off/' "$NGINX_CONF"
        fi
    else
        # 级别1-10：配置相应参数
        
        # 确保ModSecurity启用
        if grep -q "modsecurity off" "$NGINX_CONF" 2>/dev/null; then
            sudo sed -i 's/modsecurity off/modsecurity on/' "$NGINX_CONF"
        elif ! grep -q "modsecurity on" "$NGINX_CONF" 2>/dev/null; then
            # 检查是否加载了模块
            if ! grep -q "load_module.*modsecurity" "$NGINX_CONF"; then
                sudo sed -i '1i load_module modules/ngx_http_modsecurity_module.so;\n' "$NGINX_CONF"
            fi
            # 在http块中添加ModSecurity配置
            sudo sed -i '/^http {/a\\n    # ModSecurity Configuration\n    modsecurity on;\n    modsecurity_rules_file /etc/nginx/modsec/main.conf;' "$NGINX_CONF"
        fi
        
        # 创建CRS配置
        sudo tee "$CRS_SETUP" > /dev/null << EOF
# ModSecurity Level $level Configuration - $desc
# Auto-generated by toggle-modsecurity.sh

SecRuleEngine On
SecRequestBodyAccess On
SecResponseBodyAccess Off

# Paranoia Level: $paranoia
SecAction \\
  "id:900000,\\
   phase:1,\\
   nolog,\\
   pass,\\
   t:none,\\
   setvar:tx.paranoia_level=$paranoia"

# Anomaly Score Thresholds - Level $level
SecAction \\
  "id:900110,\\
   phase:1,\\
   nolog,\\
   pass,\\
   t:none,\\
   setvar:tx.inbound_anomaly_score_threshold=$inbound,\\
   setvar:tx.outbound_anomaly_score_threshold=$outbound"

# CRS Version
SecAction \\
  "id:900990,\\
   phase:1,\\
   nolog,\\
   pass,\\
   t:none,\\
   setvar:tx.crs_setup_version=335"

# Allowed Methods
SecAction \\
  "id:900100,\\
   phase:1,\\
   nolog,\\
   pass,\\
   t:none,\\
   setvar:tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE"

EOF

        # 为低级别添加额外的宽松设置
        if [[ $level -le 3 ]]; then
            cat << 'EOF' | sudo tee -a "$CRS_SETUP" > /dev/null

# Level 1-3: Additional relaxed settings for production
# Magento2 Admin area exclusion
SecRule REQUEST_URI "@beginsWith /admin" \
    "id:900200,phase:1,pass,nolog,ctl:ruleEngine=Off"

# Common false positive exclusions
SecRuleRemoveById 920100 920120 920160 920170 920180
SecRuleRemoveById 941100 941110 941120 941130 941140
SecRuleRemoveById 942100 942110 942150 942180 942200

EOF
        fi
    fi
    
    # 测试配置
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        echo -e "  ${CHECK_MARK} ${GREEN}ModSecurity已设置为级别 $level${NC}"
        
        # 显示级别说明
        case $level in
            0) echo -e "  ${INFO_MARK} ${RED}安全警告: ModSecurity已完全关闭${NC}" ;;
            1-2) echo -e "  ${INFO_MARK} ${GREEN}适合生产环境使用${NC}" ;;
            3-5) echo -e "  ${INFO_MARK} ${BLUE}平衡的安全级别${NC}" ;;
            6-7) echo -e "  ${INFO_MARK} ${YELLOW}高安全级别，可能有误报${NC}" ;;
            8-10) echo -e "  ${INFO_MARK} ${RED}极高安全级别，建议仅用于测试${NC}" ;;
        esac
    else
        echo -e "  ${CROSS_MARK} ${RED}配置测试失败，恢复备份...${NC}"
        # 恢复最新备份
        local latest_backup=$(ls -t "$BACKUP_DIR"/nginx.conf.* 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            sudo cp "$latest_backup" "$NGINX_CONF"
        fi
        return 1
    fi
}

show_recommendations() {
    echo -e "${INFO_MARK} ${YELLOW}级别推荐:${NC}"
    echo -e "  ${GREEN}级别 0${NC}: 临时调试时完全关闭"
    echo -e "  ${GREEN}级别 1-2${NC}: 生产环境推荐 (Magento2/WordPress)"
    echo -e "  ${CYAN}级别 3-4${NC}: 增强安全的生产环境"
    echo -e "  ${BLUE}级别 5-6${NC}: 高安全要求的应用"
    echo -e "  ${YELLOW}级别 7-8${NC}: 测试环境或安全要求极高"
    echo -e "  ${RED}级别 9-10${NC}: 实验性，高误报风险"
    echo
}

interactive_menu() {
    while true; do
        print_header
        show_current_status
        show_levels_table
        show_recommendations
        
        echo -e "${YELLOW}请选择安全级别 (0-10) 或操作:${NC}"
        echo "0-10: 设置对应安全级别"
        echo "s: 显示当前状态"
        echo "h: 显示帮助"
        echo "q: 退出"
        echo
        read -p "请输入选择: " choice
        
        case $choice in
            [0-9]|10)
                set_modsecurity_level "$choice"
                read -p "按Enter继续..."
                ;;
            "s"|"status")
                show_current_status
                read -p "按Enter继续..."
                ;;
            "h"|"help")
                show_levels_table
                show_recommendations
                read -p "按Enter继续..."
                ;;
            "q"|"quit"|"exit")
                echo "退出"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请输入 0-10 或 s/h/q${NC}"
                read -p "按Enter继续..."
                ;;
        esac
    done
}

show_help() {
    echo -e "${YELLOW}用法: $0 [级别|命令]${NC}"
    echo
    echo -e "${YELLOW}级别 (0-10):${NC}"
    echo -e "  ${GREEN}0${NC}     - 完全关闭ModSecurity"
    echo -e "  ${GREEN}1-2${NC}   - 低敏感度 (生产环境推荐)"
    echo -e "  ${GREEN}3-5${NC}   - 中等敏感度"
    echo -e "  ${GREEN}6-8${NC}   - 高敏感度"
    echo -e "  ${GREEN}9-10${NC}  - 极高敏感度 (测试用)"
    echo
    echo -e "${YELLOW}命令:${NC}"
    echo -e "  ${GREEN}status${NC} - 显示当前状态"
    echo -e "  ${GREEN}help${NC}   - 显示此帮助"
    echo -e "  ${GREEN}list${NC}   - 显示级别表格"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0 0        # 关闭ModSecurity"
    echo -e "  $0 2        # 设置为级别2 (生产推荐)"
    echo -e "  $0 5        # 设置为级别5 (中高安全)"
    echo -e "  $0 status   # 查看当前状态"
    echo
}

# 主程序
main() {
    case "${1:-interactive}" in
        [0-9]|10)
            print_header
            set_modsecurity_level "$1"
            echo
            show_current_status
            ;;
        "status"|"s")
            print_header
            show_current_status
            ;;
        "list"|"l")
            print_header
            show_levels_table
            show_recommendations
            ;;
        "help"|"--help"|"-h")
            print_header
            show_help
            ;;
        "interactive"|"")
            interactive_menu
            ;;
        *)
            echo -e "${RED}错误: 无效参数 '$1'${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 检查是否以root权限运行
if [[ $EUID -eq 0 ]]; then
    echo -e "${WARNING_MARK} ${YELLOW}请不要以root身份运行此脚本${NC}"
    echo "使用: ./toggle-modsecurity.sh [0-10|命令]"
    exit 1
fi

# 运行主程序
main "$@"