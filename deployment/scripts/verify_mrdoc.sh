#!/bin/bash

# MrDoc 验证脚本 - 快速检查服务状态

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}✓${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

echo_error() {
    echo -e "${RED}✗${NC} $1"
}

echo "MrDoc 服务状态检查"
echo "========================="

# 1. 检查容器状态
echo -e "\n容器状态:"
containers=("mrdocs-safe-app" "mrdocs-safe-mysql" "mrdocs-safe-redis" "mrdocs-safe-nginx")
for container in "${containers[@]}"; do
    if docker ps | grep -q "$container"; then
        echo_info "$container 运行中"
    else
        echo_error "$container 未运行"
    fi
done

# 2. 检查端口
echo -e "\n端口监听:"
ports=("8081" "8082" "3307" "6380")
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo_info "端口 $port 正常"
    else
        echo_error "端口 $port 未监听"
    fi
done

# 3. 测试访问
echo -e "\nHTTP访问测试:"
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")
if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
    echo_info "应用响应正常 (HTTP $response)"
else
    echo_error "应用无响应 (HTTP $response)"
fi

# 4. 显示访问信息
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "\n========================="
echo "访问信息:"
echo "  应用地址: http://$SERVER_IP:8081"
echo "  Nginx代理: http://$SERVER_IP:8082"
echo "  管理员: admin / admin123456"
echo "========================="