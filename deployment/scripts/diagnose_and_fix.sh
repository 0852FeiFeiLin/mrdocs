#!/bin/bash

# 深度诊断和修复脚本
# 诊断MrDoc应用无响应问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════${NC}"
}

# 项目目录
PROJECT_DIR="/root/kt/mrdocs"
cd "$PROJECT_DIR"

echo_header "MrDoc 深度诊断和修复"

# 1. 首先查看应用容器日志
echo_header "1. MrDoc应用容器完整日志"
docker logs mrdocs-safe-app 2>&1 | tail -50

# 2. 检查容器是否正在运行
echo_header "2. 容器运行状态"
docker inspect mrdocs-safe-app --format='{{.State.Status}}' || echo_error "容器不存在"

# 3. 进入容器检查文件
echo_header "3. 检查容器内文件系统"
docker exec mrdocs-safe-app ls -la /app/ 2>&1 || echo_error "无法访问容器文件系统"

# 4. 检查requirements.txt
echo_header "4. 检查Python依赖"
docker exec mrdocs-safe-app pip list | grep -E "Django|mysqlclient|gunicorn" || echo_error "依赖检查失败"

# 5. 测试Django shell
echo_header "5. 测试Django Shell"
docker exec mrdocs-safe-app python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
print('环境变量设置成功')
try:
    import django
    print('Django导入成功')
    django.setup()
    print('Django初始化成功')
except Exception as e:
    print(f'Django初始化失败: {e}')
" 2>&1

# 6. 检查端口绑定
echo_header "6. 检查端口绑定"
docker exec mrdocs-safe-app netstat -tuln 2>&1 || docker exec mrdocs-safe-app ss -tuln 2>&1 || echo_warn "无法检查端口"

# 7. 尝试手动运行Django
echo_header "7. 手动启动Django测试"
echo_info "停止容器..."
docker stop mrdocs-safe-app

echo_info "使用调试模式重新启动..."
docker run --rm -d \
  --name mrdocs-safe-app-debug \
  --network mrdocs_mrdoc-safe-network \
  -e DEBUG=True \
  -e DB_ENGINE=mysql \
  -e DB_NAME=mrdoc \
  -e DB_USER=mrdoc \
  -e DB_PASSWORD=mrdocpassword123 \
  -e DB_HOST=mrdocs-safe-mysql \
  -e DB_PORT=3306 \
  -e REDIS_HOST=mrdocs-safe-redis \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD=redispassword123 \
  -e REDIS_DB=4 \
  -p 8081:8000 \
  docker-mrdocs-safe-app \
  bash -c "cd /app && python manage.py runserver 0.0.0.0:8000"

echo_info "等待启动..."
sleep 10

echo_info "查看调试容器日志..."
docker logs mrdocs-safe-app-debug --tail 30

echo_info "测试连接..."
curl -v http://localhost:8081 2>&1 | head -20

# 8. 清理调试容器
echo_header "8. 清理和重启原容器"
docker stop mrdocs-safe-app-debug 2>/dev/null || true
docker rm mrdocs-safe-app-debug 2>/dev/null || true

# 9. 使用修复后的启动命令重新创建容器
echo_info "重新启动原容器..."
cd "$PROJECT_DIR"
docker-compose -f deployment/docker/docker-compose.yml up -d mrdocs-safe-app

echo_header "诊断完成"
echo_info "请检查上述输出，特别注意错误信息。"
echo_info "如果看到具体错误，请告诉我以便进一步修复。"