#!/bin/bash

# 快速修复脚本
# 修复Nginx配置和检查MrDoc应用问题

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

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 项目目录
PROJECT_DIR="/root/kt/mrdocs"
cd "$PROJECT_DIR"

echo_info "开始快速修复..."

# 1. 查看MrDoc应用详细日志
echo_info "查看MrDoc应用日志..."
echo "================================================"
docker logs mrdocs-safe-app --tail 100
echo "================================================"

# 2. 重启Nginx容器（使用新配置）
echo_info "重启Nginx容器..."
docker restart mrdocs-safe-nginx

# 3. 等待服务启动
echo_info "等待服务启动..."
sleep 10

# 4. 检查容器状态
echo_info "检查容器状态..."
docker ps | grep mrdocs-safe

# 5. 测试连接
echo_info "测试服务连接..."
echo "测试MySQL连接..."
docker exec mrdocs-safe-app python -c "
import os
import MySQLdb
try:
    conn = MySQLdb.connect(
        host=os.environ.get('DB_HOST', 'mrdocs-safe-mysql'),
        user=os.environ.get('DB_USER', 'mrdoc'),
        passwd=os.environ.get('DB_PASSWORD', 'mrdocpassword123'),
        db=os.environ.get('DB_NAME', 'mrdoc'),
        charset='utf8mb4'
    )
    print('✓ Python MySQL连接成功!')
    conn.close()
except Exception as e:
    print(f'✗ Python MySQL连接失败: {e}')
" 2>&1 || echo_warn "Python MySQL连接测试失败"

# 6. 进入容器检查Django设置
echo_info "检查Django配置..."
docker exec mrdocs-safe-app python -c "
import os
import sys
sys.path.insert(0, '/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
import django
django.setup()
from django.conf import settings
print('Django配置加载成功!')
print(f'数据库引擎: {settings.DATABASES[\"default\"][\"ENGINE\"]}')
print(f'数据库名称: {settings.DATABASES[\"default\"][\"NAME\"]}')
print(f'数据库主机: {settings.DATABASES[\"default\"][\"HOST\"]}')
print(f'数据库端口: {settings.DATABASES[\"default\"][\"PORT\"]}')
" 2>&1 || echo_warn "Django配置检查失败"

# 7. 尝试手动启动应用
echo_info "尝试直接在容器内启动应用..."
docker exec -it mrdocs-safe-app bash -c "
cd /app
python manage.py runserver 0.0.0.0:8000
" &

# 等待几秒
sleep 5

# 8. 测试端口
echo_info "测试端口响应..."
curl -I http://localhost:8081 2>&1 || echo_warn "端口8081无响应"

echo_info "修复脚本执行完成！"