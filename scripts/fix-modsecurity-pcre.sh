#!/bin/bash
# Comprehensive ModSecurity PCRE Compatibility Fix Script
# This script fixes the pcre_malloc undefined symbol error

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 ModSecurity PCRE Compatibility Fix${NC}"
echo "====================================="

# Check if ModSecurity module exists
if [ ! -f "/etc/nginx/modules/ngx_http_modsecurity_module.so" ]; then
    echo -e "${YELLOW}ModSecurity module not found. Nothing to fix.${NC}"
    exit 0
fi

# Test for PCRE issue
echo -e "${BLUE}Testing nginx configuration...${NC}"
if nginx -t 2>&1 | grep -q "undefined symbol: pcre_malloc"; then
    echo -e "${YELLOW}⚠️  PCRE compatibility issue detected!${NC}"
    
    # Backup configuration
    echo -e "${BLUE}Backing up nginx configuration...${NC}"
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.pcre_backup_$(date +%Y%m%d_%H%M%S)
    
    # Attempt recompilation
    echo -e "${BLUE}Attempting to recompile ModSecurity module with proper PCRE support...${NC}"
    
    if [ -d "/usr/local/src/ModSecurity-nginx" ]; then
        cd /usr/local/src/ModSecurity-nginx
        
        # Get nginx version and configure args
        NGINX_VERSION=$(nginx -v 2>&1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
        CONFIGURE_ARGS=$(nginx -V 2>&1 | grep "configure arguments" | sed 's/.*configure arguments: //')
        
        # Download nginx source if not exists
        if [ ! -d "/usr/local/src/nginx-${NGINX_VERSION}" ]; then
            cd /usr/local/src
            wget -q "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" || {
                echo -e "${RED}Failed to download nginx source${NC}"
                exit 1
            }
            tar -xzf "nginx-${NGINX_VERSION}.tar.gz"
        fi
        
        # Recompile with proper PCRE settings
        cd "/usr/local/src/nginx-${NGINX_VERSION}"
        
        echo -e "${BLUE}Configuring nginx with PCRE compatibility...${NC}"
        ./configure $CONFIGURE_ARGS \
            --without-pcre2 \
            --with-pcre \
            --with-pcre-jit \
            --add-dynamic-module=/usr/local/src/ModSecurity-nginx 2>/dev/null || {
            echo -e "${RED}Configuration failed, falling back to disable ModSecurity${NC}"
            # Fallback: disable ModSecurity
            sed -i 's/^load_module modules\/ngx_http_modsecurity_module.so;/#load_module modules\/ngx_http_modsecurity_module.so; # PCRE incompatibility/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity on;/#    modsecurity on; # PCRE incompatibility/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity_rules_file/#    modsecurity_rules_file # PCRE incompatibility/' /etc/nginx/nginx.conf
            exit 0
        }
        
        echo -e "${BLUE}Building ModSecurity module...${NC}"
        make modules 2>/dev/null || {
            echo -e "${RED}Build failed, disabling ModSecurity${NC}"
            sed -i 's/^load_module modules\/ngx_http_modsecurity_module.so;/#load_module modules\/ngx_http_modsecurity_module.so; # Build failed/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity on;/#    modsecurity on; # Build failed/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity_rules_file/#    modsecurity_rules_file # Build failed/' /etc/nginx/nginx.conf
            exit 0
        }
        
        # Install new module
        cp objs/ngx_http_modsecurity_module.so /etc/nginx/modules/
        echo -e "${GREEN}✅ ModSecurity module recompiled successfully${NC}"
        
        # Test configuration
        if nginx -t; then
            echo -e "${GREEN}✅ Nginx configuration test passed!${NC}"
            echo -e "${GREEN}✅ ModSecurity PCRE compatibility fixed!${NC}"
        else
            echo -e "${YELLOW}Configuration test still fails, disabling ModSecurity...${NC}"
            sed -i 's/^load_module modules\/ngx_http_modsecurity_module.so;/#load_module modules\/ngx_http_modsecurity_module.so; # Still incompatible/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity on;/#    modsecurity on; # Still incompatible/' /etc/nginx/nginx.conf
            sed -i 's/^[[:space:]]*modsecurity_rules_file/#    modsecurity_rules_file # Still incompatible/' /etc/nginx/nginx.conf
        fi
    else
        echo -e "${RED}ModSecurity source not found, disabling ModSecurity${NC}"
        sed -i 's/^load_module modules\/ngx_http_modsecurity_module.so;/#load_module modules\/ngx_http_modsecurity_module.so; # Source not found/' /etc/nginx/nginx.conf
        sed -i 's/^[[:space:]]*modsecurity on;/#    modsecurity on; # Source not found/' /etc/nginx/nginx.conf
        sed -i 's/^[[:space:]]*modsecurity_rules_file/#    modsecurity_rules_file # Source not found/' /etc/nginx/nginx.conf
    fi
else
    echo -e "${GREEN}✅ No PCRE compatibility issues detected${NC}"
fi

echo -e "${BLUE}PCRE compatibility check completed!${NC}"
