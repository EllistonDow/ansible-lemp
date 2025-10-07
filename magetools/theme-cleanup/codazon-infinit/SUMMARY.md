# Codazon Infinit 主题卸载工具 - 功能总结

## 🔥 v1.2.0 重大更新（2025-10-02）

### 新增：CMS 内容清理（第4层清理）

**问题背景**：
- 即使删除了所有文件和清理了数据库
- 网站菜单和部分页面仍然无法显示

**根本原因**：
- **48 个 CMS 块**包含混淆的 JavaScript 代码（每个 150KB+）
- 这些 JS 引用已删除的 Codazon 类（如 `Codazon\Core\Helper\Data`）
- 页面加载时尝试调用不存在的类，导致整个页面渲染失败

**解决方案**：
```sql
-- 自动清理包含 Codazon 的 CMS 内容
DELETE FROM cms_block WHERE content LIKE '%Codazon%';
DELETE FROM cms_page WHERE content LIKE '%Codazon%';
```

### 现在支持 4 层完整清理

| 清理层 | 版本 | 清理内容 | 重要性 |
|-------|------|---------|--------|
| **1. 文件系统层** | v1.0.0 | 删除主题和模块文件 | ⭐⭐⭐ |
| **2. 数据库基础层** | v1.1.0 | theme、core_config_data、design_config_grid_flat | ⭐⭐⭐ |
| **3. 数据库深度层** | v1.1.2/v1.1.3 | setup_module、eav_attribute 引用 | ⭐⭐⭐⭐ |
| **4. CMS 内容层** | v1.2.0 | cms_block、cms_page | ⭐⭐⭐⭐⭐ |

---

## 🎯 核心功能

### 1. 数据库配置管理 ⭐ NEW

#### 查看数据库配置
脚本可以自动从 `app/etc/env.php` 读取数据库配置：

```bash
./uninstall.sh --show-db /var/www/magento2
```

**输出示例**：
```
[INFO] 数据库配置信息:
  Host: localhost
  Database: magento2
  User: magento
  Password: Sec***
  Table Prefix: m2_
```

### 2. 双模式数据库清理 ⭐ NEW

#### 方式 A：Magento 命令（默认）
```bash
./uninstall.sh /var/www/magento2
```
- ✅ 安全可靠，使用官方 API
- ✅ 自动处理依赖
- ❌ Magento 损坏时可能失败

#### 方式 B：直接数据库（高级）
```bash
./uninstall.sh --direct-db /var/www/magento2
```
- ✅ 更彻底，直接操作数据库
- ✅ 即使 Magento 损坏也能运行
- ⚠️ 需要 mysql 客户端

### 3. 完整文件删除

删除以下所有 Codazon 相关文件：
```
✓ app/design/frontend/Codazon       (主题设计文件)
✓ app/code/Codazon                  (模块代码)
✓ pub/static/frontend/Codazon       (静态资源)
✓ var/view_preprocessed/...         (预处理文件)
✓ generated/code/Codazon            (生成的代码)
✓ generated/metadata/Codazon        (元数据)
✓ var/cache                         (缓存)
```

### 4. 数据库深度清理 ⭐ NEW

直接数据库模式会清理：
```sql
✓ theme 表 - Codazon 主题记录
✓ core_config_data - 所有相关配置
✓ design_config_grid_flat - 设计配置
✓ 重置为默认 Luma 主题
```

## 🛠️ 所有命令选项

| 选项 | 说明 | 版本 |
|------|------|------|
| `-h, --help` | 显示帮助信息 | v1.0.0 |
| `-d, --dry-run` | 演练模式，不实际删除 | v1.0.0 |
| `-y, --yes` | 自动确认，跳过提示 | v1.0.0 |
| `-b, --backup` | 先备份再删除 | v1.0.0 |
| `--db-only` | 仅清理数据库 | v1.0.0 |
| `--files-only` | 仅删除文件 | v1.0.0 |
| `--direct-db` | 直接数据库清理 ⭐ | v1.1.0 |
| `--show-db` | 显示数据库配置 ⭐ | v1.1.0 |

## 📋 常用使用场景

### 场景 1：首次使用（最安全）
```bash
# 1. 查看数据库配置
./uninstall.sh --show-db /var/www/magento2

# 2. 演练看看会删除什么
./uninstall.sh -d /var/www/magento2

# 3. 确认无误后执行
./uninstall.sh -b /var/www/magento2
```

### 场景 2：快速卸载（已确认）
```bash
./uninstall.sh -y /var/www/magento2
```

### 场景 3：彻底清理（推荐）
```bash
# 备份 + 直接数据库清理
./uninstall.sh -b --direct-db /var/www/magento2
```

### 场景 4：Magento 损坏
```bash
# 使用直接数据库模式
./uninstall.sh --direct-db /var/www/magento2
```

### 场景 5：只清理数据库
```bash
# 不删除文件，只清理数据库
./uninstall.sh --db-only --direct-db /var/www/magento2
```

### 场景 6：只删除文件
```bash
# 不清理数据库，只删除文件
./uninstall.sh --files-only /var/www/magento2
```

## 🔄 工作流程

