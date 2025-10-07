# Magetools - Magento 工具集

这个目录包含了用于管理 Magento 2 项目的各种工具脚本。

## 可用工具

### n98-magerun2.sh

n98-magerun2 的 Composer 安装和管理脚本。n98-magerun2 是一个强大的 Magento 2 命令行工具，提供了许多有用的命令来管理 Magento 2 项目。

#### 功能特性

- ✅ 使用 Composer 全局安装和管理 n98-magerun2
- ✅ 自动检测已安装的 Composer 版本
- ✅ 系统要求检查（PHP 版本、Composer 等）
- ✅ 安全的卸载功能
- ✅ 更新到最新版本
- ✅ 详细的安装状态检查
- ✅ PATH 配置检查和提示
- ✅ 彩色日志输出
- ✅ 详细的帮助信息

#### 使用方法

```bash
# 查看帮助信息
./n98-magerun2.sh help

# 使用 Composer 安装 n98-magerun2
./n98-magerun2.sh install

# 检查安装状态
./n98-magerun2.sh status

# 更新到最新版本
./n98-magerun2.sh update

# 卸载 n98-magerun2
./n98-magerun2.sh uninstall
```

#### 系统要求

- PHP 7.4 或更高版本（推荐 PHP 8.0+）
- Composer 已安装
- 不需要 root 权限（使用用户级 Composer 全局安装）

#### 安装位置

- Composer 全局 bin 目录: `~/.composer/vendor/bin/` 或 `~/.config/composer/vendor/bin/`
- 配置目录: `~/.composer/vendor/n98/magerun2`
- 缓存目录: `~/.cache/n98-magerun2`

#### PATH 配置

确保 Composer 全局 bin 目录在 PATH 中：

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
export PATH="$PATH:$(composer global config bin-dir --absolute)"

# 或者手动指定路径
export PATH="$PATH:$HOME/.composer/vendor/bin"
```

#### 使用示例

安装完成后，你可以在任何 Magento 2 项目目录中使用 n98-magerun2：

```bash
# 查看可用命令
n98-magerun2 list

# 查看帮助
n98-magerun2 --help

# 清除缓存
n98-magerun2 cache:clean

# 重新索引
n98-magerun2 indexer:reindex

# 查看系统信息
n98-magerun2 sys:info
```

## 维护页面设计

`maintenance-page-design/` 目录包含了 Magento 2 维护页面的设计模板。

### 2025 年维护页面

- `2025/503.phtml` - 现代化的维护页面模板

## 贡献

欢迎提交问题和改进建议。请确保：

1. 脚本具有良好的错误处理
2. 包含详细的帮助信息
3. 遵循项目的编码规范
4. 测试所有功能

## 许可证

本项目遵循项目根目录中的 LICENSE 文件。
