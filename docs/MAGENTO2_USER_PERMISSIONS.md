# 🔐 Magento2 用户和权限管理指南

## 📋 问题分析

### ❌ **不推荐的做法**
```bash
# 不安全：将 Nginx 用户改为个人用户
user doge;  # 在 /etc/nginx/nginx.conf
```

**风险**：
- 🚨 安全隔离被破坏
- 🚨 如果网站被入侵，攻击者可以访问用户的所有文件
- 🚨 多个网站共享用户时，一个被攻击会影响所有网站
- 🚨 不符合最小权限原则

### ✅ **推荐的做法**

**原则**：
1. **Nginx 用户保持 `www-data`**（系统安全）
2. **文件所有者设为个人用户**（方便管理）
3. **文件组设为 `www-data`**（Nginx 可读）
4. **合理的文件权限**（安全与功能平衡）

## 🚀 快速使用

### 方式一：简化命令（推荐）

```bash
# 为当前目录设置权限
cd /home/doge/hawk
./magentouser.sh doge

# 为指定目录设置权限
./magentouser.sh doge /home/doge/tank

# 还原默认配置
./magentouser.sh restore
```

### 方式二：完整命令

```bash
# 设置权限
./scripts/magento-permissions.sh setup doge /home/doge/hawk

# 快速设置（使用当前用户）
cd /home/doge/tank
./scripts/magento-permissions.sh quick .

# 检查权限
./scripts/magento-permissions.sh check /home/doge/hawk

# 还原配置
./scripts/magento-permissions.sh restore
```

## 🔧 权限配置方案

### 标准目录结构

```
/home/doge/hawk/          # Magento2 根目录
├── app/                  # 755 / doge:www-data
├── bin/                  # 755 / doge:www-data
│   └── magento          # 755 (可执行)
├── pub/                  # 755 / doge:www-data
│   ├── media/           # 775 / doge:www-data (可写)
│   └── static/          # 775 / doge:www-data (可写)
├── var/                  # 775 / doge:www-data (可写)
├── generated/            # 775 / doge:www-data (可写)
└── vendor/               # 755 / doge:www-data
```

### 权限说明

| 类型 | 所有者 | 组 | 目录权限 | 文件权限 | 说明 |
|------|--------|-----|----------|----------|------|
| **一般目录** | doge | www-data | 755 | 644 | Nginx 可读，用户可写 |
| **可写目录** | doge | www-data | 775 | 664 | Nginx 可写（缓存、上传等） |
| **可执行文件** | doge | www-data | - | 755 | bin/magento 等脚本 |

## 🎯 使用场景

### 场景一：新建 Magento2 网站

```bash
# 1. 创建网站目录
mkdir -p /home/doge/hawk
cd /home/doge/hawk

# 2. 安装 Magento2
composer create-project --repository-url=https://repo.magento.com/ \
    magento/project-community-edition .

# 3. 设置权限
~/ansible-lemp/magentouser.sh doge

# 4. 完成安装
php bin/magento setup:install \
    --base-url=http://hawk.example.com \
    --db-host=localhost \
    --db-name=hawk \
    --db-user=root \
    --admin-user=admin
```

### 场景二：多个网站

```bash
# 为每个网站分别设置权限
~/ansible-lemp/magentouser.sh doge /home/doge/hawk
~/ansible-lemp/magentouser.sh doge /home/doge/tank
~/ansible-lemp/magentouser.sh doge /home/doge/falcon
```

### 场景三：修复权限问题

```bash
# 检查权限
~/ansible-lemp/scripts/magento-permissions.sh check /home/doge/hawk

# 如果发现问题，重新设置
~/ansible-lemp/magentouser.sh doge /home/doge/hawk

# 清理 Magento 缓存
cd /home/doge/hawk
php bin/magento cache:clean
```

## 🛡️ 安全最佳实践

### 1. 用户隔离

