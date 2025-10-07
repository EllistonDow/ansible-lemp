# 更新日志

## 版本 2.2.2 (2024-12-19)

### 🎉 新增功能
- **智能权限管理**: 自动检查和修复 Docker 权限问题
- **权限自动修复**: 新增 `--fix-perms` 参数，专门用于修复权限问题
- **无 sudo 权限测试**: 安装完成后自动测试无 sudo 权限的 Docker 访问
- **权限状态验证**: 提供详细的权限状态反馈和故障排除指导

### 🔧 改进功能
- **智能用户组配置**: 避免重复添加用户到 docker 组
- **增强的安装后说明**: 提供完整的权限管理指导
- **权限故障排除**: 添加详细的权限问题解决方案

### 📁 新增文件
- `dogetools/test-docker-permissions.sh`: Docker 权限测试脚本
- `dogetools/DOCKER_PERMISSIONS_GUIDE.md`: Docker 权限管理指南
- `GITHUB_SSH_SETUP.md`: GitHub SSH 配置说明

### 🚀 使用方法
```bash
# 正常安装（包含权限管理）
./install-docker.sh

# 快速安装
./install-docker.sh --quick

# 修复权限问题
./install-docker.sh --fix-perms

# 测试权限状态
./test-docker-permissions.sh
```

### 🔐 权限问题解决方案
- 自动检测权限问题
- 提供修复建议和命令
- 支持 `newgrp docker` 和重新登录
- 完整的权限验证流程

---

## 版本 1.0.0 (初始版本)
- 基础 Docker 和 Docker Compose 安装功能
- 支持官方仓库和一键脚本安装
- 基本的用户组配置
