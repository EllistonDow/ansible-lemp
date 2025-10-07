# 快速开始 - Codazon Infinit 主题卸载

## ⚡ 3步完成卸载

### 第一步：进入目录
```bash
cd /home/doge/ansible-lemp/theme-cleanup/codazon-infinit
```

### 第二步：查看帮助
```bash
./uninstall.sh --help
```

### 第三步：执行卸载

#### 🔍 新手推荐（安全）

```bash
# 1. 先演练看看会删除什么
./uninstall.sh -d /var/www/magento2

# 2. 确认无误后，带备份卸载
./uninstall.sh -b /var/www/magento2

# 3. 重启服务
sudo systemctl restart php8.3-fpm nginx
```

#### ⚡ 熟练用户（快速）

```bash
# 一键卸载
./uninstall.sh -y /var/www/magento2 && sudo systemctl restart php8.3-fpm nginx
```

## 📋 常用命令速查

| 场景 | 命令 |
|------|------|
| 查看帮助 | `./uninstall.sh -h` |
| 演练模式 | `./uninstall.sh -d /var/www/magento2` |
| 带备份卸载 | `./uninstall.sh -b /var/www/magento2` |
| 自动确认卸载 | `./uninstall.sh -y /var/www/magento2` |
| 仅删文件 | `./uninstall.sh --files-only /var/www/magento2` |
| 仅清数据库 | `./uninstall.sh --db-only /var/www/magento2` |
| 查看数据库配置 | `./uninstall.sh --show-db /var/www/magento2` |
| 直接数据库清理 | `./uninstall.sh --direct-db /var/www/magento2` |
| 彻底清理（推荐） | `./uninstall.sh -b --direct-db /var/www/magento2` |

## ⚠️ 注意事项

1. **使用前请先备份数据库！**
2. **先用 `-d` 参数演练一遍**
3. **确保 Magento 根目录路径正确**
4. **卸载后记得重启服务**

## 🔗 详细文档

查看 [README.md](README.md) 了解完整功能和故障排除。

---
**💡 提示**: 如果遇到问题，运行 `./uninstall.sh --help` 查看所有选项

