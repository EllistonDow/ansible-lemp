# Magento2 性能优化器 📈

针对64GB RAM服务器运行3-4个Magento2网站的专业性能优化工具。

## 🎯 功能特性

### 🔧 全面优化
- **MySQL (Percona)**: 数据库查询和存储优化
- **PHP-FPM**: 进程池和内存管理优化  
- **Nginx**: Web服务器缓存和连接优化
- **Valkey (Redis)**: 会话存储和缓存优化
- **OpenSearch**: 产品搜索和索引性能优化

### 🛡️ 安全可靠
- **自动备份**: 修改前自动备份原始配置
- **一键还原**: 可随时还原到原始状态
- **状态监控**: 实时查看优化状态
- **错误处理**: 完善的错误检测和恢复

## 🚀 快速开始

### 1. 检查当前状态
```bash
./scripts/magento2-optimizer.sh status
```

### 2. 应用优化配置
```bash
./scripts/magento2-optimizer.sh optimize
```

### 3. 如需还原配置
```bash
./scripts/magento2-optimizer.sh restore
```

## 📊 内存分配策略

| 服务 | 内存分配 | 说明 |
|------|----------|------|
| MySQL | 20GB | 数据和索引缓存 |
| OpenSearch | 12GB | 搜索引擎和索引 |
| PHP-FPM | 12GB | 120个进程×2GB限制 |
| Valkey | 8GB | 会话和缓存存储 |
| 系统+其他 | 12GB | 系统缓存和其他服务 |

## 🔧 优化详情

### MySQL优化
- InnoDB缓冲池: 20GB
- 最大连接数: 500
- 查询缓存优化
- 事务日志优化

### PHP-FPM优化
- 动态进程管理
- 最大120个子进程
- 2GB内存限制/进程
- OPcache优化

### Nginx优化
- 工作进程自动调整
- FastCGI缓存配置
- Gzip压缩优化
- 连接保持优化

### Valkey优化
- 8GB最大内存
- LRU内存回收策略
- 会话存储优化
- 持久化配置

### OpenSearch优化
- 12GB JVM堆内存
- G1垃圾回收器
- 单节点集群配置
- Magento2专用设置

## 📈 预期性能提升

### 响应时间
- 首页加载: 2-3秒 → **< 1秒**
- 产品页面: 3-5秒 → **< 2秒**
- 搜索响应: 2-4秒 → **< 0.5秒**
- 结账流程: 5-8秒 → **< 3秒**

### 并发能力
- 同时用户: 100-200 → **500-1000**
- 数据库连接: 151 → **500**
- PHP进程: 8-16 → **120**

### 系统资源
- 内存利用率: 40-60% → **85-95%**
- 数据库缓存命中率: 70-80% → **95%+**
- 页面缓存命中率: 50-70% → **90%+**

## 🛠️ 安装后配置

### 1. Magento2配置OpenSearch
```bash
# 在Magento2根目录执行
bin/magento config:set catalog/search/engine opensearch
bin/magento config:set catalog/search/opensearch_server_hostname localhost
bin/magento config:set catalog/search/opensearch_server_port 9200
bin/magento config:set catalog/search/opensearch_index_prefix magento2
```

### 2. 配置Valkey会话存储
```bash
# 编辑 app/etc/env.php
'session' => [
    'save' => 'redis',
    'redis' => [
        'host' => '127.0.0.1',
        'port' => 6379,
        'password' => '',
        'timeout' => '2.5',
        'persistent_identifier' => '',
        'database' => 2,
        'compression_threshold' => '2048',
        'compression_library' => 'gzip'
    ]
]
```

### 3. 配置页面缓存
```bash
# 使用Valkey作为页面缓存
bin/magento config:set system/full_page_cache/caching_application 2
bin/magento config:set system/full_page_cache/ttl 86400
```

### 4. 重建索引和缓存
```bash
# 重建所有索引
bin/magento indexer:reindex

# 清理并预热缓存
bin/magento cache:clean
bin/magento cache:flush
bin/magento cache:enable
```

## 🎯 Magento2生产模式配置

### 1. 切换到生产模式
```bash
bin/magento deploy:mode:set production
```

### 2. 静态内容部署
```bash
bin/magento setup:static-content:deploy -f
```

### 3. 依赖注入编译
```bash
bin/magento setup:di:compile
```

## 📊 性能监控

### 1. 系统监控命令
```bash
# 内存使用情况
free -h

# MySQL进程状态
mysqladmin -u root -p processlist

# PHP-FPM状态
sudo systemctl status php8.3-fpm

# OpenSearch状态
curl -X GET "localhost:9200/_cluster/health?pretty"

# Valkey状态
redis-cli info memory
```

### 2. Magento2性能监控
```bash
# 检查索引状态
bin/magento indexer:status

# 查看缓存状态
bin/magento cache:status

# 检查模式
bin/magento deploy:mode:show
```

## ⚠️ 重要注意事项

### 备份文件位置
- 配置备份: `/opt/lemp-backups/magento2-optimizer/`
- 自动时间戳: `文件名.backup.YYYYMMDD_HHMMSS`
- 原始备份: `文件名.original`

### 服务重启说明
- 优化过程会自动重启所有相关服务
- 预计重启时间: 2-5分钟
- 建议在低流量时段执行

### 兼容性检查
- Ubuntu 24.04 LTS ✅
- PHP 8.3 ✅
- MySQL/Percona 8.4 ✅
- OpenSearch 2.19 ✅
- Magento 2.4.6+ ✅

## 🔄 版本更新

当系统配置发生变化时，可以重新运行优化脚本：

```bash
# 先还原原始配置
./scripts/magento2-optimizer.sh restore

# 重新应用优化
./scripts/magento2-optimizer.sh optimize
```

## 🆘 故障排除

### 1. MySQL无法启动
```bash
# 检查错误日志
sudo tail -f /var/log/mysql/error.log

# 还原MySQL配置
sudo cp /opt/lemp-backups/magento2-optimizer/mysqld.cnf.original /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql
```

### 2. OpenSearch启动失败
```bash
# 检查OpenSearch日志
sudo tail -f /var/log/opensearch/opensearch.log

# 检查JVM设置
sudo systemctl status opensearch
```

### 3. PHP-FPM错误
```bash
# 检查PHP-FPM日志
sudo tail -f /var/log/php8.3-fpm.log

# 测试配置文件
sudo php-fpm8.3 -t
```

## 📞 技术支持

如果遇到问题，请检查：
1. 系统日志: `journalctl -xe`
2. 服务状态: `systemctl status service-name`
3. 配置语法: 各服务的配置测试命令

---

**🎉 享受Magento2的高性能体验！**
