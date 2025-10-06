# 🎨 Magento维护页面管理系统

## 📋 概述

这是一个统一的Magento维护页面管理系统，提供现代化的暗黑模式维护页面，支持动画效果、移动端适配和统一管理。

## 📁 项目结构

```
ansible-lemp/
├── magetools/
│   └── maintenance-page-design/
│       └── 2025/
│           └── 503.phtml          # 维护页面模板
└── scripts/
    └── maintenance_page_manager.sh # 管理脚本
```

## 🚀 快速开始

### 1. 更新模板（首次使用）

```bash
cd /home/doge/ansible-lemp
./scripts/maintenance_page_manager.sh update-template
```

### 2. 安装维护页面

```bash
# 安装到单个网站
./scripts/maintenance_page_manager.sh install ipwa

# 安装到所有网站
./scripts/maintenance_page_manager.sh install-all
```

### 3. 管理维护模式

```bash
# 启用维护模式
./scripts/maintenance_page_manager.sh enable ipwa

# 禁用维护模式
./scripts/maintenance_page_manager.sh disable ipwa

# 查看状态
./scripts/maintenance_page_manager.sh status ipwa
```

## 🛠️ 命令参考

### 安装命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `install [网站名]` | 安装维护页面到指定网站 | `install ipwa` |
| `install-all` | 安装到所有Magento网站 | `install-all` |

### 维护模式命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `enable [网站名]` | 启用维护模式 | `enable ipwa` |
| `disable [网站名]` | 禁用维护模式 | `disable ipwa` |
| `status [网站名]` | 查看维护模式状态 | `status ipwa` |

### 管理命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `list` | 列出所有网站 | `list` |
| `template-info` | 显示模板信息 | `template-info` |
| `update-template` | 从hawk更新模板 | `update-template` |

## 🎨 维护页面特性

### 🌙 设计特色
- **暗黑模式**: 现代化的深色主题
- **透明玻璃**: 毛玻璃效果和半透明背景
- **渐变背景**: 动态渐变色彩
- **粒子动画**: 浮动粒子背景效果

### ✨ 动画效果
- **旋转齿轮**: 持续旋转的维护图标
- **脉冲动画**: 图标的呼吸效果
- **渐变文字**: 标题的彩虹渐变动画
- **页面进入**: 滑入和缩放动画
- **按钮悬停**: 光泽扫过效果

### 📱 移动端适配
- **响应式设计**: 自动适配各种屏幕尺寸
- **触摸优化**: 触摸友好的按钮和交互
- **视口配置**: 优化的移动端视口设置
- **性能优化**: 硬件加速和流畅动画

### ⏰ 功能特性
- **倒计时器**: 5分钟倒计时显示
- **联系功能**: 邮件联系链接
- **状态显示**: 维护状态提示
- **加载动画**: 动态省略号效果

## 📧 配置信息

- **联系邮箱**: `magento@tschenfeng.com`
- **倒计时**: 5分钟
- **主题**: 2025
- **兼容性**: HTML5 + CSS3

## 🔧 自定义修改

### 修改联系邮箱

编辑模板文件：
```bash
nano /home/doge/ansible-lemp/magetools/maintenance-page-design/2025/503.phtml
```

搜索并修改：
```html
<a href="mailto:magento@tschenfeng.com" class="contact-link">
```

### 修改倒计时时间

在模板文件中找到：
```javascript
let timeLeft = 5 * 60; // 5分钟
```

修改为您需要的时间（分钟）。

### 修改页面内容

编辑模板文件中的HTML内容部分。

## 📊 使用示例

### 批量管理所有网站

```bash
# 1. 更新模板
./scripts/maintenance_page_manager.sh update-template

# 2. 安装到所有网站
./scripts/maintenance_page_manager.sh install-all

# 3. 查看网站列表
./scripts/maintenance_page_manager.sh list

# 4. 启用维护模式（示例）
./scripts/maintenance_page_manager.sh enable ipwa
./scripts/maintenance_page_manager.sh enable sava

# 5. 查看状态
./scripts/maintenance_page_manager.sh status ipwa

# 6. 禁用维护模式
./scripts/maintenance_page_manager.sh disable ipwa
```

### 单个网站管理

```bash
# 安装维护页面
./scripts/maintenance_page_manager.sh install hawk

# 启用维护模式
./scripts/maintenance_page_manager.sh enable hawk

# 查看状态
./scripts/maintenance_page_manager.sh status hawk

# 禁用维护模式
./scripts/maintenance_page_manager.sh disable hawk
```

## 🔍 故障排除

### 模板文件不存在

```bash
# 更新模板
./scripts/maintenance_page_manager.sh update-template
```

### 网站不是Magento

确保网站目录包含 `bin/magento` 文件。

### 权限问题

脚本会自动设置正确的文件权限，如果仍有问题：

```bash
# 手动设置权限
chown -R www-data:www-data /home/doge/[网站名]/pub/errors/2025
chmod -R 755 /home/doge/[网站名]/pub/errors/2025
```

## 📈 版本历史

- **v1.0.0**: 初始版本，支持2025主题维护页面
- 暗黑模式设计
- 透明玻璃效果
- 动画效果
- 移动端适配
- 统一管理脚本

## 🤝 贡献

欢迎提交问题和改进建议！

## 📄 许可证

MIT License
