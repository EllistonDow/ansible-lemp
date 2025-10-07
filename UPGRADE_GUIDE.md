# 升级指南：从 v1.9.1 升级到 v1.9.7

## 📋 版本变更概览

```
v1.9.1 → v1.9.7 (6个版本升级)
```

### 主要更新内容：
- v1.9.2: 脚本重组和增强（services-check.sh）
- v1.9.3: ModSecurity路径检测修复
- v1.9.4: 新增Magento2工具脚本集合
- v1.9.5: 服务重启脚本sudo修复
- v1.9.6: 代码清理和路径标准化
- v1.9.7: 优化的Crontab配置

---

## 🚀 升级步骤

### 步骤 1: 备份当前配置

```bash
# 进入项目目录
cd /home/doge/ansible-lemp

# 备份当前版本
git branch backup-v1.9.1-$(date +%Y%m%d)

# 备份 crontab
crontab -l > ~/crontab.backup.$(date +%Y%m%d_%H%M%S)

# 备份重要配置文件（如果有修改）
cp -r dogetools ~/backup-dogetools-$(date +%Y%m%d)
cp -r scripts ~/backup-scripts-$(date +%Y%m%d)
```

---

### 步骤 2: 检查本地修改

```bash
cd /home/doge/ansible-lemp

# 查看是否有未提交的修改
git status

# 如果有修改，保存它们
git stash save "Local changes before upgrade to v1.9.7"
```

---

### 步骤 3: 更新代码

```bash
cd /home/doge/ansible-lemp

# 获取最新的远程信息
git fetch origin --tags

# 查看可用版本
git tag -l | tail -10

# 切换到最新版本
git checkout v1.9.7

# 或者更新到 master 分支最新代码
# git checkout master
# git pull origin master
```

---

### 步骤 4: 检查新文件和变更

```bash
cd /home/doge/ansible-lemp

# 查看版本号
git describe --tags --abbrev=0

# 查看新增的文件
ls -la dogetools/
ls -la scripts/

# 新增的重要文件：
# - dogetools/maintenance.sh
# - dogetools/mysqldump.sh
# - dogetools/services-restart.sh
# - dogetools/snapshot.sh
# - crontab-optimized.txt
# - scripts/services-check.sh
```

---

### 步骤 5: 恢复本地修改（如果需要）

```bash
# 如果之前使用了 git stash
git stash list

# 恢复修改
git stash pop
```

---

### 步骤 6: 更新 Crontab 配置

```bash
cd /home/doge/ansible-lemp

# 方案 1: 使用新的优化配置（推荐）
crontab crontab-optimized.txt
crontab crontab-optimized-bf1-fixed.txt

# 方案 2: 手动编辑现有 crontab
crontab -e
# 参考 crontab-optimized.txt 进行调整

# 验证 crontab
crontab -l
```

---

### 步骤 7: 创建日志目录

```bash
# 新版本使用统一的日志路径
mkdir -p /home/doge/Dropbox/logs

# 设置权限
chmod 755 /home/doge/Dropbox/logs

# （可选）移动旧日志
if [ -d /home/doge/Dropbox/cron/logs ]; then
    mv /home/doge/Dropbox/cron/logs/* /home/doge/Dropbox/logs/ 2>/dev/null || true
fi
```

---

### 步骤 8: 测试新脚本

```bash
cd /home/doge/ansible-lemp

# 测试服务检查脚本
./scripts/services-check.sh

# 测试服务重启脚本（谨慎！）
# ./dogetools/services-restart.sh

# 测试 Magento 维护脚本（使用你的站点名）
# ./scripts/magento2-maintenance.sh hourly YOUR_SITE_NAME

# 测试数据库备份（使用你的站点名和数据库名）
# ./dogetools/mysqldump.sh YOUR_SITE_NAME YOUR_DB_NAME
```

---

### 步骤 9: 验证升级

```bash
cd /home/doge/ansible-lemp

# 检查版本
git describe --tags --abbrev=0
# 应该显示: v1.9.7

# 查看 Git 状态
git status

# 查看当前标签
git describe --tags
# 应该显示: v1.9.7

# 验证所有脚本可执行
ls -la dogetools/*.sh
ls -la scripts/*.sh
```

---

## 🔍 版本对比

### v1.9.1 → v1.9.7 的主要变化：

#### 新增文件：
```
✅ dogetools/maintenance.sh       - Magento2维护脚本
✅ dogetools/mysqldump.sh         - 数据库备份脚本
✅ dogetools/services-restart.sh  - 服务重启脚本
✅ dogetools/snapshot.sh          - 站点快照脚本
✅ scripts/services-check.sh      - 环境检查工具
✅ crontab-optimized.txt          - 优化的crontab配置
```

#### 修复的问题：
```
✅ ModSecurity 路径检测问题
✅ 服务重启需要密码的问题
✅ 重复脚本清理
✅ 日志路径标准化
✅ Crontab 时间冲突
```

#### 改进的功能：
```
✅ 更强大的系统检查工具
✅ 完整的备份解决方案
✅ 自动化维护脚本
✅ 优化的任务调度
```

---

## ⚠️ 重要注意事项

### 1. Crontab 配置变化
```bash
# 旧路径（v1.9.1可能使用）
/home/doge/Dropbox/cron/logs/

# 新路径（v1.9.6+统一使用）
/home/doge/Dropbox/logs/
```

### 2. 服务重启脚本
```bash
# 旧版本可能没有这个脚本
# 新版本提供了标准化的服务重启工具
./dogetools/services-restart.sh
```

### 3. 脚本命名规范
```bash
# 使用连字符（推荐）
services-restart.sh ✅

# 避免使用下划线
services_restart.sh ❌
```

---

## 🆘 回滚步骤（如果需要）

```bash
cd /home/doge/ansible-lemp

# 回滚到 v1.9.1
git checkout v1.9.1

# 或回滚到备份分支
git checkout backup-v1.9.1-YYYYMMDD

# 恢复 crontab
crontab ~/crontab.backup.YYYYMMDD_HHMMSS
```

---

## 📞 获取帮助

如果升级过程中遇到问题：

1. 查看 GitHub Issues
2. 检查日志文件：`/home/doge/Dropbox/logs/`
3. 验证脚本权限：`chmod +x dogetools/*.sh scripts/*.sh`
4. 检查脚本路径：确保 crontab 中的路径正确

---

## ✅ 升级完成检查清单

- [ ] 代码已更新到 v1.9.7
- [ ] Git tag 显示 v1.9.7
- [ ] 所有新脚本文件存在且可执行
- [ ] 日志目录已创建（/home/doge/Dropbox/logs）
- [ ] Crontab 已更新
- [ ] 测试脚本正常运行
- [ ] 备份已创建（可以回滚）
- [ ] 旧日志已迁移（可选）

---

**升级日期**: $(date +%Y-%m-%d)  
**目标版本**: v1.9.7  
**项目地址**: https://github.com/EllistonDow/ansible-lemp

