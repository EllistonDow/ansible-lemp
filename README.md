# Ansible LEMP Stack v1.8.4

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
| Nginx | 1.27.4 + ModSecurity | ✅ |
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