#!/bin/bash
# 用法: ./nopasswd_sudo.sh <USERNAME>
# 示例: ./nopasswd_sudo.sh doge

# ---------- 检查参数 ----------
if [ -z "$1" ]; then
    echo "❌ 请输入要创建的用户名，例如: $0 doge"
    exit 1
fi

USERNAME="$1"

# ---------- 创建用户 ----------
if id "$USERNAME" &>/dev/null; then
    echo "✅ 用户 $USERNAME 已存在，跳过创建"
else
    sudo adduser --disabled-password --gecos "" "$USERNAME"
    echo "✅ 用户 $USERNAME 已创建"
fi

# ---------- 加入 sudo 组 ----------
sudo usermod -aG sudo "$USERNAME"
echo "✅ 用户 $USERNAME 已加入 sudo 组"

# ---------- 配置免密码 sudo ----------
SUDOERS_FILE="/etc/sudoers.d/90-${USERNAME}-nopasswd"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 440 "$SUDOERS_FILE"
echo "✅ 已配置 $USERNAME 免密码 sudo"

# ---------- 提示 ----------
echo "🎉 用户 $USERNAME 已完成配置，现在执行 sudo 命令无需输入密码"
