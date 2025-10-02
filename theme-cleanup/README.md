# Theme Cleanup Tools

Magento 主题卸载和清理工具集

## 📁 目录结构

```
theme-cleanup/
├── README.md                    # 本文件
└── codazon-infinit/             # Codazon Infinit 主题卸载工具
    ├── uninstall.sh             # 卸载脚本
    ├── README.md                # 详细文档
    └── QUICK_START.md           # 快速开始指南
```

## 🎯 可用工具

### Codazon Infinit Theme Uninstaller

专门用于卸载和清空 Codazon Infinit 主题的工具。

**快速使用**：
```bash
cd codazon-infinit
./uninstall.sh --help
```

**功能特性**：
- ✅ 完全删除主题文件（design、code、static、generated 等）
- ✅ 清理数据库配置
- ✅ 重置为默认 Luma 主题
- ✅ 支持演练模式（dry-run）
- ✅ 支持备份功能
- ✅ 彩色输出和详细日志

**文档**：
- [快速开始](codazon-infinit/QUICK_START.md)
- [完整文档](codazon-infinit/README.md)

## 🚀 快速开始

### 卸载 Codazon Infinit 主题

```bash
# 进入工具目录
cd /home/doge/ansible-lemp/theme-cleanup/codazon-infinit

# 先演练看看会删除什么
./uninstall.sh -d /var/www/magento2

# 确认无误后执行卸载（带备份）
./uninstall.sh -b /var/www/magento2

# 重启服务
sudo systemctl restart php8.3-fpm nginx
```

## 📝 添加新的主题清理工具

如果你需要为其他主题创建清理工具，可以参考 `codazon-infinit/` 的结构：

```bash
# 创建新的主题清理工具目录
mkdir -p theme-cleanup/your-theme-name

# 复制模板
cp codazon-infinit/uninstall.sh theme-cleanup/your-theme-name/
cp codazon-infinit/README.md theme-cleanup/your-theme-name/
cp codazon-infinit/QUICK_START.md theme-cleanup/your-theme-name/

# 修改脚本中的主题路径和配置
vim theme-cleanup/your-theme-name/uninstall.sh

# 更新文档
vim theme-cleanup/your-theme-name/README.md
```

## 🔗 相关工具

本项目中的其他有用工具：

| 工具 | 路径 | 说明 |
|------|------|------|
| 数据库备份 | `/dogetools/mysqldump.sh` | MySQL 数据库备份工具 |
| Magento 维护 | `/scripts/magento2-maintenance.sh` | Magento 维护模式管理 |
| Magento 部署 | `/scripts/magento-deploy.sh` | Magento 自动化部署 |
| 权限修复 | `/scripts/magento-permissions.sh` | Magento 权限修复 |
| 服务重启 | `/dogetools/services-restart.sh` | 批量重启 LEMP 服务 |

## ⚠️ 重要提示

1. **使用任何卸载工具前，请务必先备份数据库！**
2. **建议先使用演练模式（`-d` 参数）查看将要删除的内容**
3. **确保在正确的 Magento 根目录下操作**
4. **卸载后记得重启相关服务（PHP-FPM、Nginx 等）**

## 📄 版本历史

- **v1.0.0** (2025-10-02)
  - 创建 theme-cleanup 工具目录
  - 添加 Codazon Infinit 主题卸载工具

## 🤝 贡献

如果你开发了其他主题的清理工具，欢迎提交到这个目录！

---

**Built with ❤️ for the Magento community**

