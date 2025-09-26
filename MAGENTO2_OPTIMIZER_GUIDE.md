# 🚀 Magento2优化脚本 - 快速使用指南

## 📋 基本用法

### 1. 查看帮助信息
```bash
./scripts/magento2-optimizer.sh help
```

### 2. 查看当前系统状态
```bash
./scripts/magento2-optimizer.sh status
```

### 3. 🎯 应用优化配置 (主要功能)
```bash
./scripts/magento2-optimizer.sh optimize
```

### 4. 🔄 还原原始配置
```bash
./scripts/magento2-optimizer.sh restore
```

## 🔧 详细说明

### ✅ 优化功能 (`optimize`)
**作用**: 将系统配置优化为适合Magento2的高性能设置

**优化内容**:
- **MySQL**: 20GB缓冲池，500连接数，InnoDB优化
- **PHP-FPM**: 120进程，2GB内存限制，OPcache优化  
- **Nginx**: FastCGI缓存，高并发连接优化
- **Valkey**: 8GB缓存，会话存储配置
- **OpenSearch**: 12GB堆内存，搜索引擎优化

**执行过程**:
1. 自动备份原始配置文件
2. 应用优化配置
3. 重启相关服务
4. 显示优化状态

### 🔄 还原功能 (`restore`)
**作用**: 将所有配置还原到优化前的原始状态

**还原内容**:
- MySQL配置文件
- PHP-FPM配置文件  
- PHP.ini配置文件
- Nginx配置文件
- Valkey配置文件
- OpenSearch配置文件

### 📊 状态查看 (`status`)
**作用**: 显示当前系统的优化状态

**显示信息**:
- MySQL InnoDB缓冲池大小
- PHP内存限制
- Nginx工作进程设置
- Valkey最大内存
- OpenSearch堆内存大小

## ⚠️ 使用注意事项

### 🛡️ 安全备份
- 脚本会自动备份配置文件到: `/opt/lemp-backups/magento2-optimizer/`
- 备份文件格式: `配置名.backup.时间戳` 和 `配置名.original`

### ⏱️ 执行时机
- **建议时间**: 低流量时段 (如凌晨2-4点)
- **预计时长**: 2-5分钟 (包含服务重启)
- **影响**: 短暂的服务中断

### 🔍 执行前检查
```bash
# 检查磁盘空间
df -h

# 检查服务状态
systemctl status mysql php8.3-fpm nginx valkey opensearch

# 查看当前配置状态
./scripts/magento2-optimizer.sh status
```

## 📝 完整使用流程

### 🚀 首次优化流程
```bash
# 1. 检查当前状态
./scripts/magento2-optimizer.sh status

# 2. 应用优化 (这是主要操作)
./scripts/magento2-optimizer.sh optimize

# 3. 验证优化结果
./scripts/magento2-optimizer.sh status
```

### 🔄 如需还原
```bash
# 还原所有配置
./scripts/magento2-optimizer.sh restore

# 验证还原结果
./scripts/magento2-optimizer.sh status
```

## 🎯 预期效果

### 优化前 vs 优化后
| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 首页加载 | 3-5秒 | 1-2秒 | 60%+ |
| 产品页面 | 4-6秒 | 2-3秒 | 50%+ |
| 搜索响应 | 2-4秒 | 0.5-1秒 | 75%+ |
| 并发用户 | 50-100 | 300-500 | 400%+ |
| 数据库响应 | 200-500ms | 50-100ms | 70%+ |

## 🆘 故障排除

### 如果优化后出现问题
```bash
# 立即还原配置
./scripts/magento2-optimizer.sh restore

# 检查服务状态
systemctl status mysql php8.3-fpm nginx valkey opensearch

# 查看错误日志
tail -f /var/log/mysql/error.log
tail -f /var/log/php8.3-fpm.log
tail -f /var/log/nginx/error.log
```

### 常见问题
1. **MySQL启动失败**: 通常是内存不足，检查可用内存
2. **PHP-FPM错误**: 检查进程数配置是否合适
3. **OpenSearch启动失败**: 检查JVM内存设置

## 📞 技术支持

如有问题，请检查：
1. 服务器内存是否真的是64GB
2. 所有服务是否正常安装
3. 磁盘空间是否充足
4. 系统日志: `journalctl -xe`

---

**🎉 享受Magento2的高性能体验！**
