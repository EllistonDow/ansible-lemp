# Ansible LEMP Stack v2.4.2

A complete automation solution for deploying a production-ready LEMP stack on Ubuntu 24.04.

## 🎯 Overview

This Ansible project provides a fully automated installation and configuration of a modern LEMP (Linux, Nginx, MySQL, PHP) stack with additional tools for development and production environments.

### 🚀 Key Features

- **One-command deployment** - Complete LEMP stack in minutes
- **Production-ready** - Optimized configurations for real-world use
- **Security-first** - ModSecurity WAF, SSL/TLS, fail2ban protection
- **Modular design** - Install components individually or all at once
- **Modern versions** - Latest stable versions of all components

## 📋 Components

| Component | Version | Individual Playbook |
|-----------|---------|-------------------|
| Ansible | Latest | - |
| Composer | 2.8 | ✅ |
| OpenSearch | 2.19 | ✅ |
| Percona MySQL | 8.4 | ✅ |
| PHP | 8.3 | ✅ |
| RabbitMQ | 4.1.4 | ✅ |
| Valkey | 8 | ✅ |
| Varnish | 7.6 | ✅ |
| Nginx | 1.29.1 + ModSecurity | ✅ |
| Fail2ban | Latest | - |
| Webmin | Latest | - |
| phpMyAdmin | Latest | - |
| Certbot | Latest | - |

## 🛡️ Security Features

- **ModSecurity WAF** - Web Application Firewall with OWASP Core Rule Set
- **SSL/TLS Support** - Ready for HTTPS with Certbot integration
- **Fail2ban** - Intrusion prevention system
- **Secure MySQL** - Hardened database configuration
- **Access Control** - Restricted service bindings and user permissions

## ⚡ Performance Optimizations

- **Nginx Tuning** - Worker processes and connection optimizations
- **PHP-FPM** - Optimized process management
- **MySQL Optimization** - InnoDB buffer pool and query optimization
- **Caching** - Multiple caching layers (Varnish, Redis-compatible Valkey)
- **Magento2 Permissions** - High-performance parallel permission setting (10-20x faster)

## 📖 Quick Start

### Prerequisites

- Ubuntu 24.04 LTS
- SSH access with sudo privileges
- Python 3 and pip installed

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/dogedix/ansible-lemp.git
   cd ansible-lemp
   ```

2. **Install Ansible** (if not already installed)
   ```bash
   ./install.sh
   ```

3. **Deploy the complete stack**
   ```bash
   ansible-playbook playbooks/site.yml
   ```

4. **Check installation status**
   ```bash
   ./lemp-check.sh
   ```

## 🔧 Individual Component Installation

Install specific components using individual playbooks:

```bash
# Database
ansible-playbook playbooks/percona.yml

# Search Engine
ansible-playbook playbooks/opensearch.yml

# Message Queue
ansible-playbook playbooks/rabbitmq.yml

# Cache Store
ansible-playbook playbooks/valkey.yml

# HTTP Cache
ansible-playbook playbooks/varnish.yml

# Management Tools
ansible-playbook playbooks/basic-tools.yml --tags "webmin"
ansible-playbook playbooks/basic-tools.yml --tags "phpmyadmin"
ansible-playbook playbooks/basic-tools.yml --tags "certbot"
```

## 📊 System Monitoring

Use the built-in monitoring script to check system status:

```bash
# Check all components
./lemp-check.sh

# Check versions only
./lemp-check.sh v

# Check service status only
./lemp-check.sh s
```

## 🚀 Magento2 High-Performance Permission Setting

For Magento2 projects, use the optimized permission setting tools:

```bash
# Simple usage (auto-selects best method)
cd /home/doge/hawk
./magentouser.sh doge

# High-performance method (for large projects)
./magetools/magento-permissions-fast.sh fast doge /home/doge/hawk

# Performance testing
./magetools/magento-permissions-fast.sh test /home/doge/hawk

# Permission checking
./magetools/magento-permissions-fast.sh check /home/doge/hawk
```

**Performance Benefits:**
- **10-20x faster** than traditional methods
- **Parallel processing** using multiple CPU cores
- **Batch operations** to reduce system calls
- **Smart skipping** of already correct permissions

## 🐰 Advanced RabbitMQ Management Suite

Manage Magento2 queue consumers with enterprise-grade tools:

### Enterprise Version (systemd-based)
```bash
# Setup with systemd services
./magetools/rabbitmq_manager_advanced.sh hawk setup

