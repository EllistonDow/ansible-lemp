# Magetools - Magento 工具集

这个目录包含了用于管理 Magento 2 项目的各种工具脚本。

## 可用工具

### memory-monitor.sh

智能内存监控和自动释放脚本。监控系统内存使用率，达到阈值时自动释放内存，确保系统稳定运行。

#### 功能特性

- ✅ 实时监控内存、Swap、CPU使用率
- ✅ 可配置的警戒线阈值
- ✅ 自动内存释放机制
- ✅ 多级缓存清理策略
- ✅ 持续监控和一次性检查模式
- ✅ 详细的日志记录
- ✅ 防重复运行保护

#### 使用方法

```bash
# 持续监控模式（推荐用于生产环境）
sudo ./memory-monitor.sh monitor

# 一次性检查模式
sudo ./memory-monitor.sh check

# 立即执行内存释放
sudo ./memory-monitor.sh release

# 显示当前系统状态
sudo ./memory-monitor.sh status

# 自定义阈值监控
sudo ./memory-monitor.sh monitor --threshold=90 --swap-threshold=20
```

#### 自动释放策略

当内存使用率超过阈值时，脚本会自动执行以下清理操作：

1. **系统缓存清理**：清理页面缓存、目录项缓存
2. **Swap空间清理**：重置Swap使用
3. **PHP缓存清理**：重新加载PHP-FPM，清理OPcache
4. **Valkey缓存清理**：清理过期键
5. **MySQL缓存清理**：刷新表缓存和查询缓存

#### 配置参数

- **内存阈值**：85%（默认）
- **Swap阈值**：30%（默认）
- **CPU阈值**：80%（默认）
- **检查间隔**：30秒（监控模式）

#### 日志文件

- 位置：`/var/log/memory-monitor.log`
- 记录所有操作和告警信息

#### 自动化部署

使用 `memory-monitor-service.sh` 脚本可以自动安装和管理服务：

```bash
# 安装为系统服务（推荐）
sudo ./memory-monitor-service.sh install
sudo ./memory-monitor-service.sh start

# 安装定时任务
sudo ./memory-monitor-service.sh cron-install

# 查看服务状态
sudo ./memory-monitor-service.sh status

# 查看实时日志
sudo ./memory-monitor-service.sh logs
```

#### 服务特性

- ✅ **自动启动**：系统重启后自动启动
- ✅ **自动重启**：服务异常时自动重启
- ✅ **定时任务**：每5分钟检查，每天深度清理
- ✅ **系统集成**：systemd服务管理
- ✅ **日志记录**：systemd journal集成

### memory-monitor-service.sh

内存监控服务管理脚本。用于安装、配置和管理内存监控服务，支持系统服务和定时任务。

#### 功能特性

- ✅ 一键安装/卸载系统服务
- ✅ systemd服务管理
- ✅ 定时任务配置
- ✅ 服务参数配置
- ✅ 日志查看和管理
- ✅ 自动启动和重启

#### 使用方法

```bash
# 安装服务
sudo ./memory-monitor-service.sh install

# 启动服务
sudo ./memory-monitor-service.sh start

# 查看状态
sudo ./memory-monitor-service.sh status

# 安装定时任务
sudo ./memory-monitor-service.sh cron-install

# 查看日志
sudo ./memory-monitor-service.sh logs

# 配置参数
sudo ./memory-monitor-service.sh configure
```

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
