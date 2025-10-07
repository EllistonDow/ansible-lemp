# 更新日志

## [1.2.0] - 2025-10-02

### 🔥 重大更新

#### CMS 内容清理（第4层清理）
- **问题**: 网站菜单无法显示
- **原因**: CMS 块和页面中包含混淆的 JavaScript 代码引用已删除的 Codazon 类
- **影响**: 页面渲染失败，导致菜单和其他 UI 元素无法显示

#### 发现的问题
```
✅ 已删除 Codazon 文件
✅ 已清理数据库主题记录
✅ 已清理模块记录
✅ 已清理 EAV 属性引用
❌ 但页面仍然加载失败 → CMS 内容中有 Codazon 引用！
```

#### 清理的 CMS 内容
- **48 个 CMS 块**: 主要是 Newsletter Popup（含 150KB+ 混淆 JS 代码）
  ```
  unlimited-*-newsletter-popup
  unlimited-product-view-custom-block-*
  等等...
  ```
- **2 个 CMS 页面**: 
  - codazon-about-us
  - codazon-gallery

#### 解决方案
新增第4层清理：CMS 内容层
```sql
-- 删除包含 Codazon 的 CMS 块
DELETE FROM cms_block WHERE content LIKE '%Codazon%';

-- 删除包含 Codazon 的 CMS 页面
DELETE FROM cms_page WHERE content LIKE '%Codazon%';
```

#### 修复效果
**修复前**：
```
❌ 网站菜单无法显示
❌ 页面加载失败
❌ JavaScript 报错（引用不存在的 Codazon 类）
```

**修复后**：
```
✅ 网站菜单正常显示
✅ 页面正常加载
✅ 无 JavaScript 错误
```

### 🏗️ 清理层次总结

现在脚本支持 **4 层完整清理**：

1. **文件系统层**（v1.0.0）
   - 删除主题和模块文件
   
2. **数据库基础层**（v1.1.0）
   - 清理 theme、core_config_data、design_config_grid_flat
   
3. **数据库深度层**（v1.1.2 & v1.1.3）
   - v1.1.2: 清理 setup_module（模块记录）
   - v1.1.3: 清理 eav_attribute（属性引用）
   
4. **CMS 内容层**（v1.2.0）← 新增
   - 清理 cms_block（CMS 块）
   - 清理 cms_page（CMS 页面）

### 📝 重要说明
- CMS 块和页面可能包含大量混淆的 JavaScript 代码
- 这些代码在运行时会尝试调用已删除的 Codazon 类
- 必须彻底删除这些内容，否则页面渲染会失败
- 建议清理前先备份数据库

---

## [1.1.3] - 2025-10-02

### 🐛 重要修复

#### EAV 属性引用清理
- **问题**: 索引时出现 `Class "Codazon\ThemeLayoutPro\Model\Category\Attribute\Backend\Image" does not exist` 错误
- **原因**: `eav_attribute` 表中的属性仍在引用 Codazon 的 backend_model/frontend_model/source_model
- **影响**: 导致 Catalog Search 索引失败

#### 发现的 Codazon 属性
```sql
-- 6 个 Codazon 相关属性
codazon_custom_tab         (text)
cdz_thumbnail_image        (varchar) ← backend_model 引用 Codazon 类
cdz_thumbnail_enable       (int)
cdz_thumbnail_exclude      (int)
cdz_pimg_width            (int)
cdz_pimg_height           (int)
```

#### 解决方案
新增 SQL 清理操作：
```sql
-- 清空属性中的 Codazon 模型引用
UPDATE eav_attribute SET backend_model = NULL WHERE backend_model LIKE '%Codazon%';
UPDATE eav_attribute SET frontend_model = NULL WHERE frontend_model LIKE '%Codazon%';
UPDATE eav_attribute SET source_model = NULL WHERE source_model LIKE '%Codazon%';
```

#### 修复效果
**修复前**：
```
❌ Catalog rule indexing failed
❌ Class "Codazon\ThemeLayoutPro\Model\Category\Attribute\Backend\Image" does not exist
❌ Catalog Search index process error
```

**修复后**：
```
✅ 所有 14 个索引全部成功
✅ Stock index rebuilt successfully
✅ Catalog Search index rebuilt successfully
✅ Product Price index rebuilt successfully
... (全部成功)
```

