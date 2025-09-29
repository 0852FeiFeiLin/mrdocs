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
while ! mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --silent; do
    echo_warn "数据库未就绪，等待 5 秒..."
    sleep 5
done

echo_info "✅ 数据库连接成功!"

# 切换到项目目录
cd /app

# 创建数据库（如果不存在）
echo_info "📊 创建数据库..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || echo_warn "数据库可能已存在"

# 数据库迁移
echo_info "🔄 执行数据库迁移..."
python manage.py makemigrations --noinput || echo_warn "生成迁移文件失败，可能已是最新"
python manage.py migrate --noinput || echo_error "数据库迁移失败"

# 收集静态文件
echo_info "📁 收集静态文件..."
python manage.py collectstatic --noinput --clear || echo_warn "收集静态文件失败"

# 创建超级用户（仅在首次运行时）
echo_info "👤 检查超级用户..."
python manage.py shell << EOF
from django.contrib.auth.models import User
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
    print("超级用户创建成功: $DJANGO_SUPERUSER_USERNAME")
else:
    print("超级用户已存在: $DJANGO_SUPERUSER_USERNAME")
EOF

# 创建上传目录
mkdir -p /app/media/uploads
mkdir -p /app/logs

# 设置权限
chmod -R 755 /app/media
chmod -R 755 /app/static

echo_info "🎉 MrDoc 初始化完成!"
echo_info "📝 管理员账户: $DJANGO_SUPERUSER_USERNAME"
echo_info "🌐 访问地址: http://your-server-ip"

# 启动应用
if [ "${1}" = 'runserver' ]; then
    echo_info "🔧 启动开发服务器..."
    exec python manage.py runserver 0.0.0.0:8000
elif [ "${1}" = 'gunicorn' ]; then
    echo_info "🚀 启动生产服务器..."
    exec gunicorn --bind 0.0.0.0:8000 \
        --workers 4 \
        --worker-class gevent \
        --worker-connections 1000 \
        --max-requests 1000 \
        --max-requests-jitter 100 \
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