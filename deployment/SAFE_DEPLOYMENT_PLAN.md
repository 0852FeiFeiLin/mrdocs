# 🛡️ MrDoc 安全部署方案文档

> **方案 2：独立部署模式**
> 完全隔离的 Docker 容器栈，与现有服务零冲突

## 📋 方案概述

### 🎯 设计目标

-   ✅ **零冲突部署**：完全避免与现有 MySQL、Redis 服务冲突
-   ✅ **数据安全**：现有生产数据绝对不受影响
-   ✅ **独立管理**：MrDoc 服务可独立启停、维护
-   ✅ **便于迁移**：完整的容器化服务栈

### 🏗️ 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                     Ubuntu 服务器                           │
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────────────┐ │
│  │    现有服务栈        │    │      MrDoc 独立服务栈        │ │
│  │                    │    │                             │ │
│  │  ┌──────────────┐  │    │  ┌─────────────────────────┐ │ │
│  │  │ 本机MySQL    │  │    │  │ mrdoc-safe-app         │ │ │
│  │  │ 端口: 3306   │  │    │  │ 端口: 8081             │ │ │
│  │  │ 生产数据     │  │    │  └─────────────────────────┘ │ │
│  │  └──────────────┘  │    │                             │ │
│  │                    │    │  ┌─────────────────────────┐ │ │
│  │  ┌──────────────┐  │    │  │ mrdoc-safe-mysql       │ │ │
│  │  │ 本机Redis    │  │    │  │ 端口: 3307             │ │ │
│  │  │ 端口: 6379   │  │    │  │ 独立数据               │ │ │
│  │  │ 生产数据     │  │    │  └─────────────────────────┘ │ │
│  │  └──────────────┘  │    │                             │ │
│  │                    │    │  ┌─────────────────────────┐ │ │
│  │  ┌──────────────┐  │    │  │ mrdoc-safe-redis       │ │ │
│  │  │ 其他服务     │  │    │  │ 端口: 6380             │ │ │
│  │  │ ...          │  │    │  │ 数据库: 4号库           │ │ │
│  │  └──────────────┘  │    │  └─────────────────────────┘ │ │
│  │                    │    │                             │ │
│  └─────────────────────┘    │  ┌─────────────────────────┐ │ │
│                             │  │ mrdoc-safe-nginx       │ │ │
│                             │  │ 端口: 8082             │ │ │
│                             │  │ 反向代理               │ │ │
│                             │  └─────────────────────────┘ │ │
│                             └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔒 安全隔离保证

### 1. **端口隔离**

| 服务类型         | 现有端口 | MrDoc 独立端口 | 隔离状态    |
| ---------------- | -------- | -------------- | ----------- |
| **MySQL 数据库** | 3306     | **3307**       | ✅ 完全隔离 |
| **Redis 缓存**   | 6379     | **6380**       | ✅ 完全隔离 |
| **Web 应用**     | -        | **8081**       | ✅ 独立端口 |
| **Nginx 代理**   | 80       | **8082**       | ✅ 避免冲突 |

### 2. **容器隔离**

```yaml
# 独立容器命名，避免重名冲突
containers:
    - mrdoc-safe-app # MrDoc 主应用
    - mrdoc-safe-mysql # 独立 MySQL 容器
    - mrdoc-safe-redis # 独立 Redis 容器
    - mrdoc-safe-nginx # 独立 Nginx 代理
```

### 3. **网络隔离**

```yaml
# 独立Docker网络
networks:
    mrdoc-safe-network:
        driver: bridge
        ipam:
            config:
                - subnet: 172.31.0.0/16
                  gateway: 172.31.0.1
```

### 4. **数据隔离**

```yaml
# 独立数据卷
volumes:
    mrdoc_safe_mysql_data: # MrDoc MySQL 数据
    mrdoc_safe_redis_data: # MrDoc Redis 数据

# 现有数据完全不受影响
# /var/lib/mysql     - 现有MySQL数据（安全）
# /var/lib/redis     - 现有Redis数据（安全）
```

### 5. **Redis 数据库隔离**

