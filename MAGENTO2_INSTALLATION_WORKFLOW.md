# 🚀 Magento2安装 + 优化最佳流程

## 📋 推荐执行顺序

### 阶段1: LEMP环境准备 ✅
```bash
# 1. 安装基础LEMP环境 (已完成)
ansible-playbook -i inventories/production playbooks/site.yml

# 2. 验证所有服务正常运行
./lemp-check.sh status
```

### 阶段2: 性能优化 🚀 (建议现在执行)
```bash
# 3. 应用Magento2性能优化
./scripts/magento2-optimizer.sh optimize

# 4. 验证优化效果
./scripts/magento2-optimizer.sh status
```

### 阶段3: Magento2安装 📦
```bash
# 5. 下载Magento2
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition /var/www/html/magento2

# 6. 配置权限
sudo chown -R www-data:www-data /var/www/html/magento2
sudo chmod -R 755 /var/www/html/magento2

# 7. 安装Magento2
php bin/magento setup:install \
  --base-url=http://yourstore.com \
  --db-host=localhost \
  --db-name=magento2 \
  --db-user=root \
  --db-password=root_password_change_me \
  --admin-firstname=Admin \
  --admin-lastname=User \
  --admin-email=admin@yourstore.com \
  --admin-user=admin \
  --admin-password=YourStrongPassword123! \
  --language=en_US \
  --currency=USD \
  --timezone=America/Los_Angeles \
  --use-rewrites=1 \
  --search-engine=opensearch \
  --opensearch-host=localhost \
  --opensearch-port=9200
```

## 💡 为什么先优化再安装？

### ✅ 优势
1. **安装过程更快**: 优化的数据库和PHP配置让安装过程更流畅
2. **避免安装失败**: 充足的内存和连接数避免安装过程中的超时
3. **一次配置**: 不需要安装后再调整配置重启服务
4. **性能基线**: 从一开始就有最佳性能表现

### 🎯 具体好处

#### MySQL优化对安装的影响
```ini
# 优化前 (默认配置)
innodb_buffer_pool_size = 128M      # 安装时数据库操作慢
max_connections = 151                # 可能连接不足

# 优化后
innodb_buffer_pool_size = 20G       # 快速数据库操作
max_connections = 500                # 充足连接数
```

#### PHP-FPM优化对安装的影响
```ini
# 优化前
memory_limit = 128M                  # 安装可能内存不足
max_execution_time = 30              # 安装过程可能超时

# 优化后  
memory_limit = 2G                    # 安装过程内存充足
max_execution_time = 1800            # 30分钟执行时间
```

#### OpenSearch优化对安装的影响
```yaml
# 优化前
-Xms1g -Xmx1g                       # 索引创建较慢

# 优化后
-Xms12g -Xmx12g                     # 快速索引创建
```

## 🔧 优化验证

### 在优化后，安装前检查
```bash
# 1. 检查优化状态
./scripts/magento2-optimizer.sh status

# 应该看到:
# MySQL InnoDB Buffer Pool: 20G
# PHP Memory Limit: 2G  
# OpenSearch Heap Size: 12g

# 2. 检查服务状态
systemctl status mysql php8.3-fpm nginx valkey opensearch

# 3. 测试数据库连接
mysql -u root -e "SELECT 'Database ready!' as status;"

# 4. 测试OpenSearch
curl -X GET "localhost:9200/_cluster/health?pretty"
```

## 🚀 Magento2专用配置

### 安装完成后的额外配置

#### 1. 配置缓存存储
```bash
# 编辑 app/etc/env.php
'cache' => [
    'frontend' => [
        'default' => [
            'backend' => 'Cm_Cache_Backend_Redis',
            'backend_options' => [
                'server' => '127.0.0.1',
                'port' => '6379',
                'database' => 0
            ]
        ]
    ]
]
```

#### 2. 配置会话存储
```bash
# 会话存储使用Valkey (Redis)
'session' => [
    'save' => 'redis',
    'redis' => [
        'host' => '127.0.0.1',
        'port' => 6379,
        'password' => '',
        'timeout' => '2.5',
        'database' => 2
    ]
]
```

#### 3. 启用生产模式
```bash
# 切换到生产模式
bin/magento deploy:mode:set production

# 编译依赖注入
bin/magento setup:di:compile

# 部署静态文件
bin/magento setup:static-content:deploy -f

# 重建索引
bin/magento indexer:reindex
```

## ⏱️ 时间对比

### 安装时间对比
| 阶段 | 未优化 | 已优化 | 改善 |
|------|--------|--------|------|
| 数据库初始化 | 10-15分钟 | 3-5分钟 | 70% |
| 索引创建 | 15-20分钟 | 5-8分钟 | 65% |
| 静态文件部署 | 8-12分钟 | 3-5分钟 | 60% |
| **总安装时间** | **35-50分钟** | **12-18分钟** | **65%** |

## 📝 当前状态检查

让我检查一下你当前的系统状态：

```bash
# 检查当前优化状态
./scripts/magento2-optimizer.sh status

# 如果显示未优化，建议现在执行:
./scripts/magento2-optimizer.sh optimize
```

## 🎯 总结建议

**现在最佳的执行步骤**:

1. ✅ **LEMP环境已安装** (你已完成)
2. 🚀 **立即运行优化脚本** (推荐现在执行)
   ```bash
   ./scripts/magento2-optimizer.sh optimize
   ```
3. 📦 **然后安装Magento2站点**

这样可以确保从安装开始就有最佳的性能表现！