```bash
# 不同项目使用不同用户（高安全性场景）
./scripts/magento-permissions.sh setup hawk_user /home/hawk_user/site
./scripts/magento-permissions.sh setup tank_user /home/tank_user/site
```

### 2. Nginx 配置

保持 Nginx 用户为 `www-data`：

```nginx
# /etc/nginx/nginx.conf
user www-data;  # 不要改为个人用户

# 虚拟主机配置
server {
    root /home/doge/hawk/pub;
    
    # Nginx 以 www-data 身份运行
    # 可以读取 doge:www-data 755 的目录
    # 可以写入 doge:www-data 775 的目录
}
```

### 3. PHP-FPM 配置

保持 PHP-FPM 用户为 `www-data`：

```ini
# /etc/php/8.3/fpm/pool.d/www.conf
user = www-data
group = www-data
```

### 4. 定期检查

```bash
# 定期检查权限
~/ansible-lemp/scripts/magento-permissions.sh check /home/doge/hawk

# 监控日志
tail -f /var/log/nginx/error.log
tail -f /home/doge/hawk/var/log/system.log
```

## 🔍 故障排除

### 问题一：Nginx 403 Forbidden

**原因**：Nginx 用户无权读取文件

**解决**：
```bash
# 检查权限
ls -la /home/doge/hawk/

# 重新设置
~/ansible-lemp/magentouser.sh doge /home/doge/hawk

# 确保 /home/doge 可读
chmod 755 /home/doge
```

### 问题二：无法上传图片

**原因**：pub/media 目录不可写

**解决**：
```bash
cd /home/doge/hawk

# 设置可写权限
sudo chmod -R 775 pub/media var generated
sudo chown -R doge:www-data pub/media var generated

# 或重新运行脚本
~/ansible-lemp/magentouser.sh doge
```

### 问题三：静态文件生成失败

**原因**：pub/static 目录不可写

**解决**：
```bash
cd /home/doge/hawk

# 清理并重建
rm -rf pub/static/*
rm -rf var/view_preprocessed/*

# 重新设置权限
~/ansible-lemp/magentouser.sh doge

# 生成静态文件
php bin/magento setup:static-content:deploy -f
```

## 📊 权限对比

### 传统做法 vs 推荐做法

| 方面 | 传统做法（改 Nginx 用户） | 推荐做法（组权限） |
|------|---------------------------|-------------------|
| **安全性** | ❌ 低（隔离被破坏） | ✅ 高（保持隔离） |
| **管理便利** | ✅ 方便（直接编辑文件） | ✅ 方便（所有者是自己） |
| **多站点** | ❌ 困难（用户冲突） | ✅ 简单（各自独立） |
| **入侵影响** | ❌ 大（可访问所有文件） | ✅ 小（仅限网站目录） |
| **维护成本** | ❌ 高（需要改配置） | ✅ 低（标准配置） |

## 🔄 迁移指南

如果你已经将 Nginx 用户改为个人用户，如何迁移：

```bash
# 1. 备份当前配置
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
sudo cp /etc/php/8.3/fpm/pool.d/www.conf /etc/php/8.3/fpm/pool.d/www.conf.backup

# 2. 还原默认配置
~/ansible-lemp/magentouser.sh restore

# 3. 为每个网站设置正确权限
~/ansible-lemp/magentouser.sh doge /home/doge/hawk
~/ansible-lemp/magentouser.sh doge /home/doge/tank

# 4. 测试网站
curl -I http://localhost

# 5. 重启服务
sudo systemctl restart nginx php8.3-fpm
```

## 📞 技术支持

遇到问题？

1. 查看脚本帮助：`~/ansible-lemp/scripts/magento-permissions.sh --help`
2. 检查权限：`~/ansible-lemp/scripts/magento-permissions.sh check [路径]`
3. 查看日志：`/var/log/nginx/error.log`
4. Magento 日志：`/home/doge/hawk/var/log/`

---

**✅ 总结**：保持 Nginx 用户为 `www-data`，通过文件组权限实现管理便利和安全性的平衡！
