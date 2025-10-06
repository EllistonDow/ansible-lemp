# 2025维护页面复制指南

## 🚀 自动复制（推荐）

使用我们创建的脚本：

```bash
# 复制到单个网站
cd /home/doge/ansible-lemp
./scripts/copy_maintenance_page.sh ipwa

# 复制到多个网站
./scripts/copy_maintenance_page.sh ipwa sava bdgy ntca papa ambi
```

## 📋 手动复制步骤

### 步骤1: 创建目录结构

```bash
# 为每个网站创建2025错误页面目录
mkdir -p /home/doge/[网站名]/pub/errors/2025

# 例如：
mkdir -p /home/doge/ipwa/pub/errors/2025
mkdir -p /home/doge/sava/pub/errors/2025
mkdir -p /home/doge/bdgy/pub/errors/2025
```

### 步骤2: 复制维护页面文件

```bash
# 复制维护页面
cp /home/doge/hawk/pub/errors/2025/503.phtml /home/doge/[网站名]/pub/errors/2025/503.phtml

# 例如：
cp /home/doge/hawk/pub/errors/2025/503.phtml /home/doge/ipwa/pub/errors/2025/503.phtml
cp /home/doge/hawk/pub/errors/2025/503.phtml /home/doge/sava/pub/errors/2025/503.phtml
```

### 步骤3: 更新配置文件

```bash
# 复制配置文件
cp /home/doge/hawk/pub/errors/local.xml /home/doge/[网站名]/pub/errors/local.xml

# 或者手动编辑配置文件
nano /home/doge/[网站名]/pub/errors/local.xml
```

确保配置文件内容为：
```xml
<?xml version="1.0"?>
<config>
    <skin>2025</skin>
    <!-- 其他配置保持不变 -->
</config>
```

### 步骤4: 设置文件权限

```bash
# 设置正确的文件权限
chown -R www-data:www-data /home/doge/[网站名]/pub/errors/2025
chmod -R 755 /home/doge/[网站名]/pub/errors/2025
chown www-data:www-data /home/doge/[网站名]/pub/errors/local.xml
chmod 644 /home/doge/[网站名]/pub/errors/local.xml
```

## 🧪 测试维护模式

### 启用维护模式
```bash
cd /home/doge/[网站名]
php bin/magento maintenance:enable
```

### 查看维护状态
```bash
cd /home/doge/[网站名]
php bin/magento maintenance:status
```

### 禁用维护模式
```bash
cd /home/doge/[网站名]
php bin/magento maintenance:disable
```

## 📁 文件结构

复制完成后的文件结构：
```
/home/doge/[网站名]/
└── pub/errors/
    ├── 2025/
    │   └── 503.phtml          # 新的维护页面
    └── local.xml              # 配置文件（skin设置为2025）
```

## 🎨 维护页面特性

- ✅ **暗黑模式设计**
- ✅ **透明玻璃效果**
- ✅ **丰富的动画效果**
- ✅ **移动端适配**
- ✅ **5分钟倒计时**
- ✅ **联系邮箱**: magento@tschenfeng.com
- ✅ **HTML5标准**
- ✅ **响应式设计**

## 🔧 自定义修改

如果需要修改维护页面内容：

```bash
# 编辑维护页面
nano /home/doge/[网站名]/pub/errors/2025/503.phtml

# 修改联系邮箱
# 修改倒计时时间
# 修改页面内容
```

## ⚠️ 注意事项

1. **备份**: 复制前建议备份原有的维护页面
2. **权限**: 确保文件权限正确设置
3. **测试**: 复制后务必测试维护模式
4. **一致性**: 所有网站使用相同的维护页面设计
