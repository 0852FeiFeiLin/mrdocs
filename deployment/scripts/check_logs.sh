#!/bin/bash

# 检查MrDoc部署日志

echo "MrDoc 容器状态和日志检查"
echo "================================"

# 容器状态
echo -e "\n1. 容器状态:"
docker ps -a | grep mrdocs-safe

# 应用容器日志
echo -e "\n2. 应用容器日志（最后50行）:"
docker logs mrdocs-safe-app --tail 50 2>&1 || echo "容器不存在"

# MySQL容器状态
echo -e "\n3. MySQL容器状态:"
docker exec mrdocs-safe-mysql mysqladmin ping -h localhost 2>&1 && echo "MySQL正常" || echo "MySQL异常"

# 检查容器重启次数
echo -e "\n4. 容器重启信息:"
docker inspect mrdocs-safe-app --format='{{.RestartCount}} 次重启' 2>/dev/null || echo "容器不存在"

# 测试数据库连接
echo -e "\n5. 测试数据库连接:"
docker exec mrdocs-safe-mysql mysql -umrdoc -pmrdocpassword123 -e "SELECT 'Database connection OK';" 2>&1 || echo "数据库连接失败"

echo "================================"