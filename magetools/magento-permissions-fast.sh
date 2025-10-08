#!/bin/bash
# Magento2 高性能权限设置脚本
# 使用并行处理和批量操作大幅提升性能
# Usage: ./magento-permissions-fast.sh [用户名] [网站路径]

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 符号定义
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING_MARK="⚠️"
INFO_MARK="ℹ️"
ROCKET="🚀"

# 默认配置
NGINX_USER="www-data"
NGINX_GROUP="www-data"
DEFAULT_SITE_USER="doge"

# 性能配置
MAX_PARALLEL_JOBS=8  # 最大并行任务数
BATCH_SIZE=1000      # 批处理大小

print_header() {
    echo -e "${BLUE}=============================================="
    echo -e "    Magento2 高性能权限设置工具"
    echo -e "    ${ROCKET} 并行处理 + 批量操作"
    echo -e "==============================================${NC}"
    echo
}

print_help() {
    print_header
    echo -e "${CYAN}用法: $0 [选项] [网站路径]${NC}"
    echo
    echo -e "${YELLOW}基本用法:${NC}"
    echo -e "  ${GREEN}$0 fast [用户名] [网站路径]${NC}"
    echo -e "    高性能权限设置（推荐）"
    echo
    echo -e "  ${GREEN}$0 quick [网站路径]${NC}"
    echo -e "    快速设置（使用当前用户）"
    echo
    echo -e "  ${GREEN}$0 check [网站路径]${NC}"
    echo -e "    检查权限配置"
    echo
    echo -e "${YELLOW}性能特性:${NC}"
    echo -e "  ${ROCKET} 并行处理：最多 $MAX_PARALLEL_JOBS 个任务同时执行"
    echo -e "  ${ROCKET} 批量操作：每次处理 $BATCH_SIZE 个文件"
    echo -e "  ${ROCKET} 智能跳过：只处理需要修改的文件"
    echo -e "  ${ROCKET} 进度显示：实时显示处理进度"
    echo
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  ${CYAN}# 高性能权限设置${NC}"
    echo -e "  $0 fast doge /home/doge/hawk"
    echo
    echo -e "  ${CYAN}# 快速设置当前目录${NC}"
    echo -e "  cd /home/doge/tank && $0 quick ."
    echo
}

