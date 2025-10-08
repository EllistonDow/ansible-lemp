# RabbitMQ 站点管理工具

## 📋 概述

这是一个统一的 RabbitMQ 站点管理工具，专为 Magento 站点设计，提供完整的 RabbitMQ 虚拟主机、用户配置和队列消费者管理功能。

## 🚀 功能特点

### 主要功能
- ✅ **一键配置站点** - 自动创建虚拟主机、用户和 Magento 配置
- ✅ **智能消费者管理** - 启动/停止/重启队列消费者
- ✅ **内存监控** - 防止内存泄漏，自动重启高内存消费者
- ✅ **实时状态监控** - 查看进程状态、队列状态和配置信息
- ✅ **日志管理** - 完整的日志记录和查看
- ✅ **队列管理** - 清理队列和删除站点配置

### 性能优化
- 🔧 **内存限制** - 每个消费者限制 1GB 内存
- 🔧 **自动重启** - 内存超过 512MB 自动重启
- 🔧 **消息限制** - 每批处理消息数量限制
- 🔧 **单线程模式** - 避免并发冲突

## 📁 文件结构

```
magetools/
├── rabbitmq_manager.sh   # 统一管理脚本
└── RABBITMQ_CONFIG_README.md  # 使用说明
```

## 🛠️ 使用方法

### 统一命令格式

```bash
./rabbitmq_manager.sh <site_name> <action>
```

### 1. 配置站点

```bash
# 配置 ipwa 站点
./rabbitmq_manager.sh ipwa setup

# 配置 hawk 站点
./rabbitmq_manager.sh hawk setup
```

### 2. 管理消费者

```bash
# 启动消费者
./rabbitmq_manager.sh ipwa start

# 停止消费者
./rabbitmq_manager.sh ipwa stop

# 重启消费者
./rabbitmq_manager.sh ipwa restart

# 查看状态
./rabbitmq_manager.sh ipwa status

# 查看日志
./rabbitmq_manager.sh ipwa logs

# 监控内存
./rabbitmq_manager.sh ipwa monitor

# 清理队列
./rabbitmq_manager.sh ipwa clean

# 删除站点配置
./rabbitmq_manager.sh ipwa remove
```

## 📊 配置详情

### 自动生成的配置

| 站点名称 | 虚拟主机 | 用户名 | 密码 | 站点路径 |
|---------|---------|--------|------|----------|
| ipwa | /ipwa | ipwa_user | Ipwa#2025! | /home/doge/ipwa |
| hawk | /hawk | hawk_user | Hawk#2025! | /home/doge/hawk |

### 消费者配置

- **async.operations.all** - 异步操作队列 (1000 消息/批)
- **product_action_attribute.update** - 产品属性更新队列 (500 消息/批)

## 🔧 高级功能

### 内存监控

脚本会自动监控每个消费者的内存使用情况：

```bash
# 实时监控内存使用
./rabbitmq_manager.sh ipwa monitor

# 查看内存监控日志
tail -f /home/doge/logs/rabbitmq/ipwa_memory.log
```

### 日志管理

所有日志保存在 `/home/doge/logs/rabbitmq/` 目录：

```bash
# 查看所有日志
ls -la /home/doge/logs/rabbitmq/

# 查看特定站点日志
./rabbitmq_manager.sh ipwa logs
```

### 进程管理

```bash
# 查看消费者进程
./rabbitmq_manager.sh ipwa status

# 查看 PID 文件
cat /tmp/rabbitmq_consumers_ipwa.pid
```

## 🚨 故障排除

### 常见问题

1. **RabbitMQ 服务未运行**
   ```bash
   sudo systemctl start rabbitmq-server
   sudo systemctl enable rabbitmq-server
   ```

2. **站点目录不存在**
   ```bash
   # 确保站点目录存在
   ls -la /home/doge/ipwa
   ```

3. **Magento 文件不存在**
   ```bash
   # 确保 Magento 已安装
   ls -la /home/doge/ipwa/bin/magento
   ```

4. **权限问题**
   ```bash
   # 确保用户有权限访问站点目录
   sudo chown -R doge:www-data /home/doge/ipwa
   ```

### 手动操作

如果自动脚本出现问题，可以手动执行：

```bash
# 创建虚拟主机
sudo rabbitmqctl add_vhost /ipwa

# 创建用户
sudo rabbitmqctl add_user ipwa_user 'Ipwa#2025!'

# 设置权限
sudo rabbitmqctl set_permissions -p /ipwa ipwa_user ".*" ".*" ".*"

# 配置 Magento
cd /home/doge/ipwa
php bin/magento setup:config:set \
  --amqp-host="127.0.0.1" \
  --amqp-port=5672 \
  --amqp-user="ipwa_user" \
  --amqp-password='Ipwa#2025!' \
  --amqp-virtualhost="/ipwa"
```

## 📈 性能监控

### 队列状态监控

```bash
# 查看队列状态
./rabbitmq_manager.sh ipwa status

# 查看所有虚拟主机
sudo rabbitmqctl list_vhosts

# 查看所有用户
sudo rabbitmqctl list_users
```

### 系统资源监控

```bash
# 监控内存使用
./rabbitmq_manager.sh ipwa monitor

# 查看进程状态
./rabbitmq_manager.sh ipwa status
```

## 🔒 安全建议

1. **密码安全** - 使用强密码，定期更换
2. **权限最小化** - 每个站点使用独立用户
3. **网络隔离** - 使用虚拟主机隔离不同站点
4. **日志监控** - 定期检查日志文件

## 📝 更新日志

### v2.0.0 (2024-12-19)
- ✅ 合并配置和管理功能到单一脚本
- ✅ 新增 `setup` 操作用于一键配置站点
- ✅ 新增 `remove` 操作用于删除站点配置
- ✅ 改进状态显示，包含配置信息
- ✅ 优化用户体验和错误处理

### v1.0.0 (2024-12-19)
- ✅ 初始版本发布
- ✅ 支持自动站点配置
- ✅ 内存监控和自动重启
- ✅ 完整的日志管理
- ✅ 消费者管理工具

## 🤝 支持

如有问题或建议，请查看：
- 日志文件：`/home/doge/logs/rabbitmq/`
- 进程状态：`./rabbitmq_manager.sh <site> status`
- 系统日志：`journalctl -u rabbitmq-server`
