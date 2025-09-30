#!/bin/bash

# 完全重置MySQL并修复认证问题

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

echo_header "完全重置MySQL数据库"

# 1. 停止所有容器
echo_info "停止所有容器..."
docker-compose -f deployment/docker/docker-compose.yml down -v

# 2. 清理所有相关的Docker卷
echo_warn "清理所有数据卷..."
docker volume rm mrdocs-safe_mysql_data 2>/dev/null || true
docker volume rm mrdocs_mrdoc-safe_mysql_data 2>/dev/null || true
docker volume rm $(docker volume ls -q | grep mysql | grep mrdoc) 2>/dev/null || true

# 3. 创建MySQL初始化SQL脚本
echo_info "创建MySQL初始化脚本..."
mkdir -p deployment/docker/mysql-init
cat > deployment/docker/mysql-init/01-init-db.sql << 'EOF'
-- 初始化MrDoc数据库
SET NAMES utf8mb4;

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `mrdoc` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 确保用户被正确创建
CREATE USER IF NOT EXISTS 'mrdoc'@'%' IDENTIFIED BY 'mrdocpassword123';
CREATE USER IF NOT EXISTS 'mrdoc'@'localhost' IDENTIFIED BY 'mrdocpassword123';

-- 授予权限
GRANT ALL PRIVILEGES ON `mrdoc`.* TO 'mrdoc'@'%';
GRANT ALL PRIVILEGES ON `mrdoc`.* TO 'mrdoc'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

-- 设置认证插件（MySQL 8.0）
ALTER USER 'mrdoc'@'%' IDENTIFIED WITH mysql_native_password BY 'mrdocpassword123';
ALTER USER 'mrdoc'@'localhost' IDENTIFIED WITH mysql_native_password BY 'mrdocpassword123';

-- 再次刷新权限
FLUSH PRIVILEGES;

-- 验证用户创建
SELECT user, host, plugin FROM mysql.user WHERE user = 'mrdoc';
EOF

# 4. 创建简化的docker-compose配置
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
      - mysql_data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d:ro
    command:
      - --default-authentication-plugin=mysql_native_password
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-ssl
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-prootpassword123"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
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
  mysql_data:
    driver: local
  redis_data:
    driver: local
  mrdoc_logs:
    driver: local
EOF

# 5. 更新entrypoint.sh
echo_info "更新entrypoint.sh脚本..."
cat > deployment/docker/entrypoint.sh << 'EOF'
#!/bin/bash

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

# 显示环境变量（调试用）
echo_info "数据库配置："
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"
echo "  DB_USER=$DB_USER"

# 等待数据库服务可用
echo_info "⏳ 等待数据库服务启动..."
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --protocol=tcp -e "SELECT 1;" >/dev/null 2>&1; then
        echo_info "✅ 数据库连接成功!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo_warn "等待数据库 ($RETRY_COUNT/$MAX_RETRIES)..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_error "无法连接到数据库！"
    echo_error "尝试使用root用户测试连接..."
    mysql -h"$DB_HOST" -P"$DB_PORT" -uroot -prootpassword123 --protocol=tcp -e "SELECT 1;" 2>&1
    exit 1
fi

# 切换到项目目录
cd /app

# 确保数据库存在
echo_info "📊 确保数据库存在..."
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" --protocol=tcp -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true

# 数据库迁移
echo_info "🔄 执行数据库迁移..."
python manage.py makemigrations --noinput || echo_warn "生成迁移文件失败"
python manage.py migrate --noinput || echo_error "数据库迁移失败"

# 收集静态文件
echo_info "📁 收集静态文件..."
python manage.py collectstatic --noinput --clear || echo_warn "收集静态文件失败"

# 创建超级用户
echo_info "👤 检查超级用户..."
python manage.py shell << PYTHON_EOF
from django.contrib.auth.models import User
try:
    if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
        User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
        print("✅ 超级用户创建成功: $DJANGO_SUPERUSER_USERNAME")
    else:
        print("ℹ️ 超级用户已存在: $DJANGO_SUPERUSER_USERNAME")
except Exception as e:
    print(f"⚠️ 创建超级用户失败: {e}")
PYTHON_EOF

# 创建必要目录
mkdir -p /app/media/uploads
mkdir -p /app/logs

# 设置权限
chmod -R 755 /app/media
chmod -R 755 /app/static

echo_info "🎉 MrDoc 初始化完成!"
echo_info "📝 管理员: $DJANGO_SUPERUSER_USERNAME / $DJANGO_SUPERUSER_PASSWORD"

# 启动应用
if [ "${1}" = 'runserver' ]; then
    echo_info "🔧 启动开发服务器..."
    exec python manage.py runserver 0.0.0.0:8000
elif [ "${1}" = 'gunicorn' ]; then
    echo_info "🚀 启动生产服务器..."
    exec gunicorn --bind 0.0.0.0:8000 \
        --workers 4 \
        --timeout 120 \
        --keep-alive 5 \
        --log-level info \
        --access-logfile - \
        --error-logfile - \
        MrDoc.wsgi:application
else
    echo_info "🔧 启动开发服务器（默认）..."
    exec python manage.py runserver 0.0.0.0:8000
fi
EOF

# 6. 确保脚本有执行权限
chmod +x deployment/docker/entrypoint.sh

# 7. 启动MySQL服务
echo_header "启动MySQL服务"
docker-compose -f deployment/docker/docker-compose.yml up -d mrdocs-safe-mysql

echo_info "等待MySQL完全启动（60秒）..."
for i in {1..60}; do
    if docker exec mrdocs-safe-mysql mysqladmin ping -h localhost -uroot -prootpassword123 --silent 2>/dev/null; then
        echo_info "MySQL已启动"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# 8. 验证MySQL用户
echo_header "验证MySQL用户"
echo_info "检查用户是否正确创建..."
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "
SELECT user, host, plugin FROM mysql.user WHERE user = 'mrdoc';
SHOW GRANTS FOR 'mrdoc'@'%';
" 2>&1 || echo_error "用户检查失败"

# 9. 测试mrdoc用户连接
echo_info "测试mrdoc用户连接..."
docker exec mrdocs-safe-mysql mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 'Connection successful!' as status;" 2>&1 || echo_error "mrdoc用户连接失败"

# 10. 启动所有服务
echo_header "启动所有服务"
docker-compose -f deployment/docker/docker-compose.yml up -d

# 11. 等待服务启动
echo_info "等待服务完全启动（30秒）..."
sleep 30

# 12. 检查服务状态
echo_header "服务状态"
docker-compose -f deployment/docker/docker-compose.yml ps

# 13. 查看应用日志
echo_header "应用启动日志"
docker logs mrdocs-safe-app --tail 50

echo_header "重置完成"
echo_info "访问地址："
echo_info "  - MrDoc应用: http://$(hostname -I | awk '{print $1}'):8081"
echo_info "  - Nginx代理: http://$(hostname -I | awk '{print $1}'):8082"
echo_info ""
echo_info "如果仍有问题，请查看详细日志："
echo_info "  docker logs mrdocs-safe-app -f"