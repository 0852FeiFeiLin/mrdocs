#!/bin/bash

# 紧急修复脚本
# 快速修复Nginx配置并重启服务

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# 项目目录
PROJECT_DIR="/root/kt/mrdocs"
cd "$PROJECT_DIR"

echo_info "执行紧急修复..."

# 1. 修复Nginx配置文件（去掉include语句）
echo_info "修复Nginx配置..."
sed -i 's/^    include \/etc\/nginx\/snippets\/mrdoc-common.conf;/    # include \/etc\/nginx\/snippets\/mrdoc-common.conf;/' deployment/nginx/mrdoc.conf

# 2. 重启所有服务
echo_info "重启所有服务..."
docker-compose -f deployment/docker/docker-compose.yml restart

# 3. 等待服务启动
echo_info "等待30秒让服务完全启动..."
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# 4. 检查服务状态
echo_info "服务状态："
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mrdocs-safe

# 5. 查看应用日志最后20行
echo_info "MrDoc应用日志（最后20行）："
docker logs mrdocs-safe-app --tail 20

echo_info "紧急修复完成！"
echo_info "访问 http://$(hostname -I | awk '{print $1}'):8081 测试应用"