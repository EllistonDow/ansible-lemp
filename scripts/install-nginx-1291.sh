#!/bin/bash

# Nginx 1.29.1 Installation Script
# This script installs nginx 1.29.1 with ModSecurity support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Nginx 1.29.1 with ModSecurity Installation${NC}"
echo "================================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ This script should not be run as root${NC}"
   echo "Please run with: bash $0"
   exit 1
fi

# Check if ansible is available
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}❌ Ansible is not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  Warning: This will remove existing nginx installation${NC}"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

echo -e "${BLUE}📋 Starting nginx 1.29.1 installation...${NC}"

# Run the ansible playbook
cd /home/doge/ansible-lemp
ansible-playbook playbooks/nginx_1291.yml --ask-become-pass

echo -e "${GREEN}✅ Installation completed!${NC}"
echo
echo -e "${BLUE}🔧 Next steps:${NC}"
echo "1. Test nginx: sudo nginx -t"
echo "2. Check status: sudo systemctl status nginx"
echo "3. Configure ModSecurity: ./scripts/toggle-modsecurity.sh [0-10]"
echo "4. View logs: sudo tail -f /var/log/nginx/error.log"
echo
echo -e "${GREEN}🎉 Nginx 1.29.1 with ModSecurity is ready!${NC}"
