#!/bin/bash
# 快速升级脚本：从旧版本升级到 v1.9.7
# 用法: ./upgrade.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "  ansible-lemp 升级工具"
echo -e "  目标版本: v1.9.7"
echo -e "==========================================${NC}"
echo

# 检查是否在正确的目录
if [ ! -d ".git" ]; then
    echo -e "${RED}错误: 请在 ansible-lemp 项目根目录运行此脚本${NC}"
    exit 1
fi

# 显示当前版本（从 Git tags 获取）
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "${YELLOW}当前版本: ${CURRENT_VERSION}${NC}"
echo

# 备份提示
echo -e "${YELLOW}📦 步骤 1: 创建备份${NC}"
echo -e "  正在创建备份..."

# 备份 crontab
if crontab -l > ~/crontab.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Crontab 已备份"
else
    echo -e "  ${YELLOW}⚠${NC} Crontab 备份失败（可能没有配置crontab）"
fi

# 创建备份分支
BACKUP_BRANCH="backup-v${CURRENT_VERSION}-$(date +%Y%m%d)"
if git branch "$BACKUP_BRANCH" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Git 分支已备份: $BACKUP_BRANCH"
else
    echo -e "  ${YELLOW}⚠${NC} 备份分支已存在"
fi

echo

# 检查本地修改
echo -e "${YELLOW}🔍 步骤 2: 检查本地修改${NC}"
if git diff --quiet && git diff --cached --quiet; then
    echo -e "  ${GREEN}✓${NC} 没有未提交的修改"
else
    echo -e "  ${YELLOW}⚠${NC} 发现本地修改，正在保存..."
    git stash save "Auto-stash before upgrade to v1.9.7 on $(date)"
    echo -e "  ${GREEN}✓${NC} 本地修改已保存到 stash"
fi

echo

# 获取更新
echo -e "${YELLOW}📥 步骤 3: 获取最新版本${NC}"
git fetch origin --tags
echo -e "  ${GREEN}✓${NC} 已获取远程更新"

echo

# 切换到最新版本
echo -e "${YELLOW}🔄 步骤 4: 切换到 v1.9.7${NC}"
if git checkout v1.9.7; then
    echo -e "  ${GREEN}✓${NC} 已切换到 v1.9.7"
else
    echo -e "  ${RED}✗${NC} 切换失败"
    exit 1
fi

NEW_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "  ${GREEN}✓${NC} 新版本: ${NEW_VERSION}"

echo

# 创建日志目录
echo -e "${YELLOW}📁 步骤 5: 创建日志目录${NC}"
mkdir -p /home/doge/Dropbox/logs
echo -e "  ${GREEN}✓${NC} 日志目录已创建: /home/doge/Dropbox/logs"

echo

# 设置脚本权限
echo -e "${YELLOW}🔧 步骤 6: 设置脚本权限${NC}"
chmod +x dogetools/*.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} 脚本权限已设置"

echo

# 显示新文件
echo -e "${YELLOW}📄 步骤 7: 新增文件列表${NC}"
echo -e "  ${GREEN}✓${NC} dogetools/maintenance.sh"
echo -e "  ${GREEN}✓${NC} dogetools/mysqldump.sh"
echo -e "  ${GREEN}✓${NC} dogetools/services-restart.sh"
echo -e "  ${GREEN}✓${NC} dogetools/snapshot.sh"
echo -e "  ${GREEN}✓${NC} scripts/services-check.sh"
echo -e "  ${GREEN}✓${NC} crontab-optimized.txt"
echo -e "  ${GREEN}✓${NC} UPGRADE_GUIDE.md"

echo

# 完成
echo -e "${GREEN}=========================================="
echo -e "  ✅ 升级完成！"
echo -e "==========================================${NC}"
echo
echo -e "${YELLOW}📋 后续步骤:${NC}"
echo
echo -e "1. 查看升级指南:"
echo -e "   ${BLUE}cat UPGRADE_GUIDE.md${NC}"
echo
echo -e "2. 测试新功能:"
echo -e "   ${BLUE}./scripts/services-check.sh${NC}"
echo
echo -e "3. 更新 crontab (推荐):"
echo -e "   ${BLUE}crontab crontab-optimized.txt${NC}"
echo
echo -e "4. 验证 crontab:"
echo -e "   ${BLUE}crontab -l${NC}"
echo
echo -e "${YELLOW}💾 回滚方法:${NC}"
echo -e "   ${BLUE}git checkout $BACKUP_BRANCH${NC}"
echo -e "   ${BLUE}crontab ~/crontab.backup.*${NC}"
echo
echo -e "${GREEN}升级成功！享受新功能吧！ 🎉${NC}"