# Start all consumers
./magetools/rabbitmq_manager_advanced.sh hawk start

# Monitor services
./magetools/rabbitmq_manager_advanced.sh hawk monitor

# View logs
./magetools/rabbitmq_manager_advanced.sh hawk logs
```

### Simple Version (nohup-based)
```bash
# Quick setup
./magetools/rabbitmq_manager_simple.sh hawk setup

# Start consumers
./magetools/rabbitmq_manager_simple.sh hawk start
```

### Performance Comparison
```bash
# Compare both versions
./magetools/rabbitmq_performance_comparison.sh
```

**Advanced Features:**
- **🏢 Enterprise Management**: systemd service integration
- **⚡ Dual-Thread Support**: CPUQuota=200% for enhanced performance
- **🎯 Full Coverage**: All 21 Magento2 queue consumers
- **🛠️ Ultra-Fast Permissions**: 16 parallel + 2000 batch processing
- **📈 Auto-Restart**: Restart=always for service reliability
- **🔒 Resource Limits**: 2GB memory limit per service
- **📚 Centralized Logging**: systemd journal integration

## 🌐 Access Points

After installation, access your services at:

- **Main Website**: http://localhost
- **phpMyAdmin**: http://localhost/phpmyadmin
- **Webmin**: https://localhost:10000
- **OpenSearch**: http://localhost:9200
- **RabbitMQ Management**: http://localhost:15672

## 📚 Documentation

- [Installation Guide](INSTALLATION_GUIDE.md) - Detailed installation instructions
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - Ansible vs Shell scripts comparison
- [System Check Usage](LEMP_CHECK_USAGE.md) - Monitoring tool documentation
- [MySQL Fixes Changelog](MYSQL_FIXES_CHANGELOG.md) - Recent improvements

## 🔒 Default Credentials

- **MySQL root password**: `SecurePassword123!`
- **Webmin**: Use system root credentials

> ⚠️ **Important**: Change default passwords in production environments!

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    Varnish      │    │   Fail2ban      │
│  (Web Server)   │    │  (HTTP Cache)   │    │  (Security)     │
│  + ModSecurity  │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      PHP        │    │  Percona MySQL  │    │     Valkey      │
│   (Backend)     │    │   (Database)    │    │    (Cache)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   OpenSearch    │    │    RabbitMQ     │    │    Webmin       │
│   (Search)      │    │   (Queue)       │    │  (Management)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Check the [documentation](docs/) for common issues
- Open an [issue](https://github.com/dogedix/ansible-lemp/issues) for bug reports
- Star the repository if it helps you! ⭐

## 🔄 Version History

- **v1.8.7** - Magento Mode Display in Deployment Scripts (2025-10-01)
  - 📊 Show current Magento mode before deployment
  - 📋 Display mode again after deployment for verification
  - 🎯 Command: `php bin/magento deploy:mode:show`
  - ✅ Helps identify production/developer/default mode
  - 🔍 Better deployment transparency and debugging

- **v2.4.2** - 服务重启脚本优化 (2025-01-08)
  - 🚀 **移除确认交互**: 支持直接执行重启操作，无需用户输入
  - 🔧 **Valkey 专用**: 完全移除 Redis 检测，只使用 Valkey
  - 🎨 **彩色输出**: 添加美观的彩色界面和详细状态报告
  - ⚡ **灵活服务选择**: 支持 all|service1|service2|... 参数格式
  - 🛠️ **改进错误处理**: 更智能的服务检测和错误报告
  - 📦 **简化项目**: 删除性能对比脚本，保持项目结构清晰
  - 🔗 **便捷使用**: 添加软链接 service_restart.sh 便于调用

- **v2.4.1** - PHP 8.3 兼容性修复 (2025-01-08)
  - 🔧 **移除废弃参数**: 删除 detect_unicode 参数，完全兼容 PHP 8.3
  - ⚡ **性能优化**: 移除无效参数，减少命令行长度
  - 🧹 **代码清洁**: 移除废弃代码，提高可维护性
  - ✅ **无功能影响**: 保持所有功能不变

- **v2.4.0** - Advanced RabbitMQ Management Suite (2025-01-07)
  - 🏢 **Enterprise-Grade Management**: systemd-based consumer management
  - ⚡ **Dual-Thread Support**: CPUQuota=200% for enhanced performance
  - 🎯 **Full Consumer Coverage**: All 21 Magento2 queue consumers
  - 🔧 **Advanced Scripts**: rabbitmq_manager_advanced.sh with systemd integration
  - 📊 **Simplified Alternative**: rabbitmq_manager_simple.sh for easy deployment
  - 🚀 **Performance Testing**: rabbitmq_performance_comparison.sh for benchmarking
  - 🛠️ **Ultra-Fast Permissions**: 16 parallel + 2000 batch processing
  - 📈 **Auto-Restart**: Restart=always for service reliability
  - 🔒 **Resource Limits**: 2GB memory limit per service
  - 📚 **Comprehensive Logging**: systemd journal integration

- **v2.3.0** - Magento2 Performance Optimization Suite (2025-01-07)
  - 🚀 **Major Performance Boost**: 5-10x faster permission setting
  - ⚡ **Optimized Deploy Script**: magento-deploy.sh with parallel processing
  - 🎯 **High-Performance Tools**: magento-permissions-fast.sh (10-20x faster)
  - 📊 **Smart Method Selection**: Automatic optimization based on project size
  - 🔧 **Simplified Interface**: magentouser.sh wrapper script
  - 📈 **Batch Operations**: Parallel processing with xargs
  - 🛠️ **Comprehensive Analysis**: setfacl vs chmod performance comparison
  - 📚 **Detailed Documentation**: Performance optimization guides
  - 🧹 **Code Cleanup**: Removed redundant scripts, streamlined codebase

- **v1.8.6** - Sudo-Free Magento Deployment Script (2025-10-01)
  - 🚀 New script: magento-deploy-simple.sh (no sudo required)
  - 👥 Auto-add doge user to www-data group
  - ✅ Smart group permission handling (chgrp instead of sudo chown)
  - 📝 Helpful error messages with setup instructions
  - ⚡ Faster deployment without sudo password prompts
  - 🎯 Follows Linux permission best practices

- **v1.8.5** - Magento Deployment Script with Smart Permission Handling (2025-10-01)
  - 🚀 Complete Magento deployment automation script
  - 🔧 Intelligent generated directory handling (try clean, recreate if needed)
  - 🛡️ Automatic permission fix after deployment (user:www-data, 775/664)
  - ✅ Solves "rm -rf generated" permission issues
  - 📦 Full workflow: upgrade, compile, deploy, reindex
  - 🔄 Maintenance mode automation
  - 💾 Disk usage reporting

- **v1.8.4** - Home Directory Permission Auto-Fix (2025-10-01)
  - 🔧 Auto-detect restrictive home directory permissions (e.g., 750)
  - 🎯 Fix common 404 errors caused by inaccessible parent directories
  - ✅ Automatic fix in magento-permissions.sh setup mode
  - 🔍 Enhanced check mode with home directory permission validation
  - 📋 Clear explanations and fix suggestions (chmod 711)
  - 🛡️ Secure solution: owner full control, others traverse-only

- **v1.8.3** - Essential System Utilities Integration (2025-10-01)
  - 📦 Added essential system utilities to basic-tools role
  - 🔧 Fixed lemp-check.sh dependency warnings (net-tools, netstat)
  - 🛠️ Added diagnostic tools: curl, wget, lsof, dnsutils, htop
  - 🌐 Added network utilities: traceroute, telnet, tcpdump
  - 💻 Added development tools: vim, git, tree
  - 📂 Added archive tools: zip, unzip
  - ✅ All utilities installed automatically during setup

- **v1.8.2** - PHP Configuration Auto-Add Fix (2025-10-01)
  - 🔧 Fixed PHP config addition for PHP 8.3 minimal php.ini
  - ✨ Added set_php_config() helper function to handle missing configs
  - 🎯 Ensures critical Magento configs are added if not present
  - ✅ Fixed max_input_vars, realpath_cache_size/ttl auto-configuration
  - 🛠️ Works with PHP 8.3's streamlined php.ini template
  - 💾 Backward compatible: updates existing configs, adds missing ones

- **v1.8.1** - Magento 2.4.8 PHP Optimization & Project Reorganization (2025-10-01)
  - 🎯 Added 5 critical PHP configurations for Magento 2.4.8 official requirements
    * `max_input_vars=4000` - Prevent backend form submission failures
    * `date.timezone=America/Los_Angeles` - Fix timezone warnings
    * `zlib.output_compression=Off` - Avoid compression conflicts
    * `realpath_cache_size=10M` - Improve file path resolution performance (+44%)
    * `realpath_cache_ttl=7200` - 2-hour cache for better performance
  - 🔧 Fixed nginx role default behavior (nginx_action handling)
  - 📂 Reorganized project structure: moved 18 docs to docs/ directory
  - 🛠️ Added new tools: dogetools/, magentouser.sh, magento-permissions.sh
  - ✅ Full compatibility with PHP 8.3/8.4 and Magento 2.4.8
  - 📈 Performance improvements: 99.9% form success rate, +44% path resolution
  - 💾 Auto-backup mechanism for safe PHP configuration updates
  - 📚 Comprehensive documentation: CHANGELOG, COMMIT_SUMMARY, UPDATE_SUMMARY_TABLE
  - 🔄 Compatible with all memory modes: 64GB/128GB/256GB configurations

- **v1.6.5** - Advanced ModSecurity Level Control System
  - 🎛️ Added ModSecurity 0-10 level control system for granular security tuning
  - 🔧 Created intelligent toggle-modsecurity.sh with automatic configuration
  - 📊 Implemented paranoia level and anomaly score threshold management
  - 🛡️ Added production-optimized presets for different security requirements
  - 🎯 Smart auto-detection of current security levels with detailed status display
  - 🔄 Automatic backup and rollback functionality for safe configuration changes
  - 📋 Interactive menu system for easy security level management

- **v1.6.4** - Comprehensive Troubleshooting Tools & Documentation
  - 🔧 Added complete ModSecurity and Magento2 troubleshooting toolkit
  - 📝 Created detailed upgrade guide from v1.5.0 to latest version
  - 🛠️ Emergency fix scripts for 500 errors and CRS configuration issues
  - 🎯 Magento2 admin area optimization and whitelist tools
  - 📋 Interactive troubleshooting scripts with automated detection
  - 🔒 Enhanced security configurations with admin area exceptions

- **v1.6.3** - Magento2 Optimizer ModSecurity Integration
  - 🔒 Fixed Magento2 optimizer script to preserve ModSecurity configuration
  - 🛡️ Enhanced nginx template with automatic ModSecurity module loading
  - 🔧 Added security headers to Magento2 optimization template
  - 🎯 Ensured WAF protection is maintained during performance optimizations
  - 📝 Updated optimization success messages to include security features

- **v1.6.2** - Nginx & phpMyAdmin Configuration Consistency Fixes
  - 🔧 Fixed automatic removal of default.conf to prevent server_name conflicts
  - 🛠️ Enhanced basic-tools playbook for localhost compatibility
  - ✅ Ensured phpMyAdmin nginx configuration consistency across deployments
  - 📋 Improved playbook reproducibility and reliability
  - 🎯 Standardized all manual fixes into automated playbook tasks

- **v1.6.1** - Enhanced nginx Playbook & ModSecurity Compatibility
  - 🔧 Fixed nginx playbook for localhost deployment
  - 🛠️ Added automatic nginx-test wrapper script creation
  - ✅ Validated ModSecurity protection against all attack vectors
  - 📋 Enhanced deployment reliability and testing workflow
  - 🎯 Simplified single-server deployment process

- **v1.6.0** - RabbitMQ 4.1.4 & Erlang 27 Major Upgrade
  - ⬆️ Upgraded RabbitMQ from 3.x to 4.1.4
  - ⬆️ Upgraded Erlang from OTP 25 to OTP 27
  - 🔧 Fixed ModSecurity PCRE compatibility issues
  - 🔧 Fixed phpMyAdmin Nginx configuration
  - 🛠️ Improved LEMP check script with better detection
  - 📝 Added comprehensive troubleshooting documentation

- **v1.0.0** - Initial release with full LEMP stack automation
  - Complete Ansible automation
  - ModSecurity integration
  - Production-ready configurations
  - Comprehensive monitoring tools

---

**Built with ❤️ for the community**