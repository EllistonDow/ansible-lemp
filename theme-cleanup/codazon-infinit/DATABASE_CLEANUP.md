# 数据库清理功能说明

## 📊 两种数据库清理方式

### 方式 1：通过 Magento 命令（默认）

**优点**：
- ✅ 安全可靠，使用 Magento 官方 API
- ✅ 自动处理依赖关系
- ✅ 不需要额外的数据库权限

**缺点**：
- ❌ 如果 Magento 损坏，可能无法执行
- ❌ 清理不够彻底

**使用方法**：
```bash
# 默认就是使用 Magento 命令方式
./uninstall.sh /var/www/magento2
```

### 方式 2：直接数据库清理（高级）

**优点**：
- ✅ 更彻底，直接操作数据库表
- ✅ 即使 Magento 损坏也能执行
- ✅ 清理更多底层数据

**缺点**：
- ❌ 需要安装 mysql 客户端
- ❌ 需要数据库访问权限
- ❌ 风险稍高（建议先备份）

**使用方法**：
```bash
# 使用 --direct-db 选项
./uninstall.sh --direct-db /var/www/magento2
```

## 🔍 数据库配置自动读取

脚本会自动从 `app/etc/env.php` 读取数据库配置：

```bash
# 查看当前数据库配置
./uninstall.sh --show-db /var/www/magento2
```

**输出示例**：
```
╔════════════════════════════════════════════════════════════╗
║         Codazon Infinit Theme Uninstaller v1.0.0          ║
╚════════════════════════════════════════════════════════════╝

[INFO] 读取数据库配置...

[INFO] 数据库配置信息:
  Host: localhost
  Database: magento2
  User: magento
  Password: Sec***
  Table Prefix: m2_

[SUCCESS] 数据库配置读取完成
```

## 🎯 直接数据库清理会执行的操作

当使用 `--direct-db` 选项时，脚本会执行以下 SQL 操作：

### 1. 删除主题记录
```sql
DELETE FROM theme WHERE theme_path LIKE 'Codazon/%';
```

### 2. 删除模块记录 ⭐ NEW
```sql
DELETE FROM setup_module WHERE module LIKE 'Codazon_%';
```
**重要性**: ⭐⭐⭐ 避免 Magento 尝试加载不存在的模块

**清理的模块**（13个）：
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

### 3. 删除主题配置
```sql
DELETE FROM core_config_data WHERE path LIKE '%codazon%';
DELETE FROM core_config_data WHERE path LIKE '%infinit%';
```

### 4. 清理设计配置
```sql
DELETE FROM design_config_grid_flat WHERE theme_theme_id IN (
    SELECT theme_id FROM theme WHERE theme_path LIKE 'Codazon/%'
);
```

### 5. 重置为默认主题
```sql
UPDATE core_config_data SET value='2' WHERE path='design/theme/theme_id';
```

### 6. 清理 CMS 内容中的 Codazon 引用（v1.2.0 新增）
```sql
-- 删除包含 Codazon 的 CMS 块
DELETE FROM cms_block WHERE content LIKE '%Codazon%';

-- 删除包含 Codazon 的 CMS 页面
DELETE FROM cms_page WHERE content LIKE '%Codazon%';
```

**重要性**: ⭐⭐⭐⭐⭐ **极其重要！**

**背景**：
- CMS 块和页面可能包含大量混淆的 JavaScript 代码
- 这些代码会在运行时尝试调用已删除的 Codazon 类
- 如果不清理，会导致页面渲染失败，菜单无法显示

**实际案例**：
```
问题：网站菜单无法显示
原因：48 个 CMS 块（Newsletter Popup）包含 150KB+ 的混淆 JS 代码
      这些代码引用了 Codazon\Core\Helper\Data 等已删除的类
影响：整个页面加载失败
```

**清理的内容**：
- Newsletter Popup 块（各种主题风格）
- 产品页自定义块
- Codazon 专用页面（About Us, Gallery等）

## 🚀 使用场景

### 场景 1：正常卸载（推荐）
```bash
# 使用 Magento 命令，安全可靠
./uninstall.sh -b /var/www/magento2
```

### 场景 2：Magento 损坏无法执行命令
```bash
# 使用直接数据库清理
./uninstall.sh --direct-db -b /var/www/magento2
```

