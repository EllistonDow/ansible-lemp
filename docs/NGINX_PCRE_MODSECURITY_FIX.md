# Nginx ModSecurity PCRE兼容性修复

## 问题描述

在某些系统中，ModSecurity模块可能会遇到PCRE库兼容性问题，导致以下错误：

```
nginx: [emerg] dlopen() "/etc/nginx/modules/ngx_http_modsecurity_module.so" failed 
(/etc/nginx/modules/ngx_http_modsecurity_module.so: undefined symbol: pcre_malloc) 
in /etc/nginx/nginx.conf:2
```

## 解决方案

### 1. Playbook自动修复

现在nginx安装playbook已经集成了PCRE兼容性检查和自动修复功能：

- **安装额外的PCRE包**: 确保所有必要的PCRE库都已安装
- **自动检测问题**: 在nginx启动前检测PCRE兼容性问题
- **智能修复**: 尝试重新编译ModSecurity模块，如果失败则临时禁用
- **日志记录**: 所有操作都记录在 `/var/log/nginx-pcre-fix.log`

### 2. 修复脚本

#### 快速修复脚本
```bash
/usr/local/bin/nginx-pcre-fix
```

#### 完整修复脚本
```bash
/home/doge/ansible-lemp/scripts/fix-modsecurity-pcre.sh
```

### 3. Magento2优化器集成

`magento2-optimizer.sh` 脚本现在在优化nginx后会自动检查PCRE兼容性：

```bash
./scripts/magento2-optimizer.sh optimize nginx
```

## 修复策略

### 第一步：重新编译
- 尝试使用正确的PCRE标志重新编译ModSecurity模块
- 使用 `--without-pcre2 --with-pcre --with-pcre-jit`

### 第二步：临时禁用
如果重新编译失败，脚本会：
- 注释掉 `load_module modules/ngx_http_modsecurity_module.so;`
- 注释掉所有 `modsecurity` 相关指令
- 确保nginx能够正常启动

### 第三步：日志记录
所有操作都会记录在日志文件中，方便后续排查。

## 使用方法

### 新安装时
```bash
ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=true"
```

### 已有系统修复
```bash
# 快速检查和修复
/usr/local/bin/nginx-pcre-fix

# 或完整修复
/home/doge/ansible-lemp/scripts/fix-modsecurity-pcre.sh
```

### 在Magento2优化时
```bash
cd /home/doge/ansible-lemp
./scripts/magento2-optimizer.sh optimize nginx
```

## 检查修复结果

### 查看nginx配置测试
```bash
sudo nginx -t
```

### 查看ModSecurity状态
```bash
nginx -V 2>&1 | grep -o with-http_modsecurity_module
```

### 查看修复日志
```bash
tail -f /var/log/nginx-pcre-fix.log
```

## 恢复ModSecurity

如果PCRE问题已解决，可以重新启用ModSecurity：

```bash
# 取消注释ModSecurity指令
sudo sed -i 's/^#load_module modules\/ngx_http_modsecurity_module.so; # .*/load_module modules\/ngx_http_modsecurity_module.so;/' /etc/nginx/nginx.conf
sudo sed -i 's/^#    modsecurity on; # .*/    modsecurity on;/' /etc/nginx/nginx.conf
sudo sed -i 's/^#    modsecurity_rules_file # .*/    modsecurity_rules_file \/etc\/nginx\/modsec\/main.conf;/' /etc/nginx/nginx.conf

# 测试配置
sudo nginx -t

# 重新加载nginx
sudo systemctl reload nginx
```

## 注意事项

1. **备份**: 修复过程会自动创建配置文件备份
2. **日志**: 检查 `/var/log/nginx-pcre-fix.log` 了解详细过程
3. **兼容性**: 某些系统可能需要手动安装特定版本的PCRE库
4. **性能**: 禁用ModSecurity会影响安全防护，应尽快修复并重新启用

## 故障排除

### 如果修复脚本失败
1. 检查nginx和ModSecurity源代码是否完整
2. 确认build-essential等编译工具已安装
3. 手动下载匹配的nginx源代码版本
4. 考虑从源代码重新安装nginx和ModSecurity

### 如果nginx仍然无法启动
1. 检查 `/var/log/nginx/error.log`
2. 确认所有nginx模块路径正确
3. 验证nginx配置文件语法
4. 临时移除所有自定义模块进行测试
