#!/bin/bash
# MrDoc 本地开发环境初始化脚本

set -e  # 遇到错误立即退出

echo "========================================="
echo "  MrDoc 本地开发环境初始化"
echo "========================================="

# 激活虚拟环境
source venv/bin/activate

# 1. 数据库迁移
echo ""
echo "[1/6] 执行数据库迁移..."
python manage.py makemigrations
python manage.py migrate

# 2. 创建超级用户（跳过，手动创建）
echo ""
echo "[2/6] 创建超级用户（稍后手动创建）..."
# python manage.py createsuperuser

# 3. 收集静态文件
echo ""
echo "[3/6] 收集静态文件..."
python manage.py collectstatic --noinput

# 4. 生成搜索索引
echo ""
echo "[4/6] 生成搜索索引..."
python manage.py rebuild_index --noinput

# 5. 测试服务器连接
echo ""
echo "[5/6] 测试配置..."
python manage.py check

# 6. 完成
echo ""
echo "[6/6] 初始化完成！"
echo "========================================="
echo "  启动开发服务器："
echo "  python manage.py runserver 0.0.0.0:8000"
echo "========================================="
