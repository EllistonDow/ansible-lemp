#!/bin/bash
# services-restart.sh
# 重启 Magento 相关服务，支持 Valkey，带颜色输出和详细日志
# 使用方法: ./services-restart.sh [all|service1|service2|...]
# 作者: Ansible LEMP Project
# 版本: 2.1.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
FIRE="🔥"

# 配置
LOG_DIR="/home/doge/Dropbox/logs/services-restart"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
LOG_FILE="$LOG_DIR/services_restart_$(date +%Y%m%d_%H%M%S).log"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 输出到日志和终端
exec > >(tee -a "$LOG_FILE") 2>&1

# 显示标题
echo -e "${CYAN}${ROCKET} Magento 服务重启脚本 v2.1.0${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${INFO_MARK} 开始时间: ${YELLOW}$DATE${NC}"
echo -e "${INFO_MARK} 日志文件: ${YELLOW}$LOG_FILE${NC}"

# 处理命令行参数
if [ $# -eq 0 ]; then
    echo -e "${RED}${CROSS_MARK} 错误: 请指定要重启的服务${NC}"
    echo -e "${YELLOW}使用方法:${NC}"
    echo -e "  ${CYAN}./services-restart.sh all${NC}                    # 重启所有服务"
    echo -e "  ${CYAN}./services-restart.sh mysql nginx${NC}           # 重启指定服务"
    echo -e "  ${CYAN}./services-restart.sh valkey${NC}                # 重启单个服务"
    echo
    echo -e "${YELLOW}可用服务:${NC} mysql, rabbitmq-server, php8.3-fpm, opensearch, valkey, nginx"
    exit 1
fi

# 定义所有可用服务
ALL_SERVICES=("mysql" "rabbitmq-server" "php8.3-fpm" "opensearch" "valkey" "nginx")

# 处理参数
if [ "$1" = "all" ]; then
    SERVICES=("${ALL_SERVICES[@]}")
    echo -e "${INFO_MARK} 模式: ${CYAN}重启所有服务${NC}"
else
    SERVICES=("$@")
    echo -e "${INFO_MARK} 模式: ${CYAN}重启指定服务${NC}"
    
    # 验证服务名称
    for svc in "${SERVICES[@]}"; do
        if [[ ! " ${ALL_SERVICES[*]} " =~ " ${svc} " ]]; then
            echo -e "${RED}${CROSS_MARK} 错误: 未知服务 '$svc'${NC}"
            echo -e "${YELLOW}可用服务:${NC} ${ALL_SERVICES[*]}"
            exit 1
        fi
    done
fi

echo
echo -e "${INFO_MARK} 将重启以下服务: ${CYAN}${SERVICES[*]}${NC}"
echo

echo -e "${BLUE}${GEAR} 开始重启服务...${NC}"
echo

# 重启服务
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SERVICES=()

for svc in "${SERVICES[@]}"; do
    echo -e "${INFO_MARK} 重启服务: ${CYAN}$svc${NC}"
    
    # 检查服务是否存在
    if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then
        echo -e "  ${WARNING_MARK} 服务 $svc 不存在，跳过"
        continue
    fi
    
    # 重启服务
    if sudo systemctl restart "$svc" 2>/dev/null; then
        echo -e "  ${INFO_MARK} 服务重启命令执行成功"
        
        # 等待服务启动
        sleep 3
        
        # 检查服务状态
        if sudo systemctl is-active --quiet "$svc"; then
            echo -e "  ${CHECK_MARK} $svc 启动成功"
            ((SUCCESS_COUNT++))
        else
            echo -e "  ${CROSS_MARK} $svc 启动失败"
            ((FAILED_COUNT++))
            FAILED_SERVICES+=("$svc")
        fi
    else
        echo -e "  ${CROSS_MARK} $svc 重启失败"
        ((FAILED_COUNT++))
        FAILED_SERVICES+=("$svc")
    fi
    
    echo
done

# 显示结果摘要
echo -e "${BLUE}========================================${NC}"
echo -e "${INFO_MARK} 重启完成摘要:"
echo -e "  ${CHECK_MARK} 成功: ${GREEN}$SUCCESS_COUNT${NC} 个服务"
echo -e "  ${CROSS_MARK} 失败: ${RED}$FAILED_COUNT${NC} 个服务"

if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "  ${WARNING_MARK} 失败的服务: ${RED}${FAILED_SERVICES[*]}${NC}"
fi

echo

# 显示服务状态
echo -e "${INFO_MARK} 当前服务状态:"
for svc in "${SERVICES[@]}"; do
    if systemctl is-enabled "$svc" >/dev/null 2>&1; then
        if sudo systemctl is-active --quiet "$svc"; then
            echo -e "  ${CHECK_MARK} $svc: ${GREEN}运行中${NC}"
        else
            echo -e "  ${CROSS_MARK} $svc: ${RED}已停止${NC}"
        fi
    else
        echo -e "  ${WARNING_MARK} $svc: ${YELLOW}未安装${NC}"
    fi
done

echo

# 清理旧日志
echo -e "${INFO_MARK} 清理30天以上日志..."
OLD_LOGS=$(find "$LOG_DIR" -type f -mtime +30 -name "*.log" | wc -l)
if [ $OLD_LOGS -gt 0 ]; then
    find "$LOG_DIR" -type f -mtime +30 -name "*.log" -exec rm -f {} \;
    echo -e "  ${CHECK_MARK} 已清理 $OLD_LOGS 个旧日志文件"
else
    echo -e "  ${INFO_MARK} 没有需要清理的旧日志"
fi

echo
echo -e "${GREEN}${ROCKET} 服务重启完成！${NC}"
echo -e "${INFO_MARK} 结束时间: ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${INFO_MARK} 日志文件: ${YELLOW}$LOG_FILE${NC}"

# 如果有失败的服务，返回非零退出码
if [ $FAILED_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi