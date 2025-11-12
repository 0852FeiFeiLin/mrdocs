#!/bin/bash
set -e

echo "==================================="
echo "MrDoc Docker 启动脚本"
echo "==================================="

cd /app

# 检查数据库是否已初始化
if [ ! -f "/app/db.sqlite3" ]; then
    echo "📋 首次启动，初始化数据库..."

    # 运行迁移
    echo "🔧 运行数据库迁移..."
    python manage.py migrate --noinput

    # 导入初始数据
    if [ -f "/app/mrdoc_data.json" ]; then
        echo "📦 导入初始数据..."
        python manage.py loaddata /app/mrdoc_data.json
        echo "✅ 数据导入完成！"
    else
        echo "⚠️  未找到初始数据文件，跳过数据导入"
    fi

    # 重建搜索索引
    echo "🔍 重建搜索索引..."
    python manage.py rebuild_index --noinput

else
    echo "✅ 数据库已存在，跳过初始化"

    # 运行迁移（以防有新的迁移）
    echo "🔧 检查并运行数据库迁移..."
    python manage.py migrate --noinput
fi

# 收集静态文件
echo "📁 收集静态文件..."
python manage.py collectstatic --noinput || true

echo "==================================="
echo "✅ 初始化完成！"
echo "==================================="
echo ""
echo "📌 管理员账号: admin"
echo "📌 管理员密码: admin123"
echo "📌 API Token: 43c395f68784452784585da896cb5c66"
echo ""
echo "🚀 启动MrDoc服务..."
echo "==================================="

# 启动Django服务
if [ "$1" = "runserver" ]; then
    exec python manage.py runserver "$2"
else
    exec "$@"
fi