### 场景 3：先查看会清理什么
```bash
# 演练模式 + 直接数据库
./uninstall.sh -d --direct-db /var/www/magento2
```

### 场景 4：只清理数据库
```bash
# 只清理数据库，不删除文件
./uninstall.sh --db-only --direct-db /var/www/magento2
```

## ⚙️ 前置要求

### 使用 Magento 命令方式
- ✅ Magento 正常运行
- ✅ PHP CLI 可用
- ✅ 有 Magento 根目录的访问权限

### 使用直接数据库方式
- ✅ 安装了 `mysql` 客户端
- ✅ 数据库配置在 `app/etc/env.php` 中
- ✅ 数据库用户有 DELETE 和 UPDATE 权限

**安装 mysql 客户端**（如果没有）：
```bash
sudo apt install mysql-client -y
```

## 🔒 安全建议

### 使用直接数据库清理前：

1. **备份数据库**
   ```bash
   /home/doge/ansible-lemp/dogetools/mysqldump.sh <db_name> <db_name> > backup.sql
   ```

2. **先运行演练模式**
   ```bash
   ./uninstall.sh -d --direct-db /var/www/magento2
   ```

3. **查看数据库配置**
   ```bash
   ./uninstall.sh --show-db /var/www/magento2
   ```

4. **确认配置无误后执行**
   ```bash
   ./uninstall.sh --direct-db -b /var/www/magento2
   ```

## 🛠️ 故障排除

### 问题 1: mysql: command not found

**解决方案**：
```bash
# 安装 MySQL 客户端
sudo apt install mysql-client -y

# 或使用默认的 Magento 命令方式
./uninstall.sh /var/www/magento2  # 不加 --direct-db
```

### 问题 2: 无法读取数据库配置

**症状**：
```
[ERROR] 无法从 env.php 读取数据库配置
```

**解决方案**：
```bash
# 检查文件是否存在
ls -la /var/www/magento2/app/etc/env.php

# 检查文件权限
chmod 644 /var/www/magento2/app/etc/env.php
```

### 问题 3: Access denied for user

**症状**：数据库连接被拒绝

**解决方案**：
```bash
# 1. 检查数据库配置
./uninstall.sh --show-db /var/www/magento2

# 2. 测试数据库连接
mysql -h localhost -u magento -p magento2

# 3. 如果无法连接，使用 Magento 命令方式
./uninstall.sh /var/www/magento2
```

### 问题 4: 直接清理失败，自动回退

脚本设计了自动回退机制：
```bash
# 如果直接数据库清理失败，会自动尝试使用 Magento 命令
./uninstall.sh --direct-db /var/www/magento2
# 失败后会自动执行: php bin/magento ...
```

## 📋 完整命令参考

### 查看数据库配置
```bash
./uninstall.sh --show-db /var/www/magento2
```

### 演练直接数据库清理
```bash
./uninstall.sh -d --direct-db /var/www/magento2
```

### 带备份的直接数据库清理
```bash
./uninstall.sh -b --direct-db /var/www/magento2
```

### 自动确认 + 直接数据库清理
```bash
./uninstall.sh -y --direct-db /var/www/magento2
```

### 只清理数据库（直接方式）
```bash
./uninstall.sh --db-only --direct-db /var/www/magento2
```

### 组合使用
```bash
# 备份 + 演练 + 直接数据库
./uninstall.sh -d -b --direct-db /var/www/magento2

# 自动确认 + 备份 + 直接数据库
./uninstall.sh -y -b --direct-db /var/www/magento2
```

## 📊 清理效果对比

| 清理项 | Magento 命令 | 直接数据库 |
|--------|-------------|-----------|
| theme 表记录 | ✅ | ✅ |
| **setup_module 表** ⭐ | ✅ | ✅ |
| core_config_data | ✅ | ✅ |
| design_config_grid_flat | ❌ | ✅ |
| 其他配置表 | 部分 | 完全 |
| 孤立数据 | 可能残留 | 完全清理 |

## 💡 建议

1. **首次使用**：先用 Magento 命令方式（默认）
2. **Magento 损坏**：使用 `--direct-db` 选项
3. **追求彻底**：使用 `--direct-db` 选项
4. **安全第一**：始终使用 `-b` 备份选项
5. **不确定时**：先用 `-d` 演练模式

---

**⚠️ 重要提示**：直接数据库操作有风险，使用前请务必备份！

