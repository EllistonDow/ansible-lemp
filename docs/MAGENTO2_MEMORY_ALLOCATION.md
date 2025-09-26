# Magento2 内存分配策略 (64GB RAM服务器)

## 📊 总内存分配概览

本文档描述了针对64GB RAM服务器运行3-4个Magento2网站的内存分配策略。

### 🎯 服务器配置
- **总内存**: 64GB
- **网站数量**: 3-4个Magento2站点
- **CPU核心**: 自动检测
- **使用场景**: 中到大型电子商务网站

## 💾 内存分配明细

| 服务 | 分配内存 | 百分比 | 说明 |
|------|----------|--------|------|
| **MySQL (Percona)** | 20GB | 31% | InnoDB缓冲池和查询处理 |
| **OpenSearch** | 12GB | 19% | 产品搜索和索引存储 |
| **Valkey (Redis)** | 8GB | 12% | 会话存储和页面缓存 |
| **PHP-FPM** | 12GB | 19% | PHP进程池 (120个进程 × 2GB limit，实际约100MB) |
| **系统缓存** | 8GB | 12% | 文件系统缓存和内核 |
| **其他服务** | 4GB | 7% | Nginx, Varnish, 系统进程等 |

**总计**: 64GB (100%)

## 🔧 各服务详细配置

### MySQL (Percona Server)
```ini
# 主要内存设置
innodb_buffer_pool_size = 20G          # 数据和索引缓存
innodb_buffer_pool_instances = 20      # 缓冲池实例数
innodb_log_buffer_size = 256M          # 日志缓冲区
key_buffer_size = 512M                 # MyISAM索引缓存
tmp_table_size = 512M                  # 临时表大小
max_heap_table_size = 512M             # 内存表大小

# 连接设置
max_connections = 500                  # 最大连接数
thread_cache_size = 50                 # 线程缓存
```

### OpenSearch
```yaml
# JVM堆内存设置
-Xms12g                               # 初始堆大小
-Xmx12g                               # 最大堆大小

# 缓存设置
indices.memory.index_buffer_size: 30%  # 索引缓冲区
indices.requests.cache.size: 2%        # 请求缓存
indices.fielddata.cache.size: 20%      # 字段数据缓存
```

### PHP-FPM
```ini
# 进程池设置
pm = dynamic
pm.max_children = 120                  # 最大子进程数
pm.start_servers = 30                 # 启动时进程数
pm.min_spare_servers = 20             # 最小空闲进程
pm.max_spare_servers = 40             # 最大空闲进程

# PHP内存设置 (Magento2官方建议: 生产环境2GB)
memory_limit = 2G                     # 每个进程内存限制
```

### Valkey (Redis)
```conf
maxmemory 8gb                         # 最大内存使用
maxmemory-policy allkeys-lru          # 内存回收策略
```

## 🚀 性能优化要点

### 1. InnoDB优化
- **缓冲池**: 20GB确保大部分热数据在内存中
- **实例数**: 20个实例减少锁竞争
- **日志文件**: 1GB × 2 提供充足的事务日志空间

### 2. OpenSearch优化
- **堆内存**: 12GB适合索引大量产品数据
- **GC设置**: 使用G1GC优化垃圾回收
- **索引策略**: 单分片无副本适合单节点部署

### 3. PHP-FPM优化
- **进程数**: 120个进程支持高并发
- **内存限制**: 2GB/进程符合Magento2官方建议
- **OPcache**: 1GB OPcache缓存编译的PHP代码

### 4. 缓存策略
- **Valkey**: 用于会话存储和页面缓存
- **Nginx**: FastCGI缓存减少PHP处理
- **Varnish**: 全页缓存 (可选)

## 📈 预期性能表现

### 并发能力
- **同时用户**: 500-1000个活跃用户
- **页面响应**: < 2秒 (TTFB)
- **数据库查询**: < 100ms (平均)
- **搜索响应**: < 500ms

### 资源利用率
- **CPU使用率**: 60-80% (高峰期)
- **内存使用率**: 85-95%
- **磁盘I/O**: 优化后显著降低
- **网络**: 充分利用带宽

## ⚠️ 注意事项

### 监控要点
1. **MySQL慢查询**: 监控超过2秒的查询
2. **OpenSearch JVM**: 关注GC频率和时间
3. **PHP-FPM状态**: 监控进程池使用情况
4. **系统负载**: 确保不超过CPU核心数

### 调优建议
1. **定期优化**: 每月检查和调整配置
2. **索引维护**: 定期重建OpenSearch索引
3. **缓存清理**: 定期清理过期缓存数据
4. **日志轮转**: 配置日志轮转避免磁盘满

## 🔄 扩展策略

### 垂直扩展 (单服务器)
- 增加到128GB RAM可支持更多站点
- 添加SSD存储提升I/O性能
- 升级CPU提升计算能力

### 水平扩展 (多服务器)
- 数据库主从分离
- OpenSearch集群部署
- 负载均衡器分发请求

## 📝 使用magento2-optimizer.sh

```bash
# 应用优化配置
./scripts/magento2-optimizer.sh optimize

# 查看当前状态
./scripts/magento2-optimizer.sh status

# 还原原始配置
./scripts/magento2-optimizer.sh restore
```

这个内存分配策略经过精心设计，确保64GB RAM服务器能够高效运行3-4个Magento2网站，同时保持良好的性能和稳定性。
