# Codazon Infinit Theme Uninstaller

完全卸载和清空 Codazon Infinit 主题及相关文件的专用工具。

## 📋 功能特性

- ✅ 完全删除主题文件
- ✅ 清理数据库配置
- ✅ 清理缓存和编译文件
- ✅ 支持备份功能
- ✅ 演练模式（Dry-run）
- ✅ 交互式确认
- ✅ 彩色日志输出
- ✅ 详细的统计信息
- ✅ **两种数据库清理方式**（Magento 命令 + 直接数据库）
- ✅ **自动读取数据库配置**（从 env.php）

## 🎯 删除范围

此脚本将删除以下位置的 Codazon 主题相关文件：

| 路径 | 说明 |
|------|------|
| `app/design/frontend/Codazon` | 主题设计文件 |
| `app/code/Codazon` | 主题模块代码 |
| `pub/static/frontend/Codazon` | 静态资源文件 |
| `var/view_preprocessed/pub/static/frontend/Codazon` | 预处理视图文件 |
| `var/cache` | 缓存目录 |
| `generated/code/Codazon` | 生成的代码 |
| `generated/metadata/Codazon` | 生成的元数据 |

同时会清理：
- 数据库中的主题配置
- 将网站主题重置为默认的 Luma 主题

## 🚀 快速开始

### 基本用法

```bash
# 交互式卸载（推荐首次使用）
cd /home/doge/ansible-lemp/theme-cleanup/codazon-infinit
./uninstall.sh /var/www/magento2

# 先运行演练模式查看将要删除什么
./uninstall.sh -d /var/www/magento2

# 自动确认卸载（适合脚本化）
./uninstall.sh -y /var/www/magento2

# 备份后再卸载（推荐）
./uninstall.sh -b /var/www/magento2
```

### 高级用法

```bash
# 查看数据库配置（从 env.php 自动读取）
./uninstall.sh --show-db /var/www/magento2

# 使用直接数据库清理（更彻底）
./uninstall.sh --direct-db /var/www/magento2

# 仅清理数据库，不删除文件
./uninstall.sh --db-only /var/www/magento2

# 仅删除文件，不清理数据库
./uninstall.sh --files-only /var/www/magento2

# 备份 + 自动确认 + 直接数据库清理
./uninstall.sh -b -y --direct-db /var/www/magento2
```

## 📖 选项说明

| 选项 | 说明 |
|------|------|
| `-h, --help` | 显示帮助信息 |
| `-d, --dry-run` | 演练模式，只显示将要删除的文件，不实际删除 |
| `-y, --yes` | 跳过确认提示，自动确认所有操作 |
| `-b, --backup` | 在删除前备份主题文件到 `backup/` 目录 |
| `--db-only` | 仅清理数据库配置，不删除文件 |
| `--files-only` | 仅删除文件，不清理数据库 |
| `--direct-db` | 使用直接数据库清理（更彻底，需要 mysql 客户端） |
| `--show-db` | 显示数据库配置信息（从 env.php 读取） |

## 🔒 安全提示

### ⚠️ 使用前必读

1. **备份数据库**：运行此脚本前，请先备份 Magento 数据库
   ```bash
   # 使用项目中的数据库备份工具
   /home/doge/ansible-lemp/dogetools/mysqldump.sh <db_name> <db_name> > backup.sql
   ```

2. **先运行演练模式**：首次使用建议先用 `-d` 参数查看将要删除的内容
   ```bash
   ./uninstall.sh -d /var/www/magento2
   ```

3. **启用备份选项**：如果不确定，使用 `-b` 参数先备份再删除
   ```bash
   ./uninstall.sh -b /var/www/magento2
   ```

4. **关闭网站维护模式**：如果网站处于维护模式，请先关闭
   ```bash
   cd /var/www/magento2
   php bin/magento maintenance:disable
   ```

## 🔍 数据库清理方式

脚本提供**两种**数据库清理方式：

### 方式 1：Magento 命令（默认）
- ✅ 安全可靠，使用官方 API
- ✅ 自动处理依赖关系
- ❌ 如果 Magento 损坏可能失败

```bash
./uninstall.sh /var/www/magento2
```

### 方式 2：直接数据库（高级）
- ✅ 更彻底，直接操作数据库表
- ✅ 即使 Magento 损坏也能执行
- ⚠️ 需要 mysql 客户端和数据库权限

```bash
./uninstall.sh --direct-db /var/www/magento2
```

**详细说明**：查看 [DATABASE_CLEANUP.md](DATABASE_CLEANUP.md)

## 📝 使用流程

### 标准卸载流程（推荐）

```bash
# 1. 进入工具目录
cd /home/doge/ansible-lemp/theme-cleanup/codazon-infinit

# 2. 给脚本添加执行权限
chmod +x uninstall.sh

# 3. 先运行演练模式
./uninstall.sh -d /var/www/magento2

# 4. 查看演练结果，确认无误后，带备份选项运行
./uninstall.sh -b /var/www/magento2

# 5. 按照提示确认操作

# 6. 等待完成后，重启服务
sudo systemctl restart php8.3-fpm
sudo systemctl restart nginx
```

### 快速卸载流程（已确认无风险）

```bash
cd /home/doge/ansible-lemp/theme-cleanup/codazon-infinit
./uninstall.sh -y /var/www/magento2
sudo systemctl restart php8.3-fpm nginx
```

## 🔄 卸载后操作

### 必须操作

```bash
# 1. 重启 PHP-FPM
sudo systemctl restart php8.3-fpm

# 2. 重启 Nginx
sudo systemctl restart nginx

# 3. 检查网站是否正常
curl -I http://your-domain.com
```

### 推荐操作

