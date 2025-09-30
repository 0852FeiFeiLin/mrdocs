# 立即执行 - 修复MySQL认证问题

## 问题原因
MySQL用户`mrdoc`没有正确创建，导致应用无法连接数据库。

## 解决方案
执行完全重置脚本，这会：
1. 停止所有容器并清理数据卷
2. 创建MySQL初始化脚本
3. 重新启动服务并验证连接

## 立即执行命令

```bash
cd /root/kt/mrdocs

# 1. 首先上传修改后的Nginx配置（已修复include问题）
# 2. 然后执行重置脚本
./deployment/scripts/reset_mysql_completely.sh
```

## 脚本会执行的操作
1. ⚠️ **删除所有MySQL数据** - 请确认这是可以接受的
2. 创建新的MySQL初始化脚本
3. 使用mysql_native_password认证
4. 验证用户创建
5. 测试连接
6. 启动所有服务

## 预期结果
- MySQL用户正确创建
- 应用能够连接数据库
- 所有服务正常运行
- 可通过8081端口访问应用

## 如果还有问题
查看详细日志：
```bash
docker logs mrdocs-safe-app -f
docker exec mrdocs-safe-mysql mysql -uroot -prootpassword123 -e "SELECT user, host FROM mysql.user WHERE user='mrdoc';"
```

## 注意事项
- 脚本会删除所有MySQL数据，如有重要数据请先备份
- 确保端口3307, 6380, 8081, 8082未被占用