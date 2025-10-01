#!/bin/bash

# SSH端口修改脚本 - Ubuntu 24.04 (增强版 - 支持特权端口)
# 使用方法: sudo ./change_ssh_port.sh [新端口号]

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误：此脚本需要root权限运行${NC}"
   echo "请使用: sudo $0 [端口号]"
   exit 1
fi

# 获取新端口号
NEW_PORT=${1:-18712}

# 验证端口号 (允许22端口和1024-65535范围)
if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || ([ "$NEW_PORT" -lt 1024 ] && [ "$NEW_PORT" -ne 22 ]) || [ "$NEW_PORT" -gt 65535 ]; then
    echo -e "${RED}错误：端口号必须是22或1024-65535之间的数字${NC}"
    exit 1
fi

# 特权端口警告
if [ "$NEW_PORT" -lt 1024 ] && [ "$NEW_PORT" -ne 22 ]; then
    echo -e "${YELLOW}警告：端口 $NEW_PORT 是特权端口，可能需要特殊权限${NC}"
    read -p "确认继续？(y/N): " confirm
    if [[ ! $confirm =~ ^[yY]$ ]]; then
        exit 1
    fi
fi

echo -e "${YELLOW}开始修改SSH端口为: $NEW_PORT${NC}"

# 检查UFW状态
echo -e "${BLUE}正在检查UFW防火墙状态...${NC}"
UFW_STATUS=$(ufw status | head -1 | awk '{print $2}')
echo "UFW状态: $UFW_STATUS"

# 备份原始配置
echo "正在备份原始配置..."
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP_FILE"

# 1. 创建SSH socket覆盖配置目录
echo "正在配置SSH socket..."
mkdir -p /etc/systemd/system/ssh.socket.d

# 创建socket覆盖配置文件 (支持IPv4和IPv6)
cat > /etc/systemd/system/ssh.socket.d/override.conf << EOF
[Socket]
ListenStream=
ListenStream=0.0.0.0:$NEW_PORT
ListenStream=[::]:$NEW_PORT
EOF

# 2. 创建SSH service覆盖配置目录
echo "正在配置SSH service..."
mkdir -p /etc/systemd/system/ssh.service.d

# 创建service覆盖配置文件
cat > /etc/systemd/system/ssh.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sshd_config -p $NEW_PORT
EOF

# 3. 修改sshd_config文件
echo "正在修改sshd_config..."
# 注释掉所有现有的Port行
sed -i 's/^Port /#Port /' /etc/ssh/sshd_config
sed -i 's/^#Port /#Port /' /etc/ssh/sshd_config

# 添加新的Port配置
if grep -q "^#Port " /etc/ssh/sshd_config; then
    sed -i "0,/^#Port .*/s//Port $NEW_PORT/" /etc/ssh/sshd_config
else
    echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
fi

# 4. 自动配置UFW防火墙
echo -e "${BLUE}正在配置UFW防火墙...${NC}"

# 添加新端口规则
echo "添加SSH端口 $NEW_PORT 到UFW规则..."
ufw allow $NEW_PORT/tcp

# 如果新端口不是22，检查是否需要处理其他SSH端口规则
if [ "$NEW_PORT" -ne 22 ]; then
    # 检查是否有22端口规则
    if ufw status | grep -q "22/tcp"; then
        echo -e "${YELLOW}检测到UFW中存在22端口规则${NC}"
        read -p "是否删除22端口规则？(y/N): " remove_22
        if [[ $remove_22 == [yY] || $remove_22 == [yY][eE][sS] ]]; then
            echo "删除22端口规则..."
            ufw delete allow 22/tcp 2>/dev/null || echo "22端口规则删除失败或不存在"
        fi
    fi
    
    # 检查是否有其他SSH端口规则需要清理
    OTHER_SSH_PORTS=$(ufw status | grep -E "(18712|2222|2022)" | grep -v "$NEW_PORT" || true)
    if [ ! -z "$OTHER_SSH_PORTS" ]; then
        echo -e "${YELLOW}检测到其他SSH端口规则：${NC}"
        echo "$OTHER_SSH_PORTS"
        read -p "是否删除这些规则？(y/N): " remove_others
        if [[ $remove_others == [yY] || $remove_others == [yY][eE][sS] ]]; then
            echo "$OTHER_SSH_PORTS" | while read line; do
                port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
                if [ ! -z "$port" ] && [ "$port" != "$NEW_PORT" ]; then
                    echo "删除端口 $port 规则..."
                    ufw delete allow $port/tcp 2>/dev/null || true
                fi
            done
        fi
    fi
else
    echo -e "${GREEN}设置为默认SSH端口22${NC}"
fi

# 如果UFW是inactive状态，询问是否启用
if [[ "$UFW_STATUS" == "inactive" ]]; then
    echo -e "${YELLOW}UFW当前处于关闭状态${NC}"
    read -p "是否启用UFW防火墙？(y/N): " enable_ufw
    if [[ $enable_ufw == [yY] || $enable_ufw == [yY][eE][sS] ]]; then
        echo "启用UFW防火墙..."
        ufw --force enable
        echo -e "${GREEN}✓ UFW已启用${NC}"
    else
        echo -e "${YELLOW}⚠ UFW保持关闭状态，规则已添加但未生效${NC}"
    fi
fi

# 显示当前UFW状态
echo "当前UFW规则："
ufw status | grep -E "(Status|$NEW_PORT)" || echo "未找到相关规则"

# 5. 测试配置文件语法
echo "正在测试SSH配置..."
if ! sshd -t; then
    echo -e "${RED}错误：SSH配置文件语法错误${NC}"
    echo "正在恢复备份..."
    cp "$BACKUP_FILE" /etc/ssh/sshd_config
    # 删除覆盖配置文件
    rm -f /etc/systemd/system/ssh.socket.d/override.conf
    rm -f /etc/systemd/system/ssh.service.d/override.conf
    exit 1
fi

# 6. 重新加载systemd配置并重启服务
echo "正在重新加载systemd配置..."
systemctl daemon-reload

echo "正在重启SSH socket..."
systemctl restart ssh.socket

# 7. 等待服务启动
echo "等待服务启动..."
sleep 3

# 8. 检查服务状态
echo "正在检查服务状态..."
if systemctl is-active --quiet ssh.socket; then
    echo -e "${GREEN}✓ SSH socket 服务运行正常${NC}"
else
    echo -e "${RED}✗ SSH socket 服务启动失败${NC}"
    systemctl status ssh.socket
    exit 1
fi

# 9. 检查端口监听 (IPv4和IPv6)
echo "正在检查端口监听..."
LISTEN_COUNT=$(ss -tulpn | grep -c ":$NEW_PORT ")
if [ "$LISTEN_COUNT" -ge 1 ]; then
    echo -e "${GREEN}✓ SSH 正在监听端口 $NEW_PORT${NC}"
    echo "监听详情："
    ss -tulpn | grep ":$NEW_PORT "
    
    # 检查是否同时监听IPv4和IPv6
    if ss -tulpn | grep -q "0.0.0.0:$NEW_PORT" && ss -tulpn | grep -q "\[::\]:$NEW_PORT"; then
        echo -e "${GREEN}✓ 同时监听IPv4和IPv6${NC}"
    elif ss -tulpn | grep -q "0.0.0.0:$NEW_PORT"; then
        echo -e "${YELLOW}⚠ 仅监听IPv4${NC}"
    elif ss -tulpn | grep -q "\[::\]:$NEW_PORT"; then
        echo -e "${YELLOW}⚠ 仅监听IPv6${NC}"
    fi
else
    echo -e "${RED}✗ 端口 $NEW_PORT 未在监听${NC}"
    echo "请检查配置或查看日志："
    echo "sudo journalctl -u ssh.socket -f"
    exit 1
fi

# 10. 本地连接测试
echo "正在进行本地连接测试..."
if timeout 3 bash -c "</dev/tcp/localhost/$NEW_PORT" 2>/dev/null; then
    echo -e "${GREEN}✓ 本地连接测试成功${NC}"
else
    echo -e "${YELLOW}⚠ 本地连接测试失败，但服务可能仍然正常${NC}"
fi

# 11. 显示完成信息
echo ""
echo -e "${GREEN}========== 端口修改成功！ ==========${NC}"
echo ""
echo "🔧 配置信息："
echo "   新SSH端口: $NEW_PORT"
if [ "$NEW_PORT" -eq 22 ]; then
    echo -e "${GREEN}   ✓ 已恢复为默认SSH端口${NC}"
fi
echo "   备份文件: $BACKUP_FILE"
echo ""
echo "📁 创建的配置文件："
echo "   - /etc/systemd/system/ssh.socket.d/override.conf"
echo "   - /etc/systemd/system/ssh.service.d/override.conf"
echo ""
echo "🛡️ 防火墙状态："
UFW_FINAL_STATUS=$(ufw status | head -1 | awk '{print $2}')
echo "   UFW状态: $UFW_FINAL_STATUS"
if [[ "$UFW_FINAL_STATUS" == "active" ]]; then
    echo "   端口 $NEW_PORT 已添加到UFW允许列表"
fi
echo ""
echo "🧪 测试连接："
SERVER_IP=$(hostname -I | awk '{print $1}' | tr -d ' ')
if [ "$NEW_PORT" -eq 22 ]; then
    echo "   ssh username@$SERVER_IP"
    echo "   ssh username@localhost"
else
    echo "   ssh -p $NEW_PORT username@$SERVER_IP"
    echo "   ssh -p $NEW_PORT username@localhost"
fi
echo ""
echo "📋 查看服务状态："
echo "   sudo systemctl status ssh.socket"
echo "   sudo ss -tulpn | grep $NEW_PORT"
echo "   sudo ufw status"
echo ""
echo -e "${YELLOW}⚠ 重要提醒：确认新端口工作正常后再断开当前SSH连接！${NC}"

# 12. 显示当前配置
echo ""
echo "📄 当前配置文件内容："
echo "--- SSH Socket 配置 ---"
cat /etc/systemd/system/ssh.socket.d/override.conf
echo ""
echo "--- SSH Service 配置 ---"
cat /etc/systemd/system/ssh.service.d/override.conf
echo ""
echo "--- sshd_config 端口设置 ---"
grep -n "^Port " /etc/ssh/sshd_config
echo ""
echo "--- UFW防火墙规则 ---"
ufw status numbered