```bash
# 进入 Magento 根目录
cd /var/www/magento2

# 1. 检查主题配置
php bin/magento config:show design/theme/theme_id

# 2. 清理所有缓存
php bin/magento cache:clean
php bin/magento cache:flush

# 3. 重新索引
php bin/magento indexer:reindex

# 4. 检查部署模式
php bin/magento deploy:mode:show

# 5. 如果是生产模式，重新部署静态内容
php bin/magento setup:static-content:deploy -f zh_Hans_CN en_US
```

## 🛠️ 故障排除

### 问题 1: 权限不足

**症状**：无法删除某些文件

**解决方案**：
```bash
# 方法 1: 使用 sudo
sudo ./uninstall.sh /var/www/magento2

# 方法 2: 修改文件所有权
sudo chown -R $USER:www-data /var/www/magento2
```

### 问题 2: 主题卸载失败

**症状**：`php bin/magento theme:uninstall` 命令报错

**解决方案**：
这是正常的，脚本会继续执行其他清理步骤。可以使用 `--files-only` 仅删除文件：
```bash
./uninstall.sh --files-only /var/www/magento2
```

### 问题 3: 编译时间过长

**症状**：`setup:di:compile` 运行很久

**解决方案**：
可以跳过重新编译，手动在后台运行：
```bash
# 后台运行编译
nohup php bin/magento setup:di:compile > compile.log 2>&1 &

# 查看进度
tail -f compile.log
```

### 问题 4: 网站显示空白

**症状**：卸载后网站显示空白页面

**解决方案**：
```bash
cd /var/www/magento2

# 1. 检查错误日志
tail -f var/log/system.log
tail -f var/log/exception.log

# 2. 重新部署
php bin/magento setup:upgrade
php bin/magento setup:di:compile
php bin/magento setup:static-content:deploy -f

# 3. 设置正确的权限
chmod -R 755 var pub/static pub/media app/etc
chmod 644 app/etc/*.xml
```

## 📊 输出示例

### 演练模式输出

```
╔════════════════════════════════════════════════════════════╗
║         Codazon Infinit Theme Uninstaller v1.0.0          ║
╚════════════════════════════════════════════════════════════╝

[WARNING] 运行模式: 演练模式（不会实际删除文件）

[INFO] 将要删除以下路径:

  📂 app/design/frontend/Codazon
  📂 app/code/Codazon
  📂 pub/static/frontend/Codazon
  📂 var/view_preprocessed/pub/static/frontend/Codazon
  📂 var/cache (缓存目录)
  📂 generated/code/Codazon

[INFO] 统计信息:

  app/design/frontend/Codazon: 45M
  app/code/Codazon: 12M
  pub/static/frontend/Codazon: 128M
  var/view_preprocessed/pub/static/frontend/Codazon: 89M

╔════════════════════════════════════════════════════════════╗
║            演练模式完成 - 未做任何更改                      ║
╚════════════════════════════════════════════════════════════╝
```

### 实际执行输出

```
╔════════════════════════════════════════════════════════════╗
║         Codazon Infinit Theme Uninstaller v1.0.0          ║
╚════════════════════════════════════════════════════════════╝

[INFO] Magento 根目录: /var/www/magento2

[INFO] 将要删除以下路径:
  📂 app/design/frontend/Codazon
  📂 app/code/Codazon
  ...

[WARNING] 此操作将永久删除 Codazon Infinit 主题及相关文件！
确认继续吗？(yes/no): yes

[INFO] 开始删除 Codazon 主题文件...
[SUCCESS] 已删除: app/design/frontend/Codazon
[SUCCESS] 已删除: app/code/Codazon
...

[INFO] 开始清理数据库中的主题配置...
[SUCCESS] 数据库配置清理完成

[INFO] 清理缓存...
[SUCCESS] 缓存清理完成

╔════════════════════════════════════════════════════════════╗
║       Codazon Infinit 主题卸载完成！                      ║
╚════════════════════════════════════════════════════════════╝

[SUCCESS] 所有操作已完成
[INFO] 建议重启 PHP-FPM 和 Nginx 服务

运行以下命令重启服务:
  sudo systemctl restart php8.3-fpm
  sudo systemctl restart nginx
```

## 🔗 相关工具

本项目中的其他有用工具：

- **数据库备份**: `/home/doge/ansible-lemp/dogetools/mysqldump.sh`
- **Magento 维护**: `/home/doge/ansible-lemp/scripts/magento2-maintenance.sh`
- **Magento 部署**: `/home/doge/ansible-lemp/scripts/magento-deploy.sh`
- **权限修复**: `/home/doge/ansible-lemp/scripts/magento-permissions.sh`
- **服务重启**: `/home/doge/ansible-lemp/dogetools/services-restart.sh`

## 📖 相关文档

- [DATABASE_CLEANUP.md](DATABASE_CLEANUP.md) - 数据库清理功能详细说明
- [QUICK_START.md](QUICK_START.md) - 快速开始指南

## 📄 版本历史

- **v1.1.0** (2025-10-02)
  - ✨ 新增直接数据库清理功能（`--direct-db`）
  - ✨ 新增显示数据库配置功能（`--show-db`）
  - ✨ 自动从 env.php 读取数据库配置
  - ✨ 两种数据库清理方式可选
  - 📚 添加数据库清理详细文档

- **v1.0.0** (2025-10-02)
  - 初始版本
  - 完整的主题卸载功能
  - 支持演练模式、备份、自动确认等选项
  - 彩色输出和详细日志

## 🤝 贡献

如果你发现 bug 或有改进建议，欢迎提交 Issue 或 Pull Request。

## 📞 支持

如有问题，请查看项目主 README 或联系维护者。

---

**⚠️ 重要提醒：此工具将永久删除主题文件，请务必先备份！**

