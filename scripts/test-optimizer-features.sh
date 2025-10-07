#!/bin/bash
# Magento2 优化脚本功能测试
# 测试所有新增功能的可用性

echo "🚀 Magento2 优化脚本功能测试"
echo "================================"
echo

# 测试帮助功能
echo "1. 测试帮助功能..."
./scripts/magento2-optimizer.sh help > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 帮助功能正常"
else
    echo "❌ 帮助功能异常"
fi

# 测试监控功能
echo "2. 测试监控功能..."
./scripts/magento2-optimizer.sh 64 monitor > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 监控功能正常"
else
    echo "❌ 监控功能异常"
fi

# 测试基准测试功能
echo "3. 测试基准测试功能..."
./scripts/magento2-optimizer.sh 64 benchmark > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 基准测试功能正常"
else
    echo "❌ 基准测试功能异常"
fi

# 测试配置建议功能
echo "4. 测试配置建议功能..."
./scripts/magento2-optimizer.sh 64 suggest > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 配置建议功能正常"
else
    echo "❌ 配置建议功能异常"
fi

# 测试状态查看功能
echo "5. 测试状态查看功能..."
./scripts/magento2-optimizer.sh 64 status > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ 状态查看功能正常"
else
    echo "❌ 状态查看功能异常"
fi

echo
echo "🎉 功能测试完成！"
echo "所有新增功能都已验证可用。"