```ini
# MrDoc 使用 Redis 第4号数据库
[redis]
host = mrdoc-safe-redis
port = 6379  # 容器内端口
db = 4       # 专用数据库编号
password = auto_generated_password
```

## 🚀 部署步骤

### 第 1 步：环境准备

```bash
# 1. 确保Docker环境就绪
docker --version
docker-compose --version

# 2. 检查现有服务状态（确认不受影响）
systemctl status mysql   # 现有MySQL状态
systemctl status redis   # 现有Redis状态
netstat -tulpn | grep -E "(3307|6380|8081|8082)"  # 端口检查
```

### 第 2 步：上传部署文件

```bash
# 在本地执行，上传到服务器
scp /Users/supen/mrdoc-source-deploy/deployment/scripts/deploy_safe_mrdoc.sh ff@你的服务器IP:~/
scp -r /Users/supen/mrdoc-source-deploy/deployment/ ff@你的服务器IP:~/
```

### 第 3 步：执行安全部署

```bash
# SSH登录到服务器
ssh ff@你的服务器IP

# 设置执行权限
chmod +x ~/deploy_safe_mrdoc.sh

# 运行安全部署脚本
./deploy_safe_mrdoc.sh
```

### 第 4 步：部署配置选择

#### 冲突检测阶段

```
🔍 检测服务冲突
================================
[INFO] 检查端口占用情况...
[INFO] 检查容器名冲突...
[INFO] 检查网络冲突...
✅ 未检测到冲突，可以安全部署
```

#### 服务选择阶段

```
🛡️ 外部服务配置
================================
是否使用外部MySQL服务? (y/N): N  ⬅️ 选择N，使用独立MySQL
是否使用外部Redis服务? (y/N): N  ⬅️ 选择N，使用独立Redis
```

#### 配置确认阶段

```
最终部署配置
================================
✅ 仓库地址: https://github.com/0852FeiFeiLin/mrdocs.git
✅ 分支: master
✅ 项目名称: mrdocs-safe
✅ 项目目录: /home/ff/mrdocs-safe
✅ 访问域名: localhost

端口配置：
  📱 MrDoc应用: 8081
  🗄️  MySQL: 3307 (独立容器)
  ⚡ Redis: 6380 (独立容器)
  🌐 Nginx: 8082

确认以上配置开始部署? (y/N): y  ⬅️ 确认部署
```

### 第 5 步：验证部署结果

```bash
# 检查容器状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 应该看到4个运行中的容器：
# mrdoc-safe-app     Up    0.0.0.0:8081->8000/tcp
# mrdoc-safe-mysql   Up    0.0.0.0:3307->3306/tcp
# mrdoc-safe-redis   Up    0.0.0.0:6380->6379/tcp
# mrdoc-safe-nginx   Up    0.0.0.0:8082->80/tcp

# 验证现有服务状态（应该不受影响）
systemctl status mysql redis
```

## 🎯 访问信息

### 🌐 Web 访问

```bash
# MrDoc 主应用（直接访问）
URL: http://你的服务器IP:8081
管理后台: http://你的服务器IP:8081/admin

# MrDoc 代理访问（通过Nginx）
URL: http://你的服务器IP:8082
管理后台: http://你的服务器IP:8082/admin

# 默认管理员账户
用户名: admin
密码: admin123456
```

### 🗄️ 数据库访问

```bash
# MrDoc MySQL（独立）
主机: 你的服务器IP
端口: 3307
数据库: mrdoc
用户名: mrdoc
密码: 自动生成（在.env文件中）

# MrDoc Redis（独立）
主机: 你的服务器IP
端口: 6380
数据库: 4号库
密码: 自动生成（在.env文件中）
```

## 🛠️ 管理维护

### 启动服务

```bash
cd ~/mrdocs-safe
docker-compose up -d

# 或使用管理脚本
./start.sh
```

### 停止服务

```bash
cd ~/mrdocs-safe
docker-compose down

# 或使用管理脚本
./stop.sh
```

### 重启服务

```bash
cd ~/mrdocs-safe
docker-compose restart

# 或使用管理脚本
./restart.sh
```

