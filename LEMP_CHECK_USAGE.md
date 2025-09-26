# LEMP Check 环境检查工具使用说明

## 📋 功能介绍

`lemp-check.sh` 是一个功能强大的LEMP环境检查工具，可以快速查看所有13个组件的版本信息和运行状态。

## 🚀 使用方法

### 基本语法
```bash
./lemp-check.sh [选项]
```

### 📝 可用选项

| 选项 | 功能 | 示例 |
|------|------|------|
| `v` | 查看所有程序版本信息 | `./lemp-check.sh v` |
| `s` | 查看所有服务运行状态 | `./lemp-check.sh s` |
| `a` | 显示所有信息 (版本+状态+系统信息) | `./lemp-check.sh a` |
| `h` | 显示帮助信息 | `./lemp-check.sh h` |
| *(无参数)* | 默认显示所有信息 | `./lemp-check.sh` |

## 📊 检查的组件

### 1. 版本信息检查 (`./lemp-check.sh v`)
检查以下13个组件的版本：

1. **Ansible** - 自动化部署工具
2. **Composer** - PHP依赖管理器
3. **Nginx** - Web服务器 (1.28.0 + ModSecurity)
4. **PHP** - 脚本语言 (8.3.6)
5. **MySQL/Percona** - 数据库服务器 (8.4.6-6)
6. **RabbitMQ** - 消息队列 (4.1)
7. **Valkey** - Redis兼容缓存 (8)
8. **Varnish** - HTTP缓存 (7.6)
9. **OpenSearch** - 搜索引擎 (2.19)
10. **Fail2ban** - 入侵防护
11. **Webmin** - 系统管理 (2.200)
12. **phpMyAdmin** - 数据库管理 (5.2.1)
13. **Certbot** - SSL证书管理 (5.0.0)

### 2. 服务状态检查 (`./lemp-check.sh s`)
检查以下服务的运行状态和端口监听：

- **Nginx** (端口: 80, 443)
- **PHP-FPM** 
- **MySQL/Percona** (端口: 3306)
- **OpenSearch** (端口: 9200)
- **RabbitMQ** (端口: 5672, 15672)
- **Valkey** (端口: 6379)
- **Varnish** (端口: 6081)
- **Fail2ban**
- **Webmin** (端口: 10000)
- **phpMyAdmin** (nginx配置)
- **Certbot** (可用性)

## 🎨 输出格式

### 状态图标
- ✅ **绿色对勾** - 正常运行/已安装
- ❌ **红色叉号** - 未安装/未运行
- ⚠️ **黄色警告** - 部分问题/需要注意

### 颜色编码
- **绿色** - 正常状态
- **红色** - 错误状态
- **黄色** - 警告状态
- **蓝色** - 信息内容
- **紫色** - 摘要信息

## 🌐 快速访问信息

脚本会显示所有服务的访问地址：

### Web服务
- **主站**: http://localhost
- **phpMyAdmin**: http://localhost/phpmyadmin
- **Webmin**: https://localhost:10000

### API服务
- **OpenSearch**: http://localhost:9200
- **RabbitMQ管理**: http://localhost:15672

### 数据库
- **MySQL**: localhost:3306 (用户: root, 密码: SecurePassword123!)
- **Valkey**: localhost:6379

## 📈 系统信息

完整检查 (`./lemp-check.sh a`) 还包括：

- 操作系统版本
- 内核版本
- 内存使用情况
- 磁盘使用情况
- 系统负载

## 🔍 使用示例

### 快速检查所有服务状态
```bash
./lemp-check.sh s
```

### 查看所有程序版本
```bash
./lemp-check.sh v
```

### 完整环境检查
```bash
./lemp-check.sh a
```

### 显示帮助
```bash
./lemp-check.sh h
```

## 🛠️ 故障排除

### 常见问题

1. **权限错误**
   ```bash
   chmod +x lemp-check.sh
   ```

2. **缺少依赖**
   ```bash
   sudo apt install -y net-tools curl
   ```

3. **某些服务显示未运行**
   - 检查服务是否已启动: `sudo systemctl status 服务名`
   - 启动服务: `sudo systemctl start 服务名`

### 调试模式
如果脚本运行异常，可以查看详细错误：
```bash
bash -x ./lemp-check.sh v
```

## 📝 输出示例

```
==========================================
    LEMP Stack 环境检查工具
==========================================

📊 已安装程序: 13/13
🔄 运行中服务: 9/9
🎯 整体状态: 良好

📦 程序版本信息:
  ✅ Ansible: ansible [core 2.16.3]
  ✅ Composer: Composer version 2.8.12
  ✅ Nginx: nginx version: nginx/1.28.0
  ...

⚙️ 服务运行状态:
  ✅ Nginx: 运行中 (端口:80)
  ✅ PHP-FPM: 运行中
  ✅ MySQL/Percona: 运行中 (端口:3306)
  ...
```

## 🎯 最佳实践

1. **定期检查**: 建议定期运行检查脚本确保环境健康
2. **部署后验证**: 每次部署后运行完整检查
3. **问题诊断**: 遇到问题时先运行状态检查
4. **文档记录**: 保存检查结果作为环境文档

---

**🎉 享受您的LEMP环境检查体验！**