```
┌─────────────────────────────────────────────────────────┐
│  1. 读取配置                                              │
│     - 检查 Magento 根目录                                 │
│     - 读取数据库配置（如果使用 --direct-db）              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  2. 显示信息                                              │
│     - 列出将要删除的路径                                  │
│     - 显示文件大小统计                                    │
│     - 显示数据库配置（--direct-db）                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  3. 确认操作                                              │
│     - 显示警告信息                                        │
│     - 等待用户确认（除非使用 -y）                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  4. 备份（可选 -b）                                       │
│     - 备份到 backup/codazon-theme-YYYYMMDD-HHMMSS/       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  5. 删除文件（除非 --db-only）                            │
│     - 删除所有 Codazon 相关文件                           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  6. 清理数据库（除非 --files-only）                       │
│     - 方式A: Magento 命令（默认）                         │
│     - 方式B: 直接数据库（--direct-db）                    │
│     - 失败自动回退到方式A                                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  7. 清理缓存                                              │
│     - cache:clean                                         │
│     - cache:flush                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  8. 重新编译（可选）                                      │
│     - setup:di:compile                                    │
│     - setup:static-content:deploy                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  9. 完成                                                  │
│     - 显示成功信息                                        │
│     - 提示重启服务                                        │
└─────────────────────────────────────────────────────────┘
```

## 📊 数据库清理对比

| 清理项目 | Magento 命令 | 直接数据库 |
|---------|-------------|-----------|
| theme 表 | ✅ | ✅ |
| core_config_data | ✅ | ✅ |
| design_config_grid_flat | ❌ | ✅ |
| 孤立配置 | 部分 | 完全 |
| 深度清理 | 基础 | 彻底 |
| 需要 Magento | ✅ 必需 | ❌ 不需要 |
| 需要 mysql 客户端 | ❌ | ✅ 需要 |
| 失败风险 | Magento 损坏时 | 数据库权限不足时 |

## 🔒 安全特性

### 1. 演练模式（-d）
- 显示所有将要执行的操作
- 不实际删除任何文件
- 不修改数据库

### 2. 备份功能（-b）
- 自动备份到 `backup/` 目录
- 时间戳命名，不会覆盖
- 不备份 var/cache（太大）

### 3. 交互确认
- 删除前需要输入 "yes" 确认
- 重新编译前需要确认
- 使用 `-y` 可跳过

### 4. 密码保护
- 显示数据库配置时自动隐藏密码
- 只显示前3位：`Sec***`

### 5. 错误回退
- 直接数据库失败自动回退到 Magento 命令
- 智能错误处理

## 📚 文档结构

```
theme-cleanup/codazon-infinit/
├── uninstall.sh           # 主脚本（14KB）
├── README.md              # 完整文档（11KB）
├── QUICK_START.md         # 快速开始（1.7KB）
├── DATABASE_CLEANUP.md    # 数据库清理详解（6.3KB）
├── CHANGELOG.md           # 更新日志（4.7KB）
└── SUMMARY.md             # 本文档
```

## 🎓 学习路径

### 新手用户
1. 阅读 `QUICK_START.md`（3分钟）
2. 运行 `./uninstall.sh --help`
3. 使用演练模式：`./uninstall.sh -d /path`
4. 执行：`./uninstall.sh -b /path`

### 进阶用户
1. 阅读 `README.md`
2. 了解 `DATABASE_CLEANUP.md`
3. 尝试 `--show-db` 查看配置
4. 使用 `--direct-db` 深度清理

### 高级用户
1. 查看 `CHANGELOG.md` 了解技术细节
2. 阅读脚本源码
3. 根据需要修改和扩展

## 💻 技术亮点

### 1. 智能配置读取
```bash
# 使用 PHP 读取 env.php
DB_HOST=$(php -r "include 'app/etc/env.php'; echo \$config['db']['connection']['default']['host'] ?? 'localhost';")
```

### 2. SQL 批量操作
```sql
-- 一次性清理多个表
DELETE FROM theme WHERE theme_path LIKE 'Codazon/%';
DELETE FROM core_config_data WHERE path LIKE '%codazon%';
...
```

### 3. 彩色日志输出
```bash
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
```

### 4. 错误自动回退
```bash
if [ $DIRECT_DB -eq 1 ]; then
    clean_database_direct || clean_database  # 失败自动回退
else
    clean_database
fi
```

## 🚀 性能优化

- 并行删除文件
- 批量 SQL 操作
- 缓存一次性清理
- 智能跳过不存在的路径

## 📞 获取帮助

1. **查看帮助**：`./uninstall.sh --help`
2. **阅读文档**：`README.md`
3. **故障排除**：`DATABASE_CLEANUP.md` 故障排除章节
4. **更新日志**：`CHANGELOG.md`

## ⚡ 快速参考卡

```bash
# 最常用的 5 个命令

# 1. 查看帮助
./uninstall.sh --help

# 2. 演练模式
./uninstall.sh -d /var/www/magento2

# 3. 安全卸载
./uninstall.sh -b /var/www/magento2

# 4. 彻底清理
./uninstall.sh -b --direct-db /var/www/magento2

# 5. 查看数据库
./uninstall.sh --show-db /var/www/magento2
```

---

**版本**: v1.1.0  
**更新日期**: 2025-10-02  
**作者**: DogeTools  
**许可**: MIT  

**⚠️ 重要提醒**：使用前请务必备份数据库！

