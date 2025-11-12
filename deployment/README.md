# MrDoc 部署脚本

## 快速开始

### 1. 准备环境
```bash
cd /root/kt/mrdocs
chmod +x deployment/scripts/*.sh
```

### 2. 部署MrDoc
```bash
./deployment/scripts/deploy_safe_mrdoc.sh
```

### 3. 验证部署
```bash
./deployment/scripts/verify_mrdoc.sh
```

## 脚本说明

### deploy_safe_mrdoc.sh
主部署脚本，已修复所有问题：
- ✅ 使用MySQL 5.7（避免SSL问题）
- ✅ 使用Python检查数据库连接（替代mysqladmin）
- ✅ 正确的Nginx配置
- ✅ 自动创建所有必要的配置文件

### verify_mrdoc.sh
快速验证服务状态：
- 检查容器运行状态
- 检查端口监听
- 测试HTTP访问
- 显示访问信息

### clean_mrdoc.sh
清理所有容器和数据（重新部署前使用）

### ubuntu_prepare.sh
系统环境准备脚本（安装Docker等）

### deploy_without_git.sh
无Git环境部署脚本（手动上传源码时使用）

## 访问信息

部署成功后：
- **应用地址**: http://your-server-ip:8081
- **Nginx代理**: http://your-server-ip:8082
- **管理员账号**: admin / admin123456

## 端口配置

- MrDoc应用: 8081
- Nginx代理: 8082
- MySQL: 3307
- Redis: 6380

## 故障排查

如果部署失败：

1. **清理环境重新部署**
```bash
./deployment/scripts/clean_mrdoc.sh
./deployment/scripts/deploy_safe_mrdoc.sh
```

2. **查看日志**
```bash
docker logs mrdocs-safe-app
docker logs mrdocs-safe-mysql
docker logs mrdocs-safe-nginx
```

3. **手动进入容器调试**
```bash
docker exec -it mrdocs-safe-app bash
```

## 注意事项

- 脚本会自动检测端口冲突
- 支持使用外部MySQL/Redis服务
- 所有服务使用安全端口，避免与现有服务冲突