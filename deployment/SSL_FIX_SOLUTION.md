# MySQL SSL问题解决方案

## 问题根本原因
- MySQL服务器配置了`--skip-ssl`（禁用SSL）
- 但应用容器的MySQL客户端默认要求SSL连接
- 导致连接失败："SSL is required, but the server does not support it"

## 立即解决方案

### 方案1：最快修复（推荐）
使用MySQL 5.7替代8.0，避免SSL问题：
```bash
cd /root/kt/mrdocs
./deployment/scripts/fix_now.sh
```
这会：
- 使用MySQL 5.7（SSL兼容性更好）
- 使用root用户连接（避免权限问题）
- 开启调试模式查看详细错误

### 方案2：快速配置修复
在现有容器中添加MySQL配置：
```bash
cd /root/kt/mrdocs
./deployment/scripts/quick_ssl_fix.sh
```

### 方案3：完整重建（彻底解决）
重建镜像并添加MySQL客户端配置：
```bash
cd /root/kt/mrdocs
./deployment/scripts/fix_ssl_issue.sh
```

## 手动修复步骤

如果脚本失败，手动执行：

### 1. 在应用容器中禁用SSL
```bash
# 进入容器
docker exec -it mrdocs-safe-app bash

# 创建MySQL配置
cat > ~/.my.cnf << 'EOF'
[client]
ssl-mode=DISABLED
EOF

# 测试连接
mysql -h mrdocs-safe-mysql -umrdoc -pmrdocpassword123 mrdoc -e "SELECT 1;"

# 退出容器
exit

# 重启容器
docker restart mrdocs-safe-app
```

### 2. 或者使用root用户
修改docker-compose.yml中的应用环境变量：
```yaml
environment:
  - DB_USER=root
  - DB_PASSWORD=rootpassword123
```
然后重启：
```bash
docker-compose -f deployment/docker/docker-compose.yml up -d
```

## 验证修复

```bash
# 测试MySQL连接
./deployment/scripts/test_mysql_connection.sh

# 查看应用日志
docker logs mrdocs-safe-app -f

# 测试HTTP访问
curl http://localhost:8081
```

## 预期结果
- 应用日志显示"数据库连接成功!"
- 端口8081响应HTTP请求
- 可以访问MrDoc界面

## 访问信息
- MrDoc应用: http://your-server-ip:8081
- 管理员账户: admin / Admin@123456