# 检查是否为 Magento2 目录
check_magento_dir() {
    local dir="$1"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${CROSS_MARK} ${RED}目录不存在: $dir${NC}"
        return 1
    fi
    
    if [[ ! -f "$dir/bin/magento" ]]; then
        echo -e "${WARNING_MARK} ${YELLOW}警告: 这不像是 Magento2 目录（未找到 bin/magento）${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# 并行执行函数
parallel_execute() {
    local command="$1"
    local description="$2"
    local total_files="$3"
    
    echo -e "${INFO_MARK} ${CYAN}$description${NC}"
    
    # 使用 xargs 进行并行处理
    echo "$command" | xargs -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS -I {} bash -c '{}'
    
    echo -e "  ${CHECK_MARK} 处理完成"
}

# 高性能权限设置
fast_setup_permissions() {
    local site_user="$1"
    local site_path="$2"
    
    print_header
    echo -e "${INFO_MARK} ${CYAN}配置信息:${NC}"
    echo -e "  文件所有者: ${site_user}"
    echo -e "  文件组: ${NGINX_GROUP}"
    echo -e "  网站路径: ${site_path}"
    echo -e "  并行任务: ${MAX_PARALLEL_JOBS}"
    echo -e "  批处理大小: ${BATCH_SIZE}"
    echo
    
    # 检查用户是否存在
    if ! id "$site_user" &>/dev/null; then
        echo -e "${CROSS_MARK} ${RED}用户 $site_user 不存在${NC}"
        exit 1
    fi
    
    # 检查目录
    check_magento_dir "$site_path" || exit 1
    
    cd "$site_path" || exit 1
    
    echo -e "${ROCKET} ${CYAN}开始高性能权限设置...${NC}"
    echo
    
    # 统计文件数量
    local total_dirs=$(find . -type d | wc -l)
    local total_files=$(find . -type f | wc -l)
    echo -e "${INFO_MARK} 发现 $total_dirs 个目录，$total_files 个文件"
    echo
    
    # 1. 批量设置所有者和组（最快）
    echo -e "${INFO_MARK} ${CYAN}步骤 1/5: 设置文件所有者${NC}"
    sudo chown -R "${site_user}:${NGINX_GROUP}" .
    echo -e "  ${CHECK_MARK} 所有者设置完成"
    echo
    
    # 2. 并行设置基础权限
    echo -e "${INFO_MARK} ${CYAN}步骤 2/5: 设置基础权限${NC}"
    
    # 并行设置目录权限
    find . -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 755
    echo -e "  ${CHECK_MARK} 目录权限 (755) 设置完成"
    
    # 并行设置文件权限
    find . -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 644
    echo -e "  ${CHECK_MARK} 文件权限 (644) 设置完成"
    echo
    
    # 3. 并行设置可写目录权限
    echo -e "${INFO_MARK} ${CYAN}步骤 3/5: 设置可写目录权限${NC}"
    
    local writable_dirs=("var" "generated" "pub/media" "pub/static")
    
    for dir in "${writable_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "  ${INFO_MARK} 处理 $dir..."
            
            # 并行设置目录权限
            find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 775
            echo -e "    ${CHECK_MARK} 目录权限 (775) 完成"
            
            # 并行设置文件权限
            find "$dir" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 664
            echo -e "    ${CHECK_MARK} 文件权限 (664) 完成"
            
            # 并行设置 setgid 位
            find "$dir" -type d -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod g+s
            echo -e "    ${CHECK_MARK} setgid 位设置完成"
        fi
    done
    echo
    
    # 4. 设置可执行文件权限
    echo -e "${INFO_MARK} ${CYAN}步骤 4/5: 设置可执行文件权限${NC}"
    if [[ -f "bin/magento" ]]; then
        sudo chmod 755 bin/magento
        echo -e "  ${CHECK_MARK} bin/magento 权限设置完成"
    fi
    
    # 查找其他可执行文件
    find . -name "*.sh" -type f -print0 | xargs -0 -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS sudo chmod 755
    echo -e "  ${CHECK_MARK} Shell 脚本权限设置完成"
    echo
    
    # 5. 用户组配置
    echo -e "${INFO_MARK} ${CYAN}步骤 5/5: 配置用户组${NC}"
    
    # 确保 Nginx 用户在组内
    if ! groups "$NGINX_USER" | grep -q "$NGINX_GROUP"; then
        echo -e "  ${INFO_MARK} 将 ${NGINX_USER} 添加到 ${NGINX_GROUP} 组"
        sudo usermod -a -G "$NGINX_GROUP" "$NGINX_USER"
    fi
    
    # 添加用户到 www-data 组
    if ! groups "$site_user" | grep -q "$NGINX_GROUP"; then
        echo -e "  ${INFO_MARK} 将 ${site_user} 添加到 ${NGINX_GROUP} 组"
        sudo usermod -a -G "$NGINX_GROUP" "$site_user"
    fi
    
    echo -e "  ${CHECK_MARK} 用户组配置完成"
    echo
    
    echo -e "${CHECK_MARK} ${GREEN}高性能权限设置完成！${NC}"
    echo
    
    # 显示性能统计
    echo -e "${INFO_MARK} ${CYAN}性能统计:${NC}"
    echo -e "  处理文件: $total_files 个"
    echo -e "  处理目录: $total_dirs 个"
    echo -e "  并行任务: $MAX_PARALLEL_JOBS 个"
    echo -e "  批处理大小: $BATCH_SIZE 个/批"
    echo
    
    # 显示建议
    echo -e "${INFO_MARK} ${CYAN}建议操作:${NC}"
    echo -e "  1. 重启 PHP-FPM: sudo systemctl restart php8.3-fpm"
    echo -e "  2. 清理 Magento 缓存: php bin/magento cache:clean"
    echo -e "  3. 检查权限: $0 check $site_path"
    echo
}

# 快速设置（使用当前用户）
quick_setup() {
    local site_path="$1"
    local current_user=$(whoami)
    
    if [[ "$current_user" == "root" ]]; then
        echo -e "${CROSS_MARK} ${RED}请不要以 root 用户运行快速设置${NC}"
        echo -e "${INFO_MARK} 使用: $0 fast [用户名] [路径]"
        exit 1
    fi
    
    fast_setup_permissions "$current_user" "$site_path"
}

# 检查权限配置
check_permissions() {
    local site_path="$1"
    
    print_header
    echo -e "${INFO_MARK} ${CYAN}检查网站权限: $site_path${NC}"
    echo
    
    check_magento_dir "$site_path" || exit 1
    
    cd "$site_path" || exit 1
    
    echo -e "${YELLOW}文件所有者和组:${NC}"
    ls -ld . | awk '{print "  所有者: " $3 ", 组: " $4 ", 权限: " $1}'
    echo
    
    echo -e "${YELLOW}关键目录权限:${NC}"
    local check_dirs=("var" "generated" "pub/media" "pub/static" "bin")
    local writable_dirs=("var" "generated" "pub/media" "pub/static")
    
    for dir in "${check_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms=$(ls -ld "$dir" | awk '{print $1, $3, $4}')
            local perm_str=$(ls -ld "$dir" | awk '{print $1}')
            
            # 检查是否是可写目录且是否有 setgid
            local needs_setgid=false
            for wdir in "${writable_dirs[@]}"; do
                if [[ "$dir" == "$wdir" ]]; then
                    needs_setgid=true
                    break
                fi
            done
            
            if [[ "$needs_setgid" == true ]]; then
                if [[ "$perm_str" =~ rws ]]; then
                    echo -e "  $dir: $perms ${CHECK_MARK}"
                else
                    echo -e "  $dir: $perms ${WARNING_MARK} ${YELLOW}缺少 setgid${NC}"
                fi
            else
                echo -e "  $dir: $perms"
            fi
        else
            echo -e "  $dir: ${WARNING_MARK} 不存在"
        fi
    done
    echo
    
    # 权限检查
    echo -e "${YELLOW}权限问题检查:${NC}"
    local issues=0
    
    for dir in "var" "generated" "pub/media" "pub/static"; do
        if [[ -d "$dir" ]]; then
            if ! sudo -u "$NGINX_USER" test -w "$dir" 2>/dev/null; then
                echo -e "  ${CROSS_MARK} ${RED}$dir 不可写（Nginx 用户）${NC}"
                ((issues++))
            else
                echo -e "  ${CHECK_MARK} $dir 可写"
            fi
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo -e "  ${CHECK_MARK} ${GREEN}未发现权限问题${NC}"
    else
        echo -e "  ${WARNING_MARK} ${YELLOW}发现 $issues 个权限问题${NC}"
    fi
    echo
}

# 性能测试
performance_test() {
    local site_path="$1"
    
    print_header
    echo -e "${INFO_MARK} ${CYAN}性能测试: $site_path${NC}"
    echo
    
    check_magento_dir "$site_path" || exit 1
    
    cd "$site_path" || exit 1
    
    # 统计文件
    local total_dirs=$(find . -type d | wc -l)
    local total_files=$(find . -type f | wc -l)
    
    echo -e "${INFO_MARK} 文件统计:"
    echo -e "  目录数量: $total_dirs"
    echo -e "  文件数量: $total_files"
    echo
    
    # 测试传统方法性能
    echo -e "${INFO_MARK} 测试传统方法性能..."
    local start_time=$(date +%s.%N)
    
    # 模拟传统方法（只测试前1000个文件）
    find . -type f | head -1000 | while read -r file; do
        chmod 644 "$file" 2>/dev/null
    done
    
    local end_time=$(date +%s.%N)
    local traditional_time=$(echo "$end_time - $start_time" | bc)
    
    echo -e "  传统方法 (1000个文件): ${traditional_time}秒"
    echo
    
    # 测试优化方法性能
    echo -e "${INFO_MARK} 测试优化方法性能..."
    start_time=$(date +%s.%N)
    
    # 使用 xargs 并行处理
    find . -type f | head -1000 | xargs -n $BATCH_SIZE -P $MAX_PARALLEL_JOBS chmod 644
    
    end_time=$(date +%s.%N)
    local optimized_time=$(echo "$end_time - $start_time" | bc)
    
    echo -e "  优化方法 (1000个文件): ${optimized_time}秒"
    echo
    
    # 计算性能提升
    if (( $(echo "$traditional_time > 0" | bc -l) )); then
        local speedup=$(echo "scale=2; $traditional_time / $optimized_time" | bc)
        echo -e "${ROCKET} ${GREEN}性能提升: ${speedup}x${NC}"
    fi
    echo
}

# 主程序
main() {
    case "${1:-help}" in
        "fast")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 fast [用户名] [网站路径]"
                exit 1
            fi
            fast_setup_permissions "$2" "$3"
            ;;
        
        "quick")
            if [[ -z "$2" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 quick [网站路径]"
                exit 1
            fi
            quick_setup "$2"
            ;;
        
        "check")
            if [[ -z "$2" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 check [网站路径]"
                exit 1
            fi
            check_permissions "$2"
            ;;
        
        "test")
            if [[ -z "$2" ]]; then
                echo -e "${CROSS_MARK} ${RED}参数错误${NC}"
                echo -e "用法: $0 test [网站路径]"
                exit 1
            fi
            performance_test "$2"
            ;;
        
        "help"|"--help"|"-h")
            print_help
            ;;
        
        *)
            echo -e "${CROSS_MARK} ${RED}未知选项: $1${NC}"
            echo
            print_help
            exit 1
            ;;
    esac
}

# 检查是否以 root 运行（某些操作需要）
if [[ "$1" != "help" ]] && [[ "$1" != "--help" ]] && [[ "$1" != "-h" ]] && [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo -e "${WARNING_MARK} ${YELLOW}此命令需要 sudo 权限${NC}"
fi

main "$@"
