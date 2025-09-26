#!/bin/bash
# OpenSearch 2.19 独立安装脚本

set -e

echo "=== OpenSearch 2.19 安装脚本 ==="

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "此脚本不应该以root用户运行，请使用sudo"
   exit 1
fi

# 安装依赖
echo "安装Java 11和依赖包..."
sudo apt update
sudo apt install -y openjdk-11-jdk curl wget

# 创建用户和目录
echo "创建opensearch用户和目录..."
sudo groupadd -f opensearch
sudo useradd -r -g opensearch -s /bin/false opensearch || true
sudo mkdir -p /opt/opensearch /var/lib/opensearch /var/log/opensearch /etc/opensearch
sudo chown -R opensearch:opensearch /opt/opensearch /var/lib/opensearch /var/log/opensearch /etc/opensearch

# 下载OpenSearch
echo "下载OpenSearch 2.19.0..."
cd /tmp
if [ ! -f opensearch-2.19.0-linux-x64.tar.gz ]; then
    wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.19.0/opensearch-2.19.0-linux-x64.tar.gz
fi

# 解压安装
echo "安装OpenSearch..."
sudo tar -xzf opensearch-2.19.0-linux-x64.tar.gz -C /opt/opensearch --strip-components=1
sudo chown -R opensearch:opensearch /opt/opensearch

# 创建配置文件
echo "配置OpenSearch..."
sudo tee /etc/opensearch/opensearch.yml > /dev/null << 'EOF'
cluster.name: opensearch-cluster
node.name: "$(hostname)"

path.data: /var/lib/opensearch
path.logs: /var/log/opensearch

network.host: 127.0.0.1
http.port: 9200
transport.port: 9300

discovery.type: single-node
bootstrap.memory_lock: true

# Disable security plugin for simple setup
plugins.security.disabled: true

# Basic OpenSearch configuration without security
action.auto_create_index: true
EOF

# 创建JVM配置
sudo tee /opt/opensearch/config/jvm.options > /dev/null << 'EOF'
-Xms1g
-Xmx1g
-XX:+UseG1GC
-XX:G1HeapRegionSize=32m
-XX:+AlwaysPreTouch
-Xss1m
-Djava.awt.headless=true
-Dfile.encoding=UTF-8
-Djna.nosys=true
-Dio.netty.noUnsafe=true
-Dio.netty.noKeySetOptimization=true
-Dio.netty.recycler.maxCapacityPerThread=0
-Dlog4j.shutdownHookEnabled=false
-Dlog4j2.disable.jmx=true
-Djava.locale.providers=SPI,COMPAT
EOF

# 创建systemd服务
echo "创建systemd服务..."
sudo tee /etc/systemd/system/opensearch.service > /dev/null << 'EOF'
[Unit]
Description=OpenSearch
Documentation=https://opensearch.org/docs/latest/
Wants=network-online.target
After=network-online.target
ConditionNetwork=true

[Service]
Type=notify
RuntimeDirectory=opensearch
PrivateTmp=true
Environment=OPENSEARCH_HOME=/opt/opensearch
Environment=OPENSEARCH_PATH_CONF=/etc/opensearch
Environment=PID_DIR=/var/run/opensearch
Environment=OPENSEARCH_SD_NOTIFY=true
EnvironmentFile=-/etc/default/opensearch
WorkingDirectory=/opt/opensearch
User=opensearch
Group=opensearch
ExecStart=/opt/opensearch/bin/opensearch
LimitNOFILE=65535
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
TimeoutStopSec=0
KillSignal=SIGTERM
KillMode=process
SendSIGKILL=no
SuccessExitStatus=143
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

# 设置系统限制
echo "设置系统限制..."
sudo tee /etc/security/limits.d/opensearch.conf > /dev/null << 'EOF'
opensearch soft nofile 65536
opensearch hard nofile 65536
opensearch soft nproc 4096
opensearch hard nproc 4096
opensearch soft memlock unlimited
opensearch hard memlock unlimited
EOF

# 设置vm.max_map_count
echo "设置内核参数..."
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 启动服务
echo "启动OpenSearch服务..."
sudo systemctl daemon-reload
sudo systemctl enable opensearch
sudo systemctl start opensearch

# 等待服务启动
echo "等待OpenSearch启动..."
for i in {1..30}; do
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        echo "OpenSearch启动成功！"
        curl http://localhost:9200
        break
    fi
    sleep 2
done

echo "=== OpenSearch安装完成 ==="
echo "访问地址: http://localhost:9200"
echo "状态检查: sudo systemctl status opensearch"
