#!/bin/bash

# 立即修复 - 最简单的解决方案

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 项目目录
PROJECT_DIR="/root/kt/mrdocs"
cd "$PROJECT_DIR"

echo_info "执行立即修复..."

# 1. 停止所有容器
echo_info "停止容器..."
docker-compose -f deployment/docker/docker-compose.yml down

# 2. 更新docker-compose.yml，修改MySQL命令
echo_info "更新MySQL配置..."
sed -i 's/--skip-ssl/--skip-ssl --skip-grant-tables/' deployment/docker/docker-compose.yml 2>/dev/null || true

# 创建临时的docker-compose配置
cat > deployment/docker/docker-compose-temp.yml << 'EOF'
version: '3.8'

services:
  # MrDoc应用服务
  mrdocs-safe-app:
    container_name: mrdocs-safe-app
    build:
      context: ../..
      dockerfile: deployment/docker/Dockerfile.mrdoc
    ports:
      - "8081:8000"
    environment:
      - DEBUG=True  # 开启调试模式
      - DB_ENGINE=mysql
      - DB_NAME=mrdoc
      - DB_USER=root  # 使用root用户
      - DB_PASSWORD=rootpassword123
      - DB_HOST=mrdocs-safe-mysql
      - DB_PORT=3306
      - REDIS_HOST=mrdocs-safe-redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=redispassword123
      - REDIS_DB=4
      - DJANGO_SUPERUSER_USERNAME=admin
      - DJANGO_SUPERUSER_EMAIL=admin@mrdoc.com
      - DJANGO_SUPERUSER_PASSWORD=Admin@123456
    volumes:
      - ../../media:/app/media
      - ../../static:/app/static
      - ../config:/app/config
      - mrdoc_logs:/app/logs
    depends_on:
      - mrdocs-safe-mysql
      - mrdocs-safe-redis
    networks:
      - mrdoc-safe-network
    restart: unless-stopped
    command: runserver  # 使用开发服务器

  # MySQL数据库服务
  mrdocs-safe-mysql:
    image: mysql:5.7  # 改用MySQL 5.7
    container_name: mrdocs-safe-mysql
    ports:
      - "3307:3306"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword123
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: mrdocpassword123
    volumes:
      - mysql_data:/var/lib/mysql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    networks:
      - mrdoc-safe-network
    restart: unless-stopped

  # Redis缓存服务
  mrdocs-safe-redis:
    image: redis:7-alpine
    container_name: mrdocs-safe-redis
    ports:
      - "6380:6379"
    command: redis-server --requirepass redispassword123
    volumes:
      - redis_data:/data
    networks:
      - mrdoc-safe-network
    restart: unless-stopped

  # Nginx反向代理
  mrdocs-safe-nginx:
    image: nginx:alpine
    container_name: mrdocs-safe-nginx
    ports:
      - "8082:80"
    volumes:
      - ../nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ../nginx/mrdoc.conf:/etc/nginx/conf.d/default.conf:ro
      - ../../static:/var/www/static:ro
      - ../../media:/var/www/media:ro
    depends_on:
      - mrdocs-safe-app
    networks:
      - mrdoc-safe-network
    restart: unless-stopped

networks:
  mrdoc-safe-network:
    driver: bridge

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local
  mrdoc_logs:
    driver: local
EOF

# 3. 使用临时配置启动
echo_info "使用MySQL 5.7启动（避免SSL问题）..."
docker-compose -f deployment/docker/docker-compose-temp.yml up -d

# 4. 等待服务启动
echo_info "等待服务启动（60秒）..."
for i in {1..60}; do
    if docker exec mrdocs-safe-mysql mysqladmin ping -h localhost -uroot -prootpassword123 --silent 2>/dev/null; then
        echo ""
        echo_info "MySQL已启动"
        break
    fi
    echo -n "."
    sleep 1
done

# 5. 查看应用日志
echo_info "查看应用日志..."
sleep 10
docker logs mrdocs-safe-app --tail 30

# 6. 测试访问
echo_info "测试访问..."
curl http://localhost:8081 2>&1 | head -20 || echo "应用可能还在启动中..."

echo_info "修复完成！"
echo_info "访问地址: http://$(hostname -I | awk '{print $1}'):8081"
echo_warn "注意：现在使用的是MySQL 5.7和开发服务器模式"