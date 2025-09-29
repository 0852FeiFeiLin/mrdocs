# 🚀 MrDoc Ubuntu 服务器 Docker 源码部署指南

> 基于源码的 Docker 部署方案，使用 MySQL 数据库

## 📋 部署概览

本部署方案提供了完整的 MrDoc 企业级部署解决方案：

- ✅ **源码部署** - 基于 MrDoc 源码构建，可自由修改
- ✅ **Docker 容器化** - 使用 Docker Compose 编排服务
- ✅ **MySQL 数据库** - 生产级数据库支持
- ✅ **Redis 缓存** - 提升系统性能
- ✅ **Nginx 反向代理** - 静态文件服务和负载均衡
- ✅ **自动化部署** - 一键部署和管理脚本

## 🗂️ 文件结构说明

```
deployment/
├── scripts/                    # 部署脚本
│   ├── ubuntu_prepare.sh       # Ubuntu 环境准备脚本
│   └── deploy_mrdoc.sh        # MrDoc 一键部署脚本
├── docker/                     # Docker 相关文件
│   ├── Dockerfile.mrdoc       # MrDoc 镜像构建文件
│   ├── docker-compose.yml     # 服务编排配置
│   └── entrypoint.sh          # 容器启动脚本
├── config/                     # 配置文件模板
│   ├── config.ini             # MrDoc 主配置
│   ├── my.cnf                 # MySQL 配置
│   └── redis.conf             # Redis 配置
├── nginx/                      # Nginx 配置
│   ├── nginx.conf             # Nginx 主配置
│   └── mrdoc.conf             # MrDoc 站点配置
└── README.md                   # 本文档
```

## 🚀 部署方案选择

### 📋 **方案A：二次开发版本部署（推荐）**

如果你正在进行 MrDoc 二次开发或想要使用自定义源码：

```bash
# 使用二次开发专用脚本
cd /path/to/mrdoc-source-deploy/deployment/scripts/
./deploy_custom_mrdoc.sh
```

**特点：**
- ✅ 支持自定义源码仓库
- ✅ 开发环境友好（热重载、端口暴露）
- ✅ 自动处理空仓库情况
- ✅ 提供开发工具脚本
- ✅ 支持从本地项目导入

### 📋 **方案B：标准生产部署**

如果你要部署稳定的生产环境：

### 第1步：准备 Ubuntu 服务器环境

```bash
# 在你的 Ubuntu 服务器上运行
cd /path/to/mrdoc-source-deploy/deployment/scripts/

# 运行环境准备脚本
./ubuntu_prepare.sh

# 重新登录以应用 Docker 组权限
logout
# 重新 SSH 登录服务器
```

### 第2步：一键部署 MrDoc

```bash
# 运行部署脚本
cd /path/to/mrdoc-source-deploy/deployment/scripts/
./deploy_mrdoc.sh

# 根据提示输入域名（或直接回车使用默认值）
# 脚本会自动：
# - 下载 MrDoc 源码
# - 生成配置文件
# - 构建 Docker 镜像
# - 启动所有服务
```

### 第3步：访问系统

```bash
# 访问地址
http://你的服务器IP

# 默认管理员账户
用户名: admin
密码: admin123456
```

## 🔧 手动部署（高级用户）

如果你想自定义部署过程，可以按以下步骤手动部署：

### 1. 准备项目目录

```bash
# 在服务器上创建项目目录
mkdir -p ~/mrdoc-server
cd ~/mrdoc-server

# 复制部署文件
cp -r /path/to/mrdoc-source-deploy/deployment/* ./
```

### 2. 修改配置文件

根据你的需求修改以下配置：

- `config/config.ini` - MrDoc 主要配置
- `docker/docker-compose.yml` - 服务编排配置
- `nginx/mrdoc.conf` - Nginx 站点配置

### 3. 下载源码并构建

```bash
# 下载 MrDoc 源码
git clone https://github.com/zmister2016/MrDoc.git source

# 复制源码到构建目录
cp -r source/* ./

# 重命名 Dockerfile
mv docker/Dockerfile.mrdoc ./Dockerfile

# 复制启动脚本
cp docker/entrypoint.sh ./docker/
chmod +x docker/entrypoint.sh
```

### 4. 启动服务

```bash
# 构建并启动服务
docker-compose -f docker/docker-compose.yml build
docker-compose -f docker/docker-compose.yml up -d

# 查看服务状态
docker-compose -f docker/docker-compose.yml ps
```

## 📊 系统要求

