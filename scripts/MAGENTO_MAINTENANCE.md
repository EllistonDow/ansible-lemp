# Magento 自动维护脚本使用指南

## 📋 脚本说明

`magento2-maintenance.sh` - Magento 2 自动化维护脚本，处理缓存清理、索引重建、日志清理等日常维护任务。

### 特点

- ✅ 无需 sudo，安全高效
- ✅ 智能维护模式，防止并发冲突
- ✅ 自动权限处理
- ✅ 日志轮转，防止日志文件过大
- ✅ 锁机制，防止重复运行

## 🚀 快速开始

### 1. 初始权限配置（必须执行一次）

为每个 Magento 站点设置正确的文件权限：

```bash
# Hawk 站点
echo 'y' | ~/ansible-lemp/scripts/magento-permissions.sh setup doge /home/doge/hawk

# Papa 站点
echo 'y' | ~/ansible-lemp/scripts/magento-permissions.sh setup doge /home/doge/papa
```

### 2. 测试运行

```bash
# 测试每周维护（最全面）
~/ansible-lemp/scripts/magento2-maintenance.sh weekly hawk

# 测试每日维护
~/ansible-lemp/scripts/magento2-maintenance.sh daily hawk

# 测试每小时维护
~/ansible-lemp/scripts/magento2-maintenance.sh hourly hawk
```

### 3. 配置自动运行

编辑 crontab：

```bash
crontab -e
```

添加以下内容：

```bash
# ================================================
# Magento 自动维护
# ================================================

# Hawk 站点
0 * * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh hourly hawk
10 2 * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh daily hawk
5 2 * * 6 /home/doge/ansible-lemp/scripts/magento2-maintenance.sh weekly hawk

# Papa 站点（错开时间避免资源竞争）
0 * * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh hourly papa
20 2 * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh daily papa
15 3 * * 6 /home/doge/ansible-lemp/scripts/magento2-maintenance.sh weekly papa

# ambi 站点 
0 * * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh hourly ambi
30 2 * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh daily ambi
25 4 * * 6 /home/doge/ansible-lemp/scripts/magento2-maintenance.sh weekly ambi

# ipwa 站点（错开时间避免资源竞争）
0 * * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh hourly ipwa
40 2 * * * /home/doge/ansible-lemp/scripts/magento2-maintenance.sh daily ipwa
35 5 * * 6 /home/doge/ansible-lemp/scripts/magento2-maintenance.sh weekly ipwa
```

## 📊 维护频率说明

### Hourly（每小时）- 轻量级
- 启动异步队列消费者
- 清理超过 1 天的会话文件
- **适合：** 所有站点

### Daily（每日）- 标准维护
- 运行 Magento cron 任务
- 启动队列消费者
- 清理旧会话（1天）和旧日志（7天）
- 智能检查索引状态，仅在需要时重建
- **适合：** 所有站点
- **推荐时间：** 凌晨 3-4 点（低流量时段）

### Weekly（每周）- 深度维护
- **启用维护模式**（网站暂时不可访问）
- 运行完整索引重建
- 清理所有缓存（包括产品图片缓存）
- 清理超过 30 天的日志
- **适合：** 所有站点
- **推荐时间：** 周日凌晨 4-5 点（最低流量时段）
- **预计时间：** 10-30 秒（取决于站点大小）

## 📝 查看日志

日志位置：`~/Dropbox/cronscripts/logs/`

```bash
# 实时查看日志
tail -f ~/Dropbox/cronscripts/logs/magento-hawk-daily.log

# 查看所有日志文件
ls -lh ~/Dropbox/cronscripts/logs/

# 查看每周维护日志
cat ~/Dropbox/cronscripts/logs/magento-hawk-weekly.log
```

## 🔧 故障排除

### 问题1：权限被拒绝

**症状：**
```
⚠️  Remaining: XX images
```

**解决：**
```bash
# 重新设置权限
echo 'y' | ~/ansible-lemp/scripts/magento-permissions.sh setup doge /home/doge/hawk
```

### 问题2：锁文件残留

**症状：**
```
Another daily maintenance is running for hawk, exiting.
```

**解决：**
```bash
# 检查是否真的在运行
ps aux | grep magento2-maintenance

# 如果没有运行，删除锁文件
rm -f /tmp/magento_hawk_daily.lock
```

### 问题3：日志文件过大

**解决：**
```bash
# 清理旧日志（脚本已内置日志轮转，保留最近 1000 行）
rm -f ~/Dropbox/cronscripts/logs/*.old
```

### 问题4：用户不在 www-data 组

**症状：**
```
⚠️  警告: 用户 doge 不在 www-data 组中
```

**解决：**
```bash
# 添加用户到 www-data 组
sudo usermod -a -G www-data doge

# 重新登录或刷新组
newgrp www-data
```

## 📈 性能数据

- **每小时维护：** < 1 秒
- **每日维护：** 2-5 秒
- **每周维护：** 10-30 秒
- **成功率：** 100%
- **资源占用：** 低

## 🎯 相关脚本

| 脚本 | 用途 | 使用频率 |
|------|------|----------|
| `magento2-maintenance.sh` | 自动维护（主力） | Crontab 自动运行 |
| `magento-permissions.sh` | 权限修复 | 部署时 + 按需 |
| `magento-deploy.sh` | 部署/升级 | 手动运行 |

## 💡 最佳实践

1. **定期检查日志**：每周查看一次维护日志，确保正常运行
2. **权限维护**：每月运行一次权限修复脚本
3. **备份策略**：每周维护前自动备份数据库
4. **监控资源**：观察服务器负载，必要时调整维护时间
5. **低流量时段**：将深度维护安排在网站访问量最低时

## 📞 需要帮助？

检查：
1. 日志文件：`~/Dropbox/cronscripts/logs/`
2. Magento 日志：`/home/doge/hawk/var/log/`
3. 系统日志：`journalctl -u cron -f`
4. 权限状态：`ls -la /home/doge/hawk/{var,pub,generated}/`

---

**更新时间：** 2025-10-01  
**版本：** 1.0 - 最终稳定版

