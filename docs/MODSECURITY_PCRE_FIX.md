# ModSecurity PCRE Compatibility Fix

## Problem
The ModSecurity nginx module was compiled against PCRE2 but required legacy PCRE functions (`pcre_malloc`, `pcre_free`), causing nginx startup failures with:
```
nginx: [emerg] dlopen() "/etc/nginx/modules/ngx_http_modsecurity_module.so" failed 
(/etc/nginx/modules/ngx_http_modsecurity_module.so: undefined symbol: pcre_malloc)
```

## Solution Implemented
This playbook has been updated to automatically fix this issue by:

### 1. Compilation Fix
- Added `--without-pcre2 --with-pcre` flags to nginx configure command
- Forces use of legacy PCRE library instead of PCRE2
- Located in: `roles/nginx/tasks/install.yml` line 93

### 2. Runtime Library Loading
- Creates systemd service override for nginx
- Preloads PCRE3 library via `LD_PRELOAD=/lib/x86_64-linux-gnu/libpcre.so.3`
- Files created:
  - `/etc/systemd/system/nginx.service.d/override.conf`
  - Handler for systemd daemon reload

### 3. Automatic Application
The fix is automatically applied when:
- `modsecurity_enabled: true` is set in group_vars or host_vars
- The nginx role is executed

## Manual Verification
After running the playbook, verify the fix:

```bash
# Check nginx status
sudo systemctl status nginx

# Test nginx configuration
sudo nginx -t

# Check ModSecurity module loading
ldd /etc/nginx/modules/ngx_http_modsecurity_module.so | grep pcre

# Verify systemd override exists
ls -la /etc/systemd/system/nginx.service.d/override.conf
```

## Files Modified
- `roles/nginx/tasks/install.yml` - Added PCRE flags and systemd override tasks
- `roles/nginx/handlers/main.yml` - Created handler for systemd reload
- This documentation file

## Compatibility
This fix is compatible with:
- Ubuntu 24.04 LTS
- nginx 1.28.0 and newer
- ModSecurity 3.x
- Any system with libpcre3 installed
