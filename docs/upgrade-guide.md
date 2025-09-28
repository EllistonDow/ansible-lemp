# 🔄 LEMP Stack 升级指南

## 从 v1.5.0 升级到 v1.6.3

### ⚠️ **重要警告**
v1.6.x 包含重大更新，特别是：
- RabbitMQ 从 3.x 升级到 4.1.4
- Erlang 从 OTP 25 升级到 OTP 27
- ModSecurity 兼容性修复
- Nginx 配置结构变更

### 📋 **升级前准备**

#### 1. **备份当前系统**
```bash
# 备份重要配置文件
sudo mkdir -p /opt/lemp-upgrade-backup/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/lemp-upgrade-backup/$(date +%Y%m%d_%H%M%S)"

# 备份配置文件
sudo cp -r /etc/nginx/ $BACKUP_DIR/nginx/
sudo cp -r /etc/mysql/ $BACKUP_DIR/mysql/
sudo cp -r /etc/php/ $BACKUP_DIR/php/
sudo cp /etc/rabbitmq/rabbitmq.conf $BACKUP_DIR/ 2>/dev/null || true

# 备份数据库
sudo mysqldump --all-databases > $BACKUP_DIR/all-databases.sql

# 备份 RabbitMQ 数据
sudo rabbitmq-diagnostics export_definitions $BACKUP_DIR/rabbitmq-definitions.json 2>/dev/null || true
```

#### 2. **检查当前版本**
```bash
# 运行检查脚本
./lemp-check.sh v
```

#### 3. **记录当前配置**
```bash
# 记录当前服务状态
systemctl list-units --type=service --state=running | grep -E "(nginx|mysql|php|rabbitmq|opensearch|valkey)" > $BACKUP_DIR/services-status.txt

# 记录当前端口使用
ss -tlnp | grep -E ":80|:443|:3306|:5672|:6379|:9200" > $BACKUP_DIR/ports-status.txt
```

### 🚀 **升级步骤**

#### **步骤 1: 获取最新代码**
```bash
# 在另一台服务器上
cd /path/to/ansible-lemp

# 备份当前版本
cp -r . ../ansible-lemp-v1.5.0-backup

# 拉取最新代码
git fetch origin
git checkout v1.6.3

# 或者重新克隆（推荐）
cd ..
git clone https://github.com/EllistonDow/ansible-lemp.git ansible-lemp-v1.6.3
cd ansible-lemp-v1.6.3
```

#### **步骤 2: RabbitMQ 升级（最关键）**
```bash
# ⚠️ 注意：RabbitMQ 4.1.4 需要 Erlang 26+
# 这是一个破坏性升级，需要小心处理

# 1. 导出 RabbitMQ 配置和数据
sudo rabbitmq-diagnostics export_definitions /tmp/rabbitmq-backup.json

# 2. 停止旧版本 RabbitMQ
sudo systemctl stop rabbitmq-server

# 3. 运行 RabbitMQ 升级
ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=uninstall"
ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=install"

# 4. 导入配置（如果需要）
sudo rabbitmq-diagnostics import_definitions /tmp/rabbitmq-backup.json
```

#### **步骤 3: Nginx 配置升级**
```bash
# 如果你使用了 ModSecurity，这个升级特别重要
ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=true"

# 检查配置
sudo nginx-test
```

#### **步骤 4: 其他组件升级**
```bash
# PHP 组件
ansible-playbook playbooks/php.yml

# 基础工具（包括 phpMyAdmin 修复）
ansible-playbook playbooks/basic-tools.yml

# MySQL/数据库
ansible-playbook playbooks/mysql.yml
```

#### **步骤 5: 验证升级**
```bash
# 运行完整检查
./lemp-check.sh status

# 验证 ModSecurity 工作
curl -I "http://localhost/phpmyadmin/?test=<script>alert('xss')</script>"
# 应该返回 403 Forbidden

# 检查 RabbitMQ
sudo rabbitmqctl status
sudo rabbitmqctl list_users
```

### 🔧 **分步升级方案（推荐）**

如果你担心一次性升级风险太高，建议分步进行：

#### **方案A: 保守升级**
```bash
# 1. 先升级到 v1.6.0（主要处理 RabbitMQ）
git checkout v1.6.0
ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=install"

# 2. 再升级到 v1.6.1（nginx 修复）
git checkout v1.6.1
ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=true"

# 3. 最后升级到 v1.6.3（Magento2 优化器修复）
git checkout v1.6.3
# 这一步主要是脚本更新，不需要重新安装
```

#### **方案B: 新环境迁移**
```bash
# 1. 在新服务器安装 v1.6.3
git clone https://github.com/EllistonDow/ansible-lemp.git
cd ansible-lemp
git checkout v1.6.3

# 2. 全新安装
./scripts/install-all.sh

# 3. 迁移数据和配置
# - 导入数据库
# - 复制网站文件
# - 导入 RabbitMQ 配置
```

### ⚡ **快速升级脚本**

我为你创建一个升级脚本：

```bash
#!/bin/bash
# 创建升级脚本
cat > upgrade-to-1.6.3.sh << 'EOF'
#!/bin/bash
set -e

echo "🔄 开始从 v1.5.0 升级到 v1.6.3..."

# 备份
BACKUP_DIR="/opt/lemp-upgrade-backup/$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p $BACKUP_DIR
echo "📦 备份目录: $BACKUP_DIR"

# 备份关键配置
sudo cp -r /etc/nginx/ $BACKUP_DIR/nginx/ 2>/dev/null || true
sudo cp -r /etc/mysql/ $BACKUP_DIR/mysql/ 2>/dev/null || true
sudo rabbitmq-diagnostics export_definitions $BACKUP_DIR/rabbitmq-backup.json 2>/dev/null || true

# 获取最新代码
git fetch origin
git checkout v1.6.3

# 分步升级
echo "🐰 升级 RabbitMQ..."
ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=install"

echo "🔒 升级 Nginx (包含 ModSecurity)..."
ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=true"

echo "🔧 升级基础工具..."
ansible-playbook playbooks/basic-tools.yml

echo "✅ 升级完成！运行检查..."
./lemp-check.sh status

echo "🎉 升级到 v1.6.3 完成！"
EOF

chmod +x upgrade-to-1.6.3.sh
```

### 📝 **升级后注意事项**

1. **RabbitMQ 端口变更**: 确认端口 5672 和 15672 正常工作
2. **ModSecurity 测试**: 验证 WAF 功能正常
3. **phpMyAdmin 访问**: 确认 http://localhost/phpmyadmin 可访问
4. **Magento2 优化**: 如果使用 Magento2，测试优化脚本保留 ModSecurity

### 🆘 **回滚方案**

如果升级出现问题：

```bash
# 停止服务
sudo systemctl stop nginx mysql php8.3-fpm rabbitmq-server

# 恢复配置
sudo cp -r $BACKUP_DIR/nginx/* /etc/nginx/
sudo cp -r $BACKUP_DIR/mysql/* /etc/mysql/

# 恢复数据库
sudo mysql < $BACKUP_DIR/all-databases.sql

# 重启服务
sudo systemctl start mysql nginx php8.3-fpm

# 如果需要，降级 RabbitMQ
ansible-playbook playbooks/rabbitmq.yml -e "rabbitmq_action=uninstall"
# 然后手动安装旧版本
```

---

**建议：在生产环境升级前，先在测试环境完整测试一遍！** 🧪
