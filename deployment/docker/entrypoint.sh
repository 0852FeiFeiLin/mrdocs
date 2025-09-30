#!/bin/bash

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

echo_info "🚀 启动 MrDoc 应用 (SQLite版本)..."

# 显示环境配置
echo_info "环境配置:"
echo "  数据库: SQLite"
echo "  REDIS_HOST=$REDIS_HOST"
echo "  REDIS_PORT=$REDIS_PORT"

cd /app

# 确保config目录和SQLite数据库文件存在
echo_info "📦 初始化SQLite数据库..."
mkdir -p /app/config
if [ ! -f "/app/config/db.sqlite3" ]; then
    touch /app/config/db.sqlite3
    chmod 664 /app/config/db.sqlite3
    echo_info "✅ SQLite数据库文件已创建"
else
    echo_info "ℹ️ SQLite数据库文件已存在"
fi

# Django操作
echo_info "🔄 执行数据库迁移..."
python manage.py makemigrations --noinput || echo_warn "makemigrations失败，可能没有新的迁移"
python manage.py migrate --noinput || { echo_error "数据库迁移失败"; exit 1; }

echo_info "📁 收集静态文件..."
python manage.py collectstatic --noinput --clear || echo_warn "收集静态文件失败"

echo_info "👤 创建超级用户..."
python manage.py shell << PYTHON_EOF
import os
from django.contrib.auth.models import User
username = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
email = os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@example.com')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'admin123456')
if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username, email, password)
    print(f"✅ 超级用户创建成功: {username}")
else:
    print(f"ℹ️ 超级用户已存在: {username}")
PYTHON_EOF

# 创建目录
mkdir -p /app/media/uploads /app/logs
chmod -R 755 /app/media /app/static /app/config 2>/dev/null || echo_warn "部分文件权限设置失败，忽略继续..."

echo_info "🎉 MrDoc 初始化完成!"

# 启动服务
exec /home/mrdoc/.local/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 --log-level info --access-logfile - --error-logfile - MrDoc.wsgi:application
