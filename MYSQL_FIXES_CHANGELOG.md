# MySQL Configuration Fixes Changelog

## 概述
本次更新修复了Percona MySQL安装过程中的配置问题，确保与MySQL 8.0完全兼容，并消除systemd警告。

## 🔧 修复的问题

### 1. MYSQLD_OPTS systemd 警告
**问题**: 
```
mysql.service: Referenced but unset environment variable evaluates to an empty string: MYSQLD_OPTS
```

**解决方案**:
- 在 `/etc/default/mysql` 中添加 `MYSQLD_OPTS=""`
- 创建 systemd drop-in 配置 `/etc/systemd/system/mysql.service.d/override.conf`
- 显式设置环境变量 `Environment="MYSQLD_OPTS="`

### 2. MySQL 8.0 兼容性问题
**问题**: 
- `NO_AUTO_CREATE_USER` 在 MySQL 8.0 中已移除
- `query_cache` 功能在 MySQL 8.0 中已移除

**解决方案**:
- 更新 `sql_mode` 配置，移除 `NO_AUTO_CREATE_USER`
- 注释掉 `query_cache_limit` 和 `query_cache_size` 配置

## 📁 更新的文件

### `roles/percona/tasks/install.yml`
**新增任务**:
```yaml
- name: Configure MySQL environment variables (fix MYSQLD_OPTS warning)
  lineinfile:
    path: /etc/default/mysql
    line: "{{ item }}"
    create: yes
    state: present
  loop:
    - "# MySQL daemon options (prevent systemd warning)"
    - 'MYSQLD_OPTS=""'

- name: Create systemd drop-in directory for MySQL
  file:
    path: /etc/systemd/system/mysql.service.d
    state: directory
    owner: root
    group: root
    mode: '0755'

- name: Create systemd drop-in configuration to fix MYSQLD_OPTS warning
  copy:
    dest: /etc/systemd/system/mysql.service.d/override.conf
    content: |
      [Service]
      Environment="MYSQLD_OPTS="
    owner: root
    group: root
    mode: '0644'
  notify: 
    - reload systemd
    - restart mysql
```

### `roles/percona/defaults/main.yml`
**更新**:
```yaml
# 之前
mysql_sql_mode: "STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"

# 之后 (MySQL 8.0 compatible)
mysql_sql_mode: "STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
```

### `roles/percona/templates/my.cnf.j2`
**更新**:
```jinja
# 之前
# Query Cache Configuration
query_cache_limit = 1M
query_cache_size = {{ mysql_query_cache_size }}

# 之后
# Query Cache Configuration (Removed in MySQL 8.0)
# query_cache_limit = 1M
# query_cache_size = {{ mysql_query_cache_size }}
```

### `roles/percona/handlers/main.yml`
**新增**:
```yaml
- name: reload systemd
  systemd:
    daemon_reload: yes
```

## ✅ 验证结果

### 启动日志 (修复前)
```
mysql.service: Referenced but unset environment variable evaluates to an empty string: MYSQLD_OPTS
Started mysql.service - Percona Server.
```

### 启动日志 (修复后)
```
Started mysql.service - Percona Server.
```

## 🎯 影响

### ✅ 正面影响
- 消除了systemd警告信息
- 提高了MySQL配置的专业性
- 确保了MySQL 8.0完全兼容
- 避免了配置错误导致的启动失败

### ❌ 无负面影响
- 不影响MySQL功能
- 不影响性能
- 向后兼容
- 配置更清爽

## 🚀 使用方法

### 全新安装
```bash
ansible-playbook playbooks/site.yml
```

### 仅更新MySQL配置
```bash
ansible-playbook test-percona.yml
```

## 📝 测试

已通过以下测试验证:
- [x] MySQL服务正常启动
- [x] 无systemd警告
- [x] 配置文件语法正确
- [x] MySQL 8.0兼容性
- [x] Ansible playbook执行成功

## 🏷️ 版本信息

- **MySQL版本**: Percona Server 8.4.6-6
- **操作系统**: Ubuntu 24.04
- **Ansible版本**: 2.16.3
- **修复日期**: 2025-09-26

---

*这些修复确保了LEMP stack在生产环境中的稳定性和专业性。*
