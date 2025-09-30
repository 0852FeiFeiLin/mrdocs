#!/bin/bash

# 紧急修复 - 立即修复MySQL权限并重启应用

echo "紧急修复MySQL权限问题..."

# 1. 修复MySQL权限
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "
GRANT ALL PRIVILEGES ON *.* TO 'mrdoc'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
" 2>/dev/null && echo "✓ 权限已更新" || echo "✗ 权限更新失败"

# 2. 重启应用容器
docker restart mrdocs-safe-app

# 3. 等待60秒
echo "等待应用启动（60秒）..."
sleep 60

# 4. 查看状态
echo -e "\n应用日志："
docker logs mrdocs-safe-app --tail 10

echo -e "\n测试访问："
curl -I http://localhost:8081 2>&1 | head -5

echo -e "\n访问: http://$(hostname -I | awk '{print $1}'):8081"