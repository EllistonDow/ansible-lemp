# LEMP Stack 完整安装指南

## 📋 总览

此项目提供完整的LEMP (Linux, Nginx, MySQL/Percona, PHP) 环境安装，包含13个核心组件的自动化安装。

### ✅ 已安装组件 (13/13)

| 序号 | 组件 | 版本 | 状态 | Playbook | 独立脚本 |
|-----|------|------|------|----------|----------|
| 1 | **Ansible** | 2.16.3 | ✅ 运行中 | - | - |
| 2 | **Composer** | 2.8.12 | ✅ 已安装 | `basic-tools.yml` | - |
| 3 | **OpenSearch** | 2.19.0 | ✅ 运行中 | `opensearch.yml` | `install-opensearch.sh` |
| 4 | **Percona MySQL** | 8.4.6-6 | ✅ 运行中 | `percona.yml` | - |
| 5 | **PHP** | 8.3.6 | ✅ 运行中 | `php.yml` | - |
| 6 | **RabbitMQ** | 4.1 | ✅ 运行中 | `rabbitmq.yml` | - |
| 7 | **Valkey** | 8 | ✅ 运行中 | `valkey.yml` | `install-valkey.sh` |
| 8 | **Varnish** | 7.6 | ✅ 运行中 | `varnish.yml` | - |
| 9 | **Nginx** | 1.28.0 | ✅ 运行中 | `nginx.yml` | - |
| 10 | **Fail2ban** | Latest | ✅ 运行中 | `basic-tools.yml` | - |
| 11 | **Webmin** | 2.200 | ✅ 运行中 | `basic-tools.yml` | `install-webmin.sh` |
| 12 | **phpMyAdmin** | 5.2.1 | ✅ 已配置 | `basic-tools.yml` | `install-phpmyadmin.sh` |
| 13 | **Certbot** | 5.0.0 | ✅ 已安装 | `basic-tools.yml` | `install-certbot.sh` |

## 🚀 使用方法

### 方法一: Ansible Playbook 安装

#### 完整安装 (推荐)
```bash
cd /home/doge/ansible-lemp
ansible-playbook playbooks/site.yml
```

#### 单独组件安装
```bash
# 安装Nginx
ansible-playbook playbooks/nginx.yml

# 安装OpenSearch
ansible-playbook playbooks/opensearch.yml

# 安装Valkey
ansible-playbook playbooks/valkey.yml

# 安装基础工具 (Composer, Fail2ban, Webmin, phpMyAdmin, Certbot)
ansible-playbook playbooks/basic-tools.yml
```

### 方法二: 独立脚本安装

```bash
cd /home/doge/ansible-lemp/scripts

# 安装OpenSearch
./install-opensearch.sh

# 安装Valkey
./install-valkey.sh

# 安装Webmin
./install-webmin.sh

# 安装phpMyAdmin
./install-phpmyadmin.sh

# 安装Certbot
./install-certbot.sh
```

## 🔧 特殊功能

### Nginx + ModSecurity
- **版本**: Nginx 1.28.0 + ModSecurity v1.0.4
- **功能**: Web应用防火墙，SQL注入防护，XSS攻击检测
- **规则**: OWASP CRS v3.3.5 (917条规则)
- **测试**: 
  ```bash
  # 正常访问
  curl http://localhost
  
  # 攻击测试 (会被阻止)
  curl "http://localhost/?test=<script>alert('xss')</script>"
  ```

### MySQL高可用
- **版本**: Percona Server 8.4.6-6
- **功能**: 企业级MySQL分支，性能优化
- **配置**: 已优化安全设置，支持SSL

## 🌐 访问地址

| 服务 | 地址 | 端口 | 备注 |
|------|------|------|------|
| **Nginx** | http://localhost | 80 | 主Web服务器 |
| **OpenSearch** | http://localhost:9200 | 9200 | 搜索引擎 |
| **Webmin** | https://localhost:10000 | 10000 | 系统管理 |
| **phpMyAdmin** | http://localhost/phpmyadmin | 80 | 数据库管理 |
| **RabbitMQ** | http://localhost:15672 | 15672 | 消息队列管理 |
| **Varnish** | - | 6081 | HTTP缓存 |

## 🔑 默认账户

| 服务 | 用户名 | 密码 | 备注 |
|------|--------|------|------|
| **MySQL** | root | `SecurePassword123!` | 可在配置中修改 |
| **Webmin** | root | 系统root密码 | 使用系统账户 |
| **phpMyAdmin** | - | 使用MySQL账户 | 需要数据库权限 |

## 📁 目录结构

```
ansible-lemp/
├── playbooks/          # Ansible Playbooks
│   ├── site.yml        # 主安装脚本
│   ├── nginx.yml       # Nginx安装
│   ├── opensearch.yml  # OpenSearch安装
│   ├── valkey.yml      # Valkey安装
│   └── ...
├── roles/              # Ansible角色
│   ├── nginx/          # Nginx角色
│   ├── opensearch/     # OpenSearch角色
│   ├── valkey/         # Valkey角色
│   └── ...
├── scripts/            # 独立安装脚本
│   ├── install-opensearch.sh
│   ├── install-valkey.sh
│   ├── install-webmin.sh
│   ├── install-phpmyadmin.sh
│   └── install-certbot.sh
└── group_vars/         # 全局变量
    └── all.yml
```

## 🛠️ 故障排除

### 服务状态检查
```bash
# 检查所有服务状态
sudo systemctl status nginx php8.3-fpm mysql opensearch valkey varnish rabbitmq-server fail2ban webmin

# 检查端口占用
sudo netstat -tlnp | grep -E ":(80|443|3306|5432|6379|9200|10000|15672)"
```

### 日志查看
```bash
# Nginx日志
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# OpenSearch日志
sudo tail -f /var/log/opensearch/opensearch.log

# Valkey日志
sudo tail -f /var/log/valkey/valkey.log

# ModSecurity审计日志
sudo tail -f /var/log/nginx/modsec_audit.log
```

## 🔒 安全特性

- ✅ **ModSecurity WAF**: 防护Web攻击
- ✅ **Fail2ban**: 入侵检测和IP封禁
- ✅ **SSL/TLS**: Certbot自动化证书
- ✅ **安全头部**: 自动添加安全HTTP头
- ✅ **防火墙**: UFW配置
- ✅ **用户权限**: 最小权限原则

## 📊 性能优化

- ✅ **Varnish缓存**: HTTP加速
- ✅ **Redis兼容**: Valkey高性能缓存
- ✅ **PHP-FPM**: 优化的PHP处理
- ✅ **MySQL调优**: Percona性能优化
- ✅ **Nginx优化**: 高并发配置

## 📞 支持

如有问题，请检查：
1. 系统要求: Ubuntu 24.04
2. 权限要求: sudo权限
3. 网络要求: 能访问官方仓库
4. 硬件要求: 最少2GB内存

---

**🎉 恭喜！您的LEMP环境已完全配置完成！**
