#!/bin/bash

# 修复MySQL SSL问题

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

echo_info "修复MySQL SSL问题..."

# 1. 创建MySQL客户端配置文件
echo_info "创建MySQL客户端配置文件..."
cat > deployment/docker/mysql-client.cnf << 'EOF'
[client]
ssl-mode=DISABLED
protocol=tcp

[mysql]
ssl-mode=DISABLED
protocol=tcp

[mysqladmin]
ssl-mode=DISABLED
protocol=tcp
EOF

# 2. 更新Dockerfile.mrdoc以复制配置文件
echo_info "更新Dockerfile..."
cat > deployment/docker/Dockerfile.mrdoc << 'EOF'
# MrDoc 源码版 Dockerfile
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=MrDoc.settings

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    pkg-config \
    default-libmysqlclient-dev \
    default-mysql-client \
    libssl-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    zlib1g-dev \
    git \
    curl \
    wget \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 创建非root用户
RUN useradd -m -u 1000 mrdoc && \
    chown -R mrdoc:mrdoc /app

USER mrdoc

# 复制项目文件
COPY --chown=mrdoc:mrdoc . /app/

# 复制MySQL配置文件到用户目录
COPY --chown=mrdoc:mrdoc deployment/docker/mysql-client.cnf /home/mrdoc/.my.cnf

# 创建必要目录
RUN mkdir -p /app/logs /app/media /app/static /app/config

# 安装 Python 依赖
RUN pip install --no-cache-dir --user -r requirements.txt

# 修复 requirements.txt 中缺失的依赖
RUN pip install --no-cache-dir --user \
    cryptography==41.0.7 \
    django-filter==23.5 \
    gunicorn==21.2.0 \
    gevent==23.9.1 \
    mysqlclient==2.2.0

# 复制启动脚本
COPY --chown=mrdoc:mrdoc deployment/docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# 启动命令
ENTRYPOINT ["/app/entrypoint.sh"]
EOF

# 3. 更新entrypoint.sh
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
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --silent 2>/dev/null; then
        echo_info "✅ 数据库连接成功!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo_warn "等待数据库 ($RETRY_COUNT/$MAX_RETRIES)..."
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo_error "无法连接到数据库！"
    exit 1
fi

# 切换到项目目录
cd /app

# 创建数据库（如果不存在）
echo_info "📊 创建数据库..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || echo_warn "数据库可能已存在"

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
echo_info "🌐 访问地址: http://your-server-ip:8000"

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
        --access-logfile - \
        --error-logfile - \
        MrDoc.wsgi:application
else
    echo_info "🔧 启动开发服务器（默认）..."
    exec python manage.py runserver 0.0.0.0:8000
fi
EOF

# 4. 确保脚本有执行权限
chmod +x deployment/docker/entrypoint.sh

# 5. 重建应用容器
echo_info "停止应用容器..."
docker stop mrdocs-safe-app 2>/dev/null || true
docker rm mrdocs-safe-app 2>/dev/null || true

echo_info "重建应用镜像..."
docker-compose -f deployment/docker/docker-compose.yml build mrdocs-safe-app

echo_info "启动应用容器..."
docker-compose -f deployment/docker/docker-compose.yml up -d mrdocs-safe-app

echo_info "等待服务启动..."
sleep 20

echo_info "查看应用日志..."
docker logs mrdocs-safe-app --tail 50

echo_info "测试连接..."
curl -I http://localhost:8081 2>&1 || echo "应用可能还在启动中..."

echo_info "修复完成！"
echo_info "请等待1-2分钟让服务完全启动。"
echo_info "访问: http://$(hostname -I | awk '{print $1}'):8081"