| 组件 | 最小配置 | 推荐配置 |
|------|----------|----------|
| **操作系统** | Ubuntu 20.04+ | Ubuntu 22.04+ |
| **CPU** | 2 核 | 4 核+ |
| **内存** | 4GB | 8GB+ |
| **磁盘** | 20GB | 100GB+ |
| **网络** | 10Mbps | 100Mbps+ |

## 🔧 配置文件详解

### MrDoc 配置 (`config/config.ini`)

主要配置项：

```ini
[site]
debug = False                    # 生产环境设为 False
sitename = 企业知识库系统        # 站点名称

[database]
engine = mysql                   # 数据库类型
name = mrdoc                     # 数据库名
user = mrdoc                     # 数据库用户
password = your-password         # 数据库密码
host = mysql                     # 数据库主机
port = 3306                      # 数据库端口

[redis]
host = redis                     # Redis 主机
port = 6379                      # Redis 端口
password = your-redis-password   # Redis 密码

[email]
email_backend = smtp             # 邮件后端
email_host = smtp.gmail.com      # SMTP 服务器
email_port = 587                 # SMTP 端口
```

### Docker Compose 配置

主要服务：

- **mrdoc** - MrDoc 主应用
- **mysql** - MySQL 数据库
- **redis** - Redis 缓存
- **nginx** - Nginx 反向代理

### Nginx 配置

- 静态文件服务
- 反向代理配置
- SSL 支持（需要证书）
- 访问控制和安全头

## 🛡️ 安全配置

### 防火墙设置

```bash
# 开启基本端口
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### SSL 证书配置

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 申请免费 SSL 证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 数据库安全

1. 修改默认密码
2. 限制外部访问
3. 定期备份数据
4. 启用慢查询日志

## 📋 管理命令

部署完成后，项目目录中会生成以下管理脚本：

```bash
# 启动所有服务
./start.sh

# 停止所有服务
./stop.sh

# 重启所有服务
./restart.sh

# 数据备份
./backup.sh

# 查看日志
./logs.sh

# 查看服务状态
docker-compose ps
```

## 🔄 维护操作

### 源码更新

```bash
cd ~/mrdoc-server/source
git pull origin main
cd ..
docker-compose build --no-cache mrdoc
docker-compose up -d mrdoc
```

### 数据库备份

```bash
# 手动备份
docker-compose exec mysql mysqldump -uroot -p mrdoc > backup_$(date +%Y%m%d).sql

# 设置定期备份
echo "0 2 * * * /home/$(whoami)/mrdoc-server/backup.sh" | crontab -
```

### 日志管理

```bash
# 查看应用日志
docker-compose logs -f mrdoc

# 清理旧日志
find ~/mrdoc-server/logs -name "*.log" -mtime +30 -delete
```

## 🆘 故障排除

### 常见问题

#### 1. 服务启动失败

```bash
# 检查端口占用
sudo netstat -tlnp | grep :80

# 查看详细日志
docker-compose logs mrdoc

# 重新构建
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

#### 2. 数据库连接失败

```bash
# 检查 MySQL 状态
docker-compose logs mysql

# 进入 MySQL 容器
docker-compose exec mysql mysql -uroot -p

# 重置数据库（危险操作！）
docker-compose down
sudo rm -rf data/mysql
docker-compose up -d
```

#### 3. 静态文件 404

```bash
# 重新收集静态文件
docker-compose exec mrdoc python manage.py collectstatic --noinput

# 检查文件权限
ls -la static/

# 重启 Nginx
docker-compose restart nginx
```

#### 4. 内存不足

```bash
# 查看系统资源使用
free -h
df -h

# 查看容器资源使用
docker stats

# 优化 MySQL 内存配置
# 编辑 config/my.cnf 中的 innodb_buffer_pool_size
```

## 📞 技术支持

### 官方资源

- **MrDoc 官方文档**: https://doc.mrdoc.fun/
- **GitHub 仓库**: https://github.com/zmister2016/MrDoc
- **问题反馈**: https://github.com/zmister2016/MrDoc/issues

### 社区支持

- **QQ 群**: 735507293
- **微信群**: 扫描官网二维码

## 📝 更新日志

### v1.0.0 (2024-09-29)
- ✅ 初始版本发布
- ✅ 支持 Ubuntu 20.04+
- ✅ Docker + MySQL + Redis 完整方案
- ✅ 自动化部署脚本
- ✅ Nginx 反向代理配置
- ✅ 生产环境优化

---

🎉 **现在你可以开始部署你的企业级 MrDoc 知识库系统了！**

如有问题，请参考故障排除部分或联系技术支持。