# Nginx 1.29.1 + SSL + ModSecurity Playbook 完整指南

## 📋 概述

这个playbook提供了一个完整的Nginx 1.29.1安装方案，包含：
- ✅ **完整SSL/TLS支持** (OpenSSL 3.0.13)
- ✅ **ModSecurity 3.0 WAF防护**  
- ✅ **PCRE兼容性解决方案**
- ✅ **HTTP/2 支持**
- ✅ **Certbot SSL证书自动配置**
- ✅ **Magento2 优化配置**

## 🚀 安装命令

### 基础安装 (仅Nginx + SSL)
```bash
ansible-playbook playbooks/nginx.yml
```

### 完整安装 (Nginx + SSL + ModSecurity)
```bash
ansible-playbook playbooks/nginx.yml -e "modsecurity_enabled=true"
```

### 卸载
```bash
ansible-playbook playbooks/nginx.yml -e "nginx_action=uninstall"
```

## 🔧 安装后配置

### 1. SSL证书配置
```bash
# 为单个域名配置SSL
sudo certbot --nginx -d example.com

# 为多个域名配置SSL  
sudo certbot --nginx -d example.com -d www.example.com

# 测试证书续期
sudo certbot renew --dry-run
```

### 2. ModSecurity 安全级别调整
```bash
# 查看当前级别
./scripts/toggle-modsecurity.sh

# 设置为级别1 (推荐用于Magento2)
./scripts/toggle-modsecurity.sh 1

# 设置为级别2 (平衡安全性和兼容性)
./scripts/toggle-modsecurity.sh 2

# 设置为级别10 (最高安全性)
./scripts/toggle-modsecurity.sh 10
```

### 3. 网站配置
```bash
# 编辑网站配置
sudo nano /etc/nginx/sites-available/your-site.conf

# 启用网站
sudo ln -s /etc/nginx/sites-available/your-site.conf /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重新加载
sudo systemctl reload nginx
```

## 🛠️ 管理命令

### Nginx 基础操作
```bash
# 测试配置
sudo nginx -t

# 重新加载配置
sudo systemctl reload nginx

# 重启服务
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx

# 查看版本和编译选项
nginx -V
```

### 日志查看
```bash
# nginx错误日志
sudo tail -f /var/log/nginx/error.log

# nginx访问日志  
sudo tail -f /var/log/nginx/access.log

# ModSecurity审计日志
sudo tail -f /var/log/nginx/modsec_audit.log
```

### SSL证书管理
```bash
# 列出所有证书
sudo certbot certificates

# 续期所有证书
sudo certbot renew

# 删除证书
sudo certbot delete --cert-name example.com
```

## 📁 重要目录结构

```
/etc/nginx/
├── nginx.conf              # 主配置文件
├── sites-available/         # 可用网站配置
├── sites-enabled/          # 启用网站配置  
├── modules/                # Nginx模块
│   └── ngx_http_modsecurity_module.so
├── modsec/                 # ModSecurity配置
│   └── main.conf
├── fastcgi_params          # FastCGI参数
├── mime.types              # MIME类型
└── ...

/var/log/nginx/
├── error.log               # 错误日志
├── access.log              # 访问日志
└── modsec_audit.log        # ModSecurity审计日志

/var/cache/nginx/           # nginx缓存目录
/etc/letsencrypt/           # SSL证书目录
```

## 🔧 自定义配置

### playbook变量
```yaml
# 在 playbooks/nginx.yml 中可以修改的变量:
vars:
  nginx_user: "www-data"
  nginx_worker_processes: "auto" 
  nginx_worker_connections: "1024"
  nginx_keepalive_timeout: "30"
  nginx_client_max_body_size: "64M"
  nginx_server_tokens: "off"
  modsecurity_enabled: true  # 启用ModSecurity
```

### 编译选项
如果需要修改编译选项，编辑 `roles/nginx/tasks/install.yml` 中的 `Configure nginx 1.29.1` 任务。

## 🔒 安全配置

### ModSecurity 推荐设置
- **开发环境**: Level 0-1
- **测试环境**: Level 1-2  
- **生产环境 (Magento2)**: Level 1-2
- **高安全生产环境**: Level 3-5
- **最高安全环境**: Level 8-10

### SSL 安全配置
playbook自动配置了现代SSL安全设置：
- TLS 1.2, 1.3 支持
- 安全密码套件
- HSTS headers
- 安全的SSL参数

## ⚡ 性能优化

### FastCGI 缓存
playbook自动配置FastCGI缓存，适合PHP应用：
```nginx
# 已自动配置在 nginx.conf
fastcgi_cache_path /var/cache/nginx/fastcgi levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";
```

### Gzip 压缩
自动启用Gzip压缩，优化传输速度：
```nginx
# 已自动配置
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain application/javascript text/css application/json;
```

## 🐛 故障排除

### 常见问题

1. **SSL配置错误**
   ```bash
   sudo nginx -t
   # 检查错误信息，通常是证书路径问题
   ```

2. **ModSecurity阻止正常请求**
   ```bash
   # 降低安全级别
   ./scripts/toggle-modsecurity.sh 1
   # 或查看审计日志
   sudo tail -f /var/log/nginx/modsec_audit.log
   ```

3. **端口冲突**
   ```bash
   sudo ss -tlnp | grep :80
   sudo ss -tlnp | grep :443
   ```

4. **权限问题**
   ```bash
   sudo chown -R www-data:www-data /var/cache/nginx/
   sudo chown -R www-data:www-data /var/log/nginx/
   ```

### 配置验证清单
- [ ] `sudo nginx -t` 测试通过
- [ ] `systemctl status nginx` 显示 active (running)
- [ ] `curl -I http://localhost` 返回200响应
- [ ] `curl -I https://your-domain.com` SSL正常工作
- [ ] ModSecurity日志正常记录 (如启用)

## 📚 参考资源

- [Nginx 官方文档](https://nginx.org/en/docs/)
- [ModSecurity 3.0 文档](https://github.com/SpiderLabs/ModSecurity/wiki)
- [Let's Encrypt Certbot](https://certbot.eff.org/)
- [OWASP ModSecurity CRS](https://owasp.org/www-project-modsecurity-core-rule-set/)

## 🎯 版本兼容性

| 组件 | 版本 | 状态 |
|------|------|------|
| Nginx | 1.29.1 | ✅ 测试通过 |
| OpenSSL | 3.0.13 | ✅ 完全支持 |
| ModSecurity | 3.0.x | ✅ 完全兼容 |
| PCRE | 1.x | ✅ 兼容性解决 |
| Ubuntu | 22.04+ | ✅ 推荐 |
| Debian | 11+ | ✅ 支持 |

---

**🎉 享受您的高性能、安全的Nginx 1.29.1环境！**
