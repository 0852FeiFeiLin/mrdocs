#!/bin/bash

# MySQL认证问题修复脚本
# 解决MrDoc应用容器无法连接MySQL的问题

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

echo_info "开始修复MySQL认证问题..."

# 1. 停止所有容器
echo_info "停止所有容器..."
docker-compose -f deployment/docker/docker-compose.yml down

# 2. 清理MySQL数据卷
echo_warn "清理MySQL数据卷（将丢失现有数据）..."
docker volume rm mrdocs-safe_mysql_data 2>/dev/null || true

# 3. 创建MySQL初始化脚本
echo_info "创建MySQL初始化脚本..."
cat > deployment/docker/mysql-init.sql << 'EOF'
-- 创建数据库
CREATE DATABASE IF NOT EXISTS mrdoc CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户并授权（兼容MySQL 5.7和8.0）
CREATE USER IF NOT EXISTS 'mrdoc'@'%' IDENTIFIED BY 'mrdocpassword123';
GRANT ALL PRIVILEGES ON mrdoc.* TO 'mrdoc'@'%';

-- 确保权限生效
FLUSH PRIVILEGES;

-- 设置认证插件为mysql_native_password（MySQL 8.0）
ALTER USER 'mrdoc'@'%' IDENTIFIED WITH mysql_native_password BY 'mrdocpassword123';

-- 再次刷新权限
FLUSH PRIVILEGES;
EOF

# 4. 更新docker-compose.yml，添加初始化脚本
echo_info "更新docker-compose配置..."
cat > deployment/docker/docker-compose.yml << 'EOF'
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
      - DEBUG=False
      - DB_ENGINE=mysql
      - DB_NAME=mrdoc
      - DB_USER=mrdoc
      - DB_PASSWORD=mrdocpassword123
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
      mrdocs-safe-mysql:
        condition: service_healthy
      mrdocs-safe-redis:
        condition: service_healthy
    networks:
      - mrdoc-safe-network
    restart: unless-stopped
    command: gunicorn

  # MySQL数据库服务
  mrdocs-safe-mysql:
    image: mysql:8.0
    container_name: mrdocs-safe-mysql
    ports:
      - "3307:3306"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword123
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: mrdocpassword123
    volumes:
      - mrdocs-safe_mysql_data:/var/lib/mysql
      - ./mysql-init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --default-authentication-plugin=mysql_native_password
      --skip-ssl
      --sql-mode=''
      --max_connections=500
      --max_allowed_packet=128M
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-prootpassword123"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - mrdoc-safe-network
    restart: unless-stopped

  # Redis缓存服务
  mrdocs-safe-redis:
    image: redis:7-alpine
    container_name: mrdocs-safe-redis
    ports:
      - "6380:6379"
    command: >
      redis-server
      --requirepass redispassword123
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --save 900 1
      --save 300 10
      --save 60 10000
      --databases 16
    volumes:
      - mrdocs-safe_redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redispassword123", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
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
  mrdocs-safe_mysql_data:
  mrdocs-safe_redis_data:
  mrdoc_logs:
EOF

# 5. 更新entrypoint.sh以支持更好的错误处理
echo_info "更新entrypoint.sh..."
cat > deployment/docker/entrypoint.sh << 'EOF'
#!/bin/bash

# MrDoc Docker 启动脚本

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

echo_info "🚀 启动 MrDoc 应用..."

# 等待数据库服务可用
echo_info "⏳ 等待数据库服务启动..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --protocol=tcp --silent 2>/dev/null; then
        echo_info "✅ 数据库连接成功!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo_warn "等待数据库 ($RETRY_COUNT/$MAX_RETRIES)..."
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_error "无法连接到数据库，请检查配置!"
    exit 1
fi

# 切换到项目目录
cd /app

# 测试数据库连接
echo_info "测试数据库连接..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --protocol=tcp -e "SELECT 1;" 2>/dev/null || {
    echo_error "数据库连接测试失败!"
    exit 1
}

# 创建数据库（如果不存在）
echo_info "📊 创建数据库..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --protocol=tcp -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || echo_warn "数据库可能已存在"

# 数据库迁移
echo_info "🔄 执行数据库迁移..."
python manage.py makemigrations --noinput || echo_warn "生成迁移文件失败，可能已是最新"
python manage.py migrate --noinput || echo_error "数据库迁移失败"

# 收集静态文件
echo_info "📁 收集静态文件..."
python manage.py collectstatic --noinput --clear || echo_warn "收集静态文件失败"

# 创建超级用户（仅在首次运行时）
echo_info "👤 检查超级用户..."
python manage.py shell << PYTHON_EOF
from django.contrib.auth.models import User
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
    print("超级用户创建成功: $DJANGO_SUPERUSER_USERNAME")
else:
    print("超级用户已存在: $DJANGO_SUPERUSER_USERNAME")
PYTHON_EOF

# 创建上传目录
mkdir -p /app/media/uploads
mkdir -p /app/logs

# 设置权限
chmod -R 755 /app/media
chmod -R 755 /app/static

echo_info "🎉 MrDoc 初始化完成!"
echo_info "📝 管理员账户: $DJANGO_SUPERUSER_USERNAME"
echo_info "🌐 访问地址: http://your-server-ip:8081"

# 启动应用
if [ "${1}" = 'runserver' ]; then
    echo_info "🔧 启动开发服务器..."
    exec python manage.py runserver 0.0.0.0:8000
elif [ "${1}" = 'gunicorn' ]; then
    echo_info "🚀 启动生产服务器..."
    exec gunicorn --bind 0.0.0.0:8000 \
        --workers 4 \
        --worker-class sync \
        --timeout 120 \
        --keep-alive 5 \
        --log-level info \
        --access-logfile /app/logs/access.log \
        --error-logfile /app/logs/error.log \
        --capture-output \
        MrDoc.wsgi:application
else
    echo_info "🔧 启动开发服务器（默认）..."
    exec python manage.py runserver 0.0.0.0:8000
fi
EOF

# 6. 确保脚本有执行权限
chmod +x deployment/docker/entrypoint.sh

# 7. 启动服务
echo_info "启动所有服务..."
docker-compose -f deployment/docker/docker-compose.yml up -d

# 8. 等待服务启动
echo_info "等待服务启动..."
sleep 10

# 9. 检查服务状态
echo_info "检查服务状态..."
docker-compose -f deployment/docker/docker-compose.yml ps

# 10. 查看应用日志
echo_info "查看应用启动日志..."
docker logs mrdocs-safe-app --tail 50

echo_info "✅ MySQL认证问题修复脚本执行完成!"
echo_info "请检查上述日志，确认服务是否正常启动。"
echo_info ""
echo_info "访问地址："
echo_info "  - MrDoc应用: http://your-server-ip:8081"
echo_info "  - Nginx代理: http://your-server-ip:8082"
echo_info ""
echo_info "管理员账户："
echo_info "  - 用户名: admin"
echo_info "  - 密码: Admin@123456"