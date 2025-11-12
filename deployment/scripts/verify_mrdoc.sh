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

# 端口默认值（可通过环境变量覆盖）
HTTP_PORT="${MRDOC_HTTP_PORT:-19081}"
HTTPS_PORT="${MRDOC_HTTPS_PORT:-19443}"
REDIS_PORT="${MRDOC_REDIS_PORT:-16380}"
APP_DEBUG_PORT="${MRDOC_APP_PORT:-}"

# 2. 检查端口
echo -e "\n端口监听:"
ports=("$HTTP_PORT" "$HTTPS_PORT" "$REDIS_PORT")
if [ -n "$APP_DEBUG_PORT" ]; then
    ports+=("$APP_DEBUG_PORT")
fi
for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo_info "端口 $port 正常"
    else
        echo_error "端口 $port 未监听"
    fi
done

# 3. 测试访问
echo -e "\nHTTP访问测试:"
response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HTTP_PORT}" 2>/dev/null || echo "000")
if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ]; then
    echo_info "应用响应正常 (HTTP $response)"
else
    echo_error "应用无响应 (HTTP $response)"
fi

# 4. 显示访问信息
SERVER_IP=$(hostname -I | awk '{print $1}')
echo -e "\n========================="
echo "访问信息:"
echo "  应用地址: http://$SERVER_IP:${HTTP_PORT}"
echo "  HTTPS地址: https://$SERVER_IP:${HTTPS_PORT}"
if [ -n "$APP_DEBUG_PORT" ]; then
    echo "  调试端口: http://$SERVER_IP:${APP_DEBUG_PORT}"
fi
echo "  管理员: admin / admin123456"
echo "========================="
