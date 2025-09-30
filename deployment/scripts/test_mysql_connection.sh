#!/bin/bash

# 快速测试MySQL连接

echo "测试MySQL连接..."
echo "====================================="

# 1. 测试root用户
echo "1. Root用户连接："
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "SELECT 'Root connection OK' as status;" 2>&1

# 2. 测试mrdoc用户
echo -e "\n2. mrdoc用户连接："
docker exec mrdocs-safe-mysql mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 'mrdoc connection OK' as status;" 2>&1

# 3. 查看用户列表
echo -e "\n3. MySQL用户列表："
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "SELECT user, host, plugin FROM mysql.user WHERE user IN ('root', 'mrdoc');" 2>&1

# 4. 查看权限
echo -e "\n4. mrdoc用户权限："
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "SHOW GRANTS FOR 'mrdoc'@'%';" 2>&1

# 5. 从应用容器测试连接
echo -e "\n5. 从应用容器测试连接："
docker exec mrdocs-safe-app mysql -h mrdocs-safe-mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 'App to MySQL connection OK' as status;" 2>&1 || echo "应用容器无法连接MySQL"

echo "====================================="