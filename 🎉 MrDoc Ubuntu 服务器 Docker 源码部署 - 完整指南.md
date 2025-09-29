# 🎉 MrDoc Ubuntu 服务器 Docker 源码部署 - 完整指南

  📋 部署方案总览

  我为你提供了完整的 MrDoc Ubuntu 服务器源码部署方案：

  ✅ 基于源码的 Docker 部署✅ 使用 MySQL 数据库✅ 包含 Redis 缓存✅ Nginx 反向代理✅ 完整的生产环境配置

---
  🚀 快速部署步骤

  第1步：准备服务器环境

  # 下载并运行环境准备脚本
  wget -O ubuntu_prepare.sh https://your-files-url/ubuntu_prepare.sh
  chmod +x ubuntu_prepare.sh
  ./ubuntu_prepare.sh

  # 重新登录以应用Docker组权限
  logout
  # 重新SSH登录服务器

  第2步：一键部署MrDoc

  # 下载并运行部署脚本
  wget -O deploy_mrdoc.sh https://your-files-url/deploy_mrdoc.sh
  chmod +x deploy_mrdoc.sh
  ./deploy_mrdoc.sh

  # 根据提示输入域名（可直接回车使用默认值）

  第3步：访问系统

  # 部署完成后访问
  http://你的服务器IP

  # 默认管理员账户
  用户名: admin
  密码: admin123456

---
  📂 项目文件结构

  ~/mrdoc-server/
  ├── config/                 # MrDoc配置文件
  │   └── config.ini
  ├── data/                   # 数据持久化目录
  │   ├── mysql/             # MySQL数据
  │   └── redis/             # Redis数据
  ├── logs/                   # 日志文件
  │   ├── nginx/             # Nginx日志
  │   └── mrdoc/             # 应用日志
  ├── media/                  # 媒体文件
  ├── static/                 # 静态文件
  ├── nginx/                  # Nginx配置
  │   ├── nginx.conf
  │   ├── conf.d/
  │   └── ssl/               # SSL证书目录
  ├── mysql/                  # MySQL配置
  │   └── conf.d/
  ├── redis/                  # Redis配置
  ├── source/                 # MrDoc源码
  ├── backup/                 # 备份目录
  ├── docker-compose.yml      # Docker编排文件
  ├── Dockerfile             # Docker镜像构建文件
  ├── .env                   # 环境变量配置
  ├── start.sh               # 启动脚本
  ├── stop.sh                # 停止脚本
  ├── restart.sh             # 重启脚本
  ├── backup.sh              # 备份脚本
  └── logs.sh                # 日志查看脚本

---
  🔧 日常管理命令

  # 进入项目目录
  cd ~/mrdoc-server

  # 启动所有服务
  ./start.sh

  # 停止所有服务
  ./stop.sh

  # 重启所有服务
  ./restart.sh

  # 数据备份
  ./backup.sh

  # 查看服务状态
  docker-compose ps

  # 查看日志
  ./logs.sh

  # 进入容器
  docker-compose exec mrdoc bash
  docker-compose exec mysql mysql -uroot -p

---
  🗂️ 核心配置文件说明

  1. MrDoc配置 (config/config.ini)

  - 数据库连接配置
  - Redis缓存配置
  - 邮箱服务配置
  - 功能开关配置

  2. Docker配置 (docker-compose.yml)

  - 服务编排定义
  - 容器依赖关系
  - 端口映射配置
  - 数据卷挂载

  3. Nginx配置 (nginx/)

  - 反向代理设置
  - 静态文件服务
  - SSL配置模板
  - 安全头设置

  4. 数据库配置 (mysql/conf.d/)

  - MySQL性能优化
  - 字符集设置
  - 连接池配置

---
  🔐 安全配置建议

  防火墙设置

  # 基本端口开放
  sudo ufw allow ssh
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw enable

  SSL证书配置

  # 使用Let's Encrypt申请免费SSL证书
  sudo certbot --nginx -d your-domain.com

  # 证书自动续期
  echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

  数据库安全

  # 修改默认密码（在.env文件中）
  # 限制数据库外部访问
  # 定期备份数据

---
  📊 系统要求

  | 组件  | 最小配置          | 推荐配置          |
  |-----|---------------|---------------|
  | CPU | 2核            | 4核+           |
  | 内存  | 4GB           | 8GB+          |
  | 磁盘  | 20GB          | 100GB+        |
  | 系统  | Ubuntu 20.04+ | Ubuntu 22.04+ |

---
  🔄 升级和维护

  源码更新

  cd ~/mrdoc-server/source
  git pull origin main
  cd ..
  docker-compose build --no-cache mrdoc
  docker-compose up -d

  定期备份

  # 添加到crontab定期备份
  echo "0 2 * * * /home/$(whoami)/mrdoc-server/backup.sh" | crontab -

  日志清理

  # 清理旧日志文件
  find ~/mrdoc-server/logs -name "*.log" -mtime +30 -delete

---
  🆘 常见问题解决

  服务启动失败

  # 检查端口占用
  sudo netstat -tlnp | grep :80

  # 查看容器日志
  docker-compose logs mrdoc

  # 重新构建
  docker-compose down
  docker-compose build --no-cache
  docker-compose up -d

  数据库连接失败

  # 检查MySQL服务
  docker-compose logs mysql

  # 重置数据库
  docker-compose down
  sudo rm -rf data/mysql
  docker-compose up -d

  静态文件404

  # 重新收集静态文件
  docker-compose exec mrdoc python manage.py collectstatic --noinput
  docker-compose restart nginx

---
  ✨ 特色功能

  🔹 源码可修改 - 完全基于源码部署，可自由定制🔹 生产环境优化 - 使用Gunicorn + Nginx，性能优异🔹 数据持久化 - MySQL + Redis 双重数据保护🔹 自动化管理 - 一键启停、备份、日志查看🔹 安全加固 -
  完整的安全配置和访问控制🔹 扩展性强 - 支持负载均衡和集群部署

  现在你可以开始在Ubuntu服务器上部署你的企业级MrDoc知识库系统了！🚀