### 📝 说明
- 属性本身**不会被删除**，只清空模型引用
- 如需完全删除这些属性，可手动执行：
  ```sql
  DELETE FROM eav_attribute WHERE attribute_code LIKE 'cdz_%' OR attribute_code LIKE '%codazon%';
  ```

---

## [1.1.2] - 2025-10-02

### ✨ 重要改进

#### 添加模块记录清理
- **新增**: 直接数据库清理现在会删除 `setup_module` 表中的模块记录
- **影响**: 解决了文件删除后模块记录残留的问题
- **重要性**: ⭐⭐⭐ 避免 Magento 尝试加载不存在的模块

#### 清理的模块
自动清理以下 Codazon 模块记录：
- Codazon_AjaxLayeredNavPro
- Codazon_Core
- Codazon_GoogleAmpManager
- Codazon_Lookbookpro
- Codazon_MegaMenu
- Codazon_ProductFilter
- Codazon_ProductLabel
- Codazon_QuickShop
- Codazon_SalesPro
- Codazon_ShippingCostCalculator
- Codazon_Shopbybrandpro
- Codazon_ShoppingCartPro
- Codazon_ThemeLayoutPro

#### 新增 SQL 操作
```sql
-- 删除模块记录（新增）
DELETE FROM setup_module WHERE module LIKE 'Codazon_%';
```

### 💡 使用场景说明

**传统方式**（推荐但不总是可行）：
```bash
# 1. 先禁用模块
php bin/magento module:disable Codazon_Core Codazon_ThemeLayoutPro ...
# 2. 删除文件
# 3. 清理数据库
```

**直接清理方式**（文件已删除或 Magento 损坏）：
```bash
# 使用 --direct-db 一次性清理所有
./uninstall.sh --direct-db /path/to/magento
```

现在 `--direct-db` 模式会自动清理：
- ✅ 主题文件
- ✅ 主题数据库记录
- ✅ **模块数据库记录** ← 新增
- ✅ 配置数据
- ✅ 设计配置

---

## [1.1.1] - 2025-10-02

### 🐛 Bug 修复

#### 数据库配置读取问题
- **问题**: `--show-db` 和 `--direct-db` 无法读取 env.php 配置
- **原因**: PHP `include` 语句没有赋值给变量
- **修复**: 将 `include 'app/etc/env.php'` 改为 `$config = include 'app/etc/env.php'`
- **影响**: 所有需要读取数据库配置的功能

#### 修复前的代码：
```bash
DB_HOST=$(php -r "include 'app/etc/env.php'; echo \$config['db']['connection']['default']['host'] ?? 'localhost';")
```

#### 修复后的代码：
```bash
DB_HOST=$(php -r "\$config = include 'app/etc/env.php'; echo \$config['db']['connection']['default']['host'] ?? 'localhost';")
```

### ✅ 测试结果

修复后成功读取配置：
```
[INFO] 数据库配置信息:
  Host: localhost
  Database: bdgymage
  User: bdgy
  Password: bdg***
[SUCCESS] 数据库配置读取完成
```

---

## [1.1.0] - 2025-10-02

### ✨ 新增功能

#### 1. 双模式数据库清理
- **Magento 命令模式**（默认）：使用 `php bin/magento` 命令，安全可靠
- **直接数据库模式**（`--direct-db`）：直接操作数据库，更彻底

#### 2. 数据库配置自动读取
- 从 `app/etc/env.php` 自动读取数据库配置
- 支持读取：host, dbname, username, password, table_prefix
- 新增 `--show-db` 选项显示数据库配置（密码部分隐藏）

#### 3. 增强的数据库清理
直接数据库模式会清理：
- `theme` 表中的 Codazon 主题记录
- `core_config_data` 中所有相关配置
- `design_config_grid_flat` 中的设计配置
- 自动重置为默认 Luma 主题

### 🔧 改进

#### 命令行选项
- 新增 `--direct-db`：使用直接数据库清理
- 新增 `--show-db`：显示数据库配置信息
- 优化帮助信息，添加新选项说明

#### 错误处理
- 直接数据库清理失败时自动回退到 Magento 命令方式
- 更好的错误提示和日志信息

### 📚 文档

新增文档：
- `DATABASE_CLEANUP.md`：数据库清理功能详细说明
  - 两种清理方式对比
  - 使用场景说明
  - 前置要求检查
  - 安全建议
  - 故障排除

更新文档：
- `README.md`：添加数据库清理方式说明
- `QUICK_START.md`：添加新命令速查表

### 🔒 安全性

- 数据库密码在显示时自动隐藏（只显示前3位）
- 演练模式支持直接数据库清理
- 建议使用前先备份数据库

### 📊 技术细节

#### 数据库配置读取
```bash
# 使用 PHP 从 env.php 读取配置
DB_HOST=$(php -r "include 'app/etc/env.php'; echo \$config['db']['connection']['default']['host'] ?? 'localhost';")
DB_NAME=$(php -r "include 'app/etc/env.php'; echo \$config['db']['connection']['default']['dbname'] ?? '';")
...
```

#### SQL 清理操作
```sql
DELETE FROM theme WHERE theme_path LIKE 'Codazon/%';
DELETE FROM core_config_data WHERE path LIKE '%codazon%';
DELETE FROM core_config_data WHERE path LIKE '%infinit%';
...
```

### 📈 使用示例

```bash
# 查看数据库配置
./uninstall.sh --show-db /var/www/magento2

# 使用直接数据库清理
./uninstall.sh --direct-db /var/www/magento2

# 带备份的直接数据库清理
./uninstall.sh -b --direct-db /var/www/magento2

# 演练直接数据库清理
./uninstall.sh -d --direct-db /var/www/magento2
```

---

## [1.0.0] - 2025-10-02

### ✨ 初始发布

#### 核心功能
- 完整的主题文件删除
- 数据库配置清理（通过 Magento 命令）
- 缓存清理
- 重新编译支持

#### 选项支持
- `-h, --help`：帮助信息
- `-d, --dry-run`：演练模式
- `-y, --yes`：自动确认
- `-b, --backup`：备份功能
- `--db-only`：仅清理数据库
- `--files-only`：仅删除文件

#### 删除范围
- `app/design/frontend/Codazon`
- `app/code/Codazon`
- `pub/static/frontend/Codazon`
- `var/view_preprocessed/pub/static/frontend/Codazon`
- `var/cache`
- `generated/code/Codazon`
- `generated/metadata/Codazon`

#### 文档
- `README.md`：完整使用文档
- `QUICK_START.md`：快速开始指南

#### 特性
- ✅ 彩色日志输出
- ✅ 详细的统计信息
- ✅ 交互式确认提示
- ✅ 备份到 `backup/` 目录
- ✅ 安全的错误处理

---

## 版本对比

| 功能 | v1.0.0 | v1.1.0 |
|------|--------|--------|
| 文件删除 | ✅ | ✅ |
| Magento 命令清理 | ✅ | ✅ |
| 直接数据库清理 | ❌ | ✅ |
| 显示数据库配置 | ❌ | ✅ |
| 自动读取配置 | ❌ | ✅ |
| 深度数据库清理 | ❌ | ✅ |
| 演练模式 | ✅ | ✅ |
| 备份功能 | ✅ | ✅ |
| 错误自动回退 | ❌ | ✅ |

---

## 升级建议

### 从 v1.0.0 升级到 v1.1.0

1. **直接替换脚本文件即可**
   ```bash
   # 备份旧版本（可选）
   cp uninstall.sh uninstall.sh.v1.0.0
   
   # 下载新版本
   # （直接使用新的 uninstall.sh）
   ```

2. **所有旧版本命令仍然兼容**
   ```bash
   # 这些命令在新版本中仍然正常工作
   ./uninstall.sh /var/www/magento2
   ./uninstall.sh -d /var/www/magento2
   ./uninstall.sh -b -y /var/www/magento2
   ```

3. **尝试新功能**
   ```bash
   # 查看数据库配置
   ./uninstall.sh --show-db /var/www/magento2
   
   # 使用更彻底的清理方式
   ./uninstall.sh --direct-db /var/www/magento2
   ```

---

## 路线图

### v1.2.0（计划中）
- [ ] 支持自定义数据库连接信息
- [ ] 支持清理日志文件
- [ ] 添加清理进度条
- [ ] 支持静默模式（无交互）
- [ ] 生成清理报告

### v1.3.0（计划中）
- [ ] 支持其他 Codazon 主题
- [ ] Web 界面管理
- [ ] 定时清理任务
- [ ] 清理历史记录

---

**反馈和建议**：欢迎通过 GitHub Issues 提交！

