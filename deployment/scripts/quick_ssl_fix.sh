#!/bin/bash

# 快速修复MySQL SSL问题（不重建镜像）

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

echo_info "快速修复MySQL SSL问题..."

# 1. 在运行的容器中创建配置文件
echo_info "在应用容器中创建MySQL配置..."
docker exec mrdocs-safe-app bash -c 'cat > ~/.my.cnf << EOF
[client]
ssl-mode=DISABLED
protocol=tcp

[mysql]
ssl-mode=DISABLED
protocol=tcp

[mysqladmin]
ssl-mode=DISABLED
protocol=tcp
EOF'

# 2. 测试连接
echo_info "测试数据库连接..."
docker exec mrdocs-safe-app mysql -h mrdocs-safe-mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 'Connection successful!' as status;" 2>&1

# 3. 重启应用容器
echo_info "重启应用容器..."
docker restart mrdocs-safe-app

echo_info "等待服务启动（30秒）..."
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

# 4. 查看日志
echo_info "查看应用日志..."
docker logs mrdocs-safe-app --tail 30

# 5. 测试HTTP访问
echo_info "测试HTTP访问..."
sleep 5
curl -I http://localhost:8081 2>&1 || echo "应用可能还在启动中..."

echo_info "快速修复完成！"
echo_info "访问: http://$(hostname -I | awk '{print $1}'):8081"