#!/bin/bash
# 用法: ./add_ssh_key.sh <USERNAME>
# 示例: ./add_ssh_key.sh doge

if [ -z "$1" ]; then
    echo "❌ 请输入用户名"
    exit 1
fi

USERNAME="$1"

# 确保用户存在
if ! id "$USERNAME" &>/dev/null; then
    echo "❌ 用户 $USERNAME 不存在，请先创建"
    exit 1
fi

# 创建 .ssh 目录
sudo mkdir -p /home/$USERNAME/.ssh
sudo chmod 700 /home/$USERNAME/.ssh

# 用 sudo 检查并复制
if sudo test -f /home/ubuntu/.ssh/authorized_keys; then
    sudo cp /home/ubuntu/.ssh/authorized_keys /home/$USERNAME/.ssh/
    sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
    sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys
    echo "✅ 已复制 ubuntu 的 authorized_keys 给 $USERNAME"
else
    echo "⚠️ /home/ubuntu/.ssh/authorized_keys 不存在，请手动配置"
fi
