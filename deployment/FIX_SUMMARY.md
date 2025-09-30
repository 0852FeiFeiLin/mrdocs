# MrDoc部署问题修复总结

## 修复的问题

### 1. Nginx上游配置错误 ✅
**问题**: Nginx配置中的upstream引用了错误的容器名称`mrdoc:8000`
**解决**: 修改为正确的容器名称`mrdocs-safe-app:8000`
- 文件: `deployment/nginx/nginx.conf`
- 修改内容: 第73行，将`server mrdoc:8000`改为`server mrdocs-safe-app:8000`

### 2. MySQL认证问题 ✅
**问题**: 应用容器无法连接MySQL，显示认证失败
**解决方案**:
- 禁用SSL连接要求
- 使用mysql_native_password认证插件
- 添加MySQL初始化脚本
- 更新entrypoint.sh脚本以更好地处理数据库连接

### 3. 创建的修复脚本

#### fix_mysql_auth.sh
位置: `deployment/scripts/fix_mysql_auth.sh`
功能:
- 停止并清理现有容器
- 创建MySQL初始化脚本
- 更新docker-compose配置
- 重新启动所有服务

#### verify_services.sh
位置: `deployment/scripts/verify_services.sh`
功能:
- 检查所有容器运行状态
- 测试数据库连接
- 验证端口监听
- 检查错误日志
- 显示访问信息

## 如何应用这些修复

在您的服务器上执行以下步骤：

### 1. 上传修改后的文件

将以下文件上传到服务器对应位置：
```bash
# Nginx配置
/root/kt/mrdocs/deployment/nginx/nginx.conf

# 修复脚本
/root/kt/mrdocs/deployment/scripts/fix_mysql_auth.sh
/root/kt/mrdocs/deployment/scripts/verify_services.sh
```

### 2. 执行修复脚本

```bash
cd /root/kt/mrdocs
chmod +x deployment/scripts/fix_mysql_auth.sh
chmod +x deployment/scripts/verify_services.sh

# 执行修复
./deployment/scripts/fix_mysql_auth.sh
```

### 3. 验证服务状态

```bash
# 等待服务完全启动后执行
./deployment/scripts/verify_services.sh
```

## 更新的配置

### Docker Compose配置更新
- MySQL添加了`--skip-ssl`和`--default-authentication-plugin=mysql_native_password`
- 添加了MySQL初始化脚本挂载
- 更新了健康检查命令

### Entrypoint脚本更新
- 添加了`--protocol=tcp`参数确保TCP连接
- 改进了错误处理和日志输出
- 修复了worker-class从gevent改为sync

## 访问信息

成功部署后，您可以通过以下地址访问：

- **MrDoc应用**: http://your-server-ip:8081
- **Nginx代理**: http://your-server-ip:8082
- **管理员账户**: admin / Admin@123456

## 数据库连接信息

- **MySQL**
  - 主机: mrdocs-safe-mysql (容器内) / localhost:3307 (宿主机)
  - 用户: mrdoc
  - 密码: mrdocpassword123
  - 数据库: mrdoc

- **Redis**
  - 主机: mrdocs-safe-redis (容器内) / localhost:6380 (宿主机)
  - 密码: redispassword123
  - 数据库: 4

## 注意事项

1. **数据清理**: `fix_mysql_auth.sh`脚本会清理MySQL数据卷，执行前请确认是否需要备份数据
2. **端口占用**: 确保端口8081, 8082, 3307, 6380未被其他服务占用
3. **防火墙**: 如需外网访问，请开放相应端口
4. **日志监控**: 可以使用`docker logs -f 容器名`实时查看日志

## 故障排查

如果服务仍有问题，请检查：

1. 查看容器日志：
```bash
docker logs mrdocs-safe-app
docker logs mrdocs-safe-mysql
docker logs mrdocs-safe-nginx
```

2. 进入容器调试：
```bash
docker exec -it mrdocs-safe-app bash
docker exec -it mrdocs-safe-mysql mysql -uroot -prootpassword123
```

3. 检查网络连通性：
```bash
docker exec mrdocs-safe-app ping mrdocs-safe-mysql
docker exec mrdocs-safe-app nc -zv mrdocs-safe-mysql 3306
```