#!/bin/bash

# MrDoc 清理脚本 - 清理所有容器和数据

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 清理MrDoc相关的所有容器和数据
echo_warn "此操作将删除MrDoc相关的所有容器和数据！"
read -p "确定要清理吗? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo_info "已取消清理"
    exit 0
fi

echo_info "开始清理MrDoc部署..."

# 停止并删除容器
echo_info "停止并删除容器..."
docker stop mrdocs-safe-app mrdocs-safe-mysql mrdocs-safe-redis mrdocs-safe-nginx 2>/dev/null || true
docker rm mrdocs-safe-app mrdocs-safe-mysql mrdocs-safe-redis mrdocs-safe-nginx 2>/dev/null || true

# 删除镜像
echo_info "删除镜像..."
docker rmi docker-mrdocs-safe-app 2>/dev/null || true

# 删除数据卷
echo_info "删除数据卷..."
docker volume rm $(docker volume ls -q | grep -E "mrdocs-safe") 2>/dev/null || true

# 删除网络
echo_info "删除网络..."
docker network rm mrdocs-safe-network 2>/dev/null || true

echo_info "✅ 清理完成！可以重新运行部署脚本了。"