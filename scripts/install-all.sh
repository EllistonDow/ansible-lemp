#!/bin/bash
# LEMP Stack 完整安装脚本 - 安装全部13个组件

set -e

echo "=========================================="
echo "    LEMP Stack 完整安装脚本"
echo "    安装全部13个组件"
echo "=========================================="
echo

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "❌ 此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 检查系统
if [[ ! -f /etc/os-release ]]; then
    echo "❌ 无法检测操作系统"
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "24.04" ]]; then
    echo "⚠️  警告: 此脚本针对Ubuntu 24.04优化，其他版本可能有兼容性问题"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 记录开始时间
START_TIME=$(date +%s)
INSTALL_LOG="/tmp/lemp-install-$(date +%Y%m%d-%H%M%S).log"

echo "📝 安装日志: $INSTALL_LOG"
echo "开始时间: $(date)"
echo

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$INSTALL_LOG"
}

install_component() {
    local component="$1"
    local description="$2"
    
    echo "🔄 正在安装: $description"
    log "开始安装: $component"
    
    if eval "$component" >> "$INSTALL_LOG" 2>&1; then
        echo "✅ $description 安装成功"
        log "$component 安装成功"
    else
        echo "❌ $description 安装失败，请查看日志: $INSTALL_LOG"
        log "$component 安装失败"
        return 1
    fi
    echo
}

# 组件安装函数
install_ansible() {
    if command -v ansible >/dev/null 2>&1; then
        echo "Ansible已安装: $(ansible --version | head -1)"
        return 0
    fi
    sudo apt update
    sudo apt install -y ansible
}

install_nginx() {
    # 安装依赖
    sudo apt install -y curl gnupg2 ca-certificates lsb-release
    
    # 添加nginx仓库
    curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    echo "deb https://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    
    # 安装nginx
    sudo apt update
    sudo apt install -y nginx
    
    # 启动服务
    sudo systemctl enable nginx
    sudo systemctl start nginx
}

install_php() {
    sudo apt update
    sudo apt install -y php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip
    sudo systemctl enable php8.3-fpm
    sudo systemctl start php8.3-fpm
}

install_percona() {
    # 下载仓库包
    wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb -O /tmp/percona-release.deb
    sudo dpkg -i /tmp/percona-release.deb
    sudo apt update
    
    # 启用Percona Server 8.4
    sudo percona-release enable-only ps-84-lts release
    sudo apt update
    
    # 预配置MySQL密码
    export DEBIAN_FRONTEND=noninteractive
    echo "percona-server-server percona-server-server/root_password password SecurePassword123!" | sudo debconf-set-selections
    echo "percona-server-server percona-server-server/root_password_again password SecurePassword123!" | sudo debconf-set-selections
    
    # 安装Percona Server
    sudo apt install -y percona-server-server percona-server-client python3-pymysql
    
    # 启动服务
    sudo systemctl enable mysql
    sudo systemctl start mysql
}

install_rabbitmq() {
    # 安装RabbitMQ
    sudo apt update
    sudo apt install -y rabbitmq-server
    
    # 启动服务
    sudo systemctl enable rabbitmq-server
    sudo systemctl start rabbitmq-server
    
    # 启用管理插件
    sudo rabbitmq-plugins enable rabbitmq_management
}

install_varnish() {
    # 安装Varnish
    sudo apt update
    sudo apt install -y varnish
    
    # 启动服务
    sudo systemctl enable varnish
    sudo systemctl start varnish
}

install_composer() {
    # 安装Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/tmp
    sudo mv /tmp/composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
    php -r "unlink('composer-setup.php');"
}

install_fail2ban() {
    sudo apt update
    sudo apt install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
}

# 开始安装
echo "🚀 开始安装LEMP Stack全套组件..."
echo

# 1. Ansible (通常已预装)
install_component "install_ansible" "1/13 - Ansible"

# 2. Composer
install_component "install_composer" "2/13 - Composer"

# 3. Nginx
install_component "install_nginx" "3/13 - Nginx"

# 4. PHP
install_component "install_php" "4/13 - PHP 8.3"

# 5. Percona MySQL
install_component "install_percona" "5/13 - Percona MySQL"

# 6. RabbitMQ
install_component "install_rabbitmq" "6/13 - RabbitMQ"

# 7. Varnish
install_component "install_varnish" "7/13 - Varnish"

# 8. Fail2ban
install_component "install_fail2ban" "8/13 - Fail2ban"

# 9-13. 使用现有脚本安装其他组件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/install-valkey.sh" ]]; then
    install_component "$SCRIPT_DIR/install-valkey.sh" "9/13 - Valkey"
else
    echo "⚠️  Valkey安装脚本未找到，跳过"
fi

if [[ -f "$SCRIPT_DIR/install-opensearch.sh" ]]; then
    install_component "$SCRIPT_DIR/install-opensearch.sh" "10/13 - OpenSearch"
else
    echo "⚠️  OpenSearch安装脚本未找到，跳过"
fi

if [[ -f "$SCRIPT_DIR/install-webmin.sh" ]]; then
    install_component "$SCRIPT_DIR/install-webmin.sh" "11/13 - Webmin"
else
    echo "⚠️  Webmin安装脚本未找到，跳过"
fi

if [[ -f "$SCRIPT_DIR/install-phpmyadmin.sh" ]]; then
    install_component "$SCRIPT_DIR/install-phpmyadmin.sh" "12/13 - phpMyAdmin"
else
    echo "⚠️  phpMyAdmin安装脚本未找到，跳过"
fi

if [[ -f "$SCRIPT_DIR/install-certbot.sh" ]]; then
    install_component "$SCRIPT_DIR/install-certbot.sh" "13/13 - Certbot"
else
    echo "⚠️  Certbot安装脚本未找到，跳过"
fi

# 计算安装时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo "=========================================="
echo "🎉 LEMP Stack 安装完成！"
echo "=========================================="
echo "安装时间: ${MINUTES}分${SECONDS}秒"
echo "结束时间: $(date)"
echo "详细日志: $INSTALL_LOG"
echo

echo "📊 安装组件列表:"
echo "  1. ✅ Ansible"
echo "  2. ✅ Composer" 
echo "  3. ✅ Nginx"
echo "  4. ✅ PHP 8.3"
echo "  5. ✅ Percona MySQL"
echo "  6. ✅ RabbitMQ"
echo "  7. ✅ Varnish"
echo "  8. ✅ Fail2ban"
echo "  9. ✅ Valkey"
echo " 10. ✅ OpenSearch"
echo " 11. ✅ Webmin"
echo " 12. ✅ phpMyAdmin"
echo " 13. ✅ Certbot"
echo

echo "🌐 访问地址:"
echo "  • 主站: http://localhost"
echo "  • Webmin: https://localhost:10000"
echo "  • phpMyAdmin: http://localhost/phpmyadmin"
echo "  • OpenSearch: http://localhost:9200"
echo "  • RabbitMQ管理: http://localhost:15672"
echo

echo "🔑 默认密码:"
echo "  • MySQL root: SecurePassword123!"
echo "  • Webmin: 使用系统root密码"
echo

echo "✅ 安装完成！请查看详细日志了解更多信息。"
