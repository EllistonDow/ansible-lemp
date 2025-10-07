#!/bin/bash

# LEMP Stack Quick Installation Script
# Version: 2.2.2
# This script provides a convenient way to install the LEMP stack

set -e

echo "============================================="
echo "     Ansible LEMP Stack Installation"
echo "============================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show version
show_version() {
    echo -e "${BLUE}LEMP Stack Installation Script${NC}"
    echo -e "Version: ${GREEN}2.2.2${NC}"
    echo -e "Git Tag: ${GREEN}$(git describe --tags --abbrev=0 2>/dev/null || echo 'N/A')${NC}"
    echo ""
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed. Please install Ansible first:"
    echo "sudo apt update && sudo apt install ansible -y"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "ansible.cfg" ] || [ ! -f "playbooks/site.yml" ]; then
    print_error "Please run this script from the ansible-lemp directory"
    exit 1
fi

# Show version info
show_version

print_header "Installation Options"
echo "1. Full LEMP Stack Installation (recommended)"
echo "2. Custom Component Selection"
echo "3. Individual Component Installation"
echo "4. Uninstall Components"
echo "5. Show Version Information"
echo "6. Exit"
echo ""

read -p "Please select an option (1-6): " choice

case $choice in
    1)
        print_header "Full LEMP Stack Installation"
        print_status "This will install all LEMP components..."
        sleep 2
        
        print_status "Starting installation..."
        ansible-playbook playbooks/site.yml
        
        print_status "Installation completed!"
        print_warning "Please check the README.md for post-installation configuration"
        ;;
        
    2)
        print_header "Custom Component Selection"
        
        # Component selection
        read -p "Install Nginx? (Y/n): " install_nginx
        read -p "Install PHP 8.3? (Y/n): " install_php
        read -p "Install Percona MySQL? (Y/n): " install_percona
        read -p "Install OpenSearch? (Y/n): " install_opensearch
        read -p "Install RabbitMQ? (Y/n): " install_rabbitmq
        read -p "Install Valkey? (Y/n): " install_valkey
        read -p "Install Varnish? (Y/n): " install_varnish
        read -p "Install Basic Tools? (Y/n): " install_basic_tools
        
        # Build extra vars
        extra_vars=""
        [[ $install_nginx =~ ^[Nn] ]] && extra_vars+=" install_nginx=false"
        [[ $install_php =~ ^[Nn] ]] && extra_vars+=" install_php=false"
        [[ $install_percona =~ ^[Nn] ]] && extra_vars+=" install_percona=false"
        [[ $install_opensearch =~ ^[Nn] ]] && extra_vars+=" install_opensearch=false"
        [[ $install_rabbitmq =~ ^[Nn] ]] && extra_vars+=" install_rabbitmq=false"
        [[ $install_valkey =~ ^[Nn] ]] && extra_vars+=" install_valkey=false"
        [[ $install_varnish =~ ^[Nn] ]] && extra_vars+=" install_varnish=false"
        [[ $install_basic_tools =~ ^[Nn] ]] && extra_vars+=" install_basic_tools=false"
        
        print_status "Starting custom installation..."
        if [ -n "$extra_vars" ]; then
            ansible-playbook playbooks/site.yml --extra-vars "$extra_vars"
        else
            ansible-playbook playbooks/site.yml
        fi
        ;;
        
    3)
        print_header "Individual Component Installation"
        echo "Available components:"
        echo "1. OpenSearch 2.19"
        echo "2. Percona MySQL 8.4"
        echo "3. PHP 8.3"
        echo "4. RabbitMQ 4.1"
        echo "5. Valkey 8"
        echo "6. Varnish 7.6"
        echo "7. Nginx 1.27.4+ModSecurity"
        echo ""
        
        read -p "Select component (1-7): " component
        
        case $component in
            1) ansible-playbook playbooks/opensearch.yml ;;
            2) ansible-playbook playbooks/percona.yml ;;
            3) ansible-playbook playbooks/php.yml ;;
            4) ansible-playbook playbooks/rabbitmq.yml ;;
            5) ansible-playbook playbooks/valkey.yml ;;
            6) ansible-playbook playbooks/varnish.yml ;;
            7) ansible-playbook playbooks/nginx.yml ;;
            *) print_error "Invalid selection" && exit 1 ;;
        esac
        ;;
        
    4)
        print_header "Component Uninstallation"
        echo "Available components for uninstallation:"
        echo "1. OpenSearch 2.19"
        echo "2. Percona MySQL 8.4"
        echo "3. PHP 8.3"
        echo "4. RabbitMQ 4.1"
        echo "5. Valkey 8"
        echo "6. Varnish 7.6"
        echo "7. Nginx 1.29.1 + ModSecurity"
        echo ""
        
        read -p "Select component to uninstall (1-7): " component
        
        print_warning "This will completely remove the selected component and its data!"
        read -p "Are you sure? (yes/no): " confirm
        
        if [ "$confirm" = "yes" ]; then
            case $component in
                1) ansible-playbook playbooks/opensearch.yml --extra-vars "action=uninstall" ;;
                2) ansible-playbook playbooks/percona.yml --extra-vars "action=uninstall" ;;
                3) ansible-playbook playbooks/php.yml --extra-vars "action=uninstall" ;;
                4) ansible-playbook playbooks/rabbitmq.yml --extra-vars "action=uninstall" ;;
                5) ansible-playbook playbooks/valkey.yml --extra-vars "action=uninstall" ;;
                6) ansible-playbook playbooks/varnish.yml --extra-vars "action=uninstall" ;;
                7) ansible-playbook playbooks/nginx.yml --extra-vars "action=uninstall" ;;
                *) print_error "Invalid selection" && exit 1 ;;
            esac
        else
            print_status "Uninstallation cancelled."
        fi
        ;;
        
    5)
        print_header "Version Information"
        show_version
        print_status "Press Enter to continue..."
        read
        exec "$0"  # Restart the script
        ;;
        
    6)
        print_status "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid option selected"
        exit 1
        ;;
esac

print_header "Installation Summary"
print_status "LEMP Stack installation completed successfully!"
echo ""
print_status "Next steps:"
echo "1. Configure your inventory file (inventories/production)"
echo "2. Update variables in group_vars/all.yml"
echo "3. Configure firewall and security settings"
echo "4. Set up SSL certificates with Certbot"
echo ""
print_status "For detailed documentation, see README.md"