### 查看日志

```bash
cd ~/mrdocs-safe
docker-compose logs -f

# 或使用管理脚本
./logs.sh
```

### 查看服务状态

```bash
cd ~/mrdocs-safe
docker-compose ps

# 或使用管理脚本
./status.sh
```

### 数据备份

```bash
cd ~/mrdocs-safe

# 备份MySQL数据
./backup.sh

# 手动备份
docker-compose exec -T mrdoc-safe-mysql mysqldump -uroot -p mrdoc > backup_$(date +%Y%m%d).sql
```

## 🔄 维护操作

### 更新源码

```bash
cd ~/mrdocs-safe

# 拉取最新代码
git pull origin master

# 重建镜像
docker-compose build --no-cache mrdoc-safe-app

# 重启应用
docker-compose up -d mrdoc-safe-app
```

### 数据库操作

```bash
# 进入MySQL容器
docker-compose exec mrdoc-safe-mysql mysql -uroot -p

# 进入Redis容器
docker-compose exec mrdoc-safe-redis redis-cli

# 数据库迁移
docker-compose exec mrdoc-safe-app python manage.py migrate

# 创建超级用户
docker-compose exec mrdoc-safe-app python manage.py createsuperuser

# 收集静态文件
docker-compose exec mrdoc-safe-app python manage.py collectstatic --noinput
```

## 🚨 故障排除

### 常见问题

#### 1. 容器启动失败

```bash
# 查看容器日志
docker-compose logs mrdoc-safe-app

# 检查端口占用
netstat -tulpn | grep -E "(8081|3307|6380|8082)"

# 重新构建
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

#### 2. 数据库连接失败

```bash
# 检查MySQL容器状态
docker-compose logs mrdoc-safe-mysql

# 重置数据库
docker-compose down
docker volume rm mrdoc_safe_mysql_data
docker-compose up -d
```

#### 3. Redis 连接失败

```bash
# 检查Redis容器状态
docker-compose logs mrdoc-safe-redis

# 测试Redis连接
docker-compose exec mrdoc-safe-redis redis-cli ping
```

#### 4. 访问权限问题

```bash
# 检查文件权限
ls -la ~/mrdocs-safe/

# 修复权限
chmod -R 755 ~/mrdocs-safe/
chown -R $USER:$USER ~/mrdocs-safe/
```

### 完全卸载

```bash
# 如果需要完全删除MrDoc服务
cd ~/mrdocs-safe

# 停止并删除所有容器和数据
docker-compose down -v --remove-orphans

# 删除相关镜像
docker rmi $(docker images | grep mrdoc-safe | awk '{print $3}')

# 删除项目目录
cd ~
rm -rf mrdocs-safe

# 验证现有服务状态（应该完全不受影响）
systemctl status mysql redis
```

## ✅ 安全保证确认

### 现有服务保护

-   ✅ **现有 MySQL (3306 端口)** - 完全不受影响，继续正常运行
-   ✅ **现有 Redis (6379 端口)** - 完全不受影响，数据安全
-   ✅ **现有 Web 服务** - 不会有端口冲突
-   ✅ **现有数据** - 绝对安全，零风险

### 独立服务验证

```bash
# 验证服务独立性
echo "=== 现有服务状态 ==="
systemctl status mysql redis

echo "=== MrDoc独立服务状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}"

echo "=== 端口使用情况 ==="
netstat -tulpn | grep -E "(3306|3307|6379|6380|8081|8082)"
```

## 📞 技术支持

### 重要提醒

1. **数据安全第一** - 现有生产数据绝对不会受到影响
2. **服务隔离** - MrDoc 服务完全独立，可随时停止
3. **端口独立** - 使用不同端口，避免一切冲突
4. **容器化管理** - 便于维护、备份和迁移

### 联系支持

如有任何问题，请保存好：

-   部署日志
-   容器状态：`docker ps -a`
-   错误信息：`docker-compose logs`

---

🎉 **MrDoc 安全部署方案 - 方案 2：独立部署模式**

**零冲突 | 数据安全 | 独立管理 | 便于维护**
