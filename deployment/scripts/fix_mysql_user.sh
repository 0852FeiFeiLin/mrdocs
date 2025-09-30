#!/bin/bash

# 快速修复MySQL用户权限问题

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

echo_info "修复MySQL用户权限..."

# 1. 进入MySQL容器修复权限
echo_info "重新创建mrdoc用户..."
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 << 'EOF'
-- 删除旧用户（如果存在）
DROP USER IF EXISTS 'mrdoc'@'%';
DROP USER IF EXISTS 'mrdoc'@'localhost';
DROP USER IF EXISTS 'mrdoc'@'172.31.0.4';

-- 创建新用户（MySQL 5.7语法）
CREATE USER 'mrdoc'@'%' IDENTIFIED BY 'mrdocpassword123';
CREATE USER 'mrdoc'@'localhost' IDENTIFIED BY 'mrdocpassword123';

-- 授予权限
GRANT ALL PRIVILEGES ON *.* TO 'mrdoc'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'mrdoc'@'localhost' WITH GRANT OPTION;

-- 刷新权限
FLUSH PRIVILEGES;

-- 验证用户
SELECT user, host FROM mysql.user WHERE user='mrdoc';
EOF

# 2. 测试连接
echo_info "测试mrdoc用户连接..."
docker exec mrdocs-safe-mysql mysql -umrdoc -pmrdocpassword123 -e "SELECT 'Connection successful!';" && echo_info "✅ 连接成功" || echo_error "连接失败"

# 3. 重启应用容器
echo_info "重启应用容器..."
docker restart mrdocs-safe-app

# 4. 等待应用启动
echo_info "等待应用启动（60秒）..."
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null | grep -qE "200|301|302"; then
        echo
        echo_info "✅ 应用已启动!"
        break
    fi
    echo -n "."
    sleep 1
done
echo

# 5. 显示应用日志
echo_info "应用日志（最后20行）："
docker logs mrdocs-safe-app --tail 20

echo
echo_info "修复完成！"
echo_info "访问: http://$(hostname -I | awk '{print $1}'):8081"
echo_info "管理员: admin / admin123456"