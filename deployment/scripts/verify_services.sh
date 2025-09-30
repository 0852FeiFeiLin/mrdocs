#!/bin/bash

# 服务验证脚本
# 检查MrDoc所有服务是否正常运行

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# 项目目录
PROJECT_DIR="/root/kt/mrdocs"
cd "$PROJECT_DIR"

echo_header "MrDoc 服务状态检查"

# 1. 检查Docker容器状态
echo_header "1. Docker容器状态"
docker-compose -f deployment/docker/docker-compose.yml ps

# 2. 检查MySQL连接
echo_header "2. MySQL数据库连接测试"
if docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "SELECT 1;" &>/dev/null; then
    echo_info "MySQL root连接成功"
else
    echo_error "MySQL root连接失败"
fi

if docker exec mrdocs-safe-mysql mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 1;" &>/dev/null; then
    echo_info "MySQL mrdoc用户连接成功"
else
    echo_error "MySQL mrdoc用户连接失败"
fi

# 3. 检查Redis连接
echo_header "3. Redis缓存连接测试"
if docker exec mrdocs-safe-redis redis-cli -a redispassword123 ping | grep -q "PONG"; then
    echo_info "Redis连接成功"
else
    echo_error "Redis连接失败"
fi

# 4. 检查应用服务
echo_header "4. MrDoc应用服务检查"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|301\|302"; then
    echo_info "MrDoc应用服务响应正常 (端口 8081)"
else
    echo_error "MrDoc应用服务无响应"
fi

# 5. 检查Nginx服务
echo_header "5. Nginx代理服务检查"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/health | grep -q "200"; then
    echo_info "Nginx健康检查通过 (端口 8082)"
else
    echo_warn "Nginx健康检查失败（可能是配置问题）"
fi

# 6. 检查端口占用
echo_header "6. 端口占用情况"
echo "检查端口占用..."
for port in 8081 8082 3307 6380; do
    if netstat -tuln | grep -q ":$port"; then
        echo_info "端口 $port 已正确监听"
    else
        echo_error "端口 $port 未监听"
    fi
done

# 7. 检查日志错误
echo_header "7. 最近错误日志"
echo "MrDoc应用日志（最后10行）："
docker logs mrdocs-safe-app --tail 10 2>&1 | grep -E "ERROR|CRITICAL|FATAL" || echo_info "没有发现错误日志"

echo "MySQL日志（最后10行）："
docker logs mrdocs-safe-mysql --tail 10 2>&1 | grep -E "ERROR|error" || echo_info "没有发现错误日志"

echo "Nginx日志（最后10行）："
docker logs mrdocs-safe-nginx --tail 10 2>&1 | grep -E "error|emerg|alert|crit" || echo_info "没有发现错误日志"

# 8. 检查磁盘空间
echo_header "8. 磁盘空间检查"
df -h | grep -E "^/|Filesystem"

# 9. 检查Docker资源使用
echo_header "9. Docker资源使用情况"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# 10. 生成访问信息
echo_header "访问信息汇总"
echo_info "MrDoc应用地址: http://$(hostname -I | awk '{print $1}'):8081"
echo_info "Nginx代理地址: http://$(hostname -I | awk '{print $1}'):8082"
echo_info "MySQL端口: 3307 (用户: mrdoc, 密码: mrdocpassword123)"
echo_info "Redis端口: 6380 (密码: redispassword123)"
echo_info "管理员账户: admin / Admin@123456"

echo_header "服务状态检查完成"