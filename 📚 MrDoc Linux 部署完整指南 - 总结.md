# 📚 MrDoc Linux 部署完整指南 - 总结

  🎯 部署方案概览

  我为你准备了两套完整的 MrDoc Linux 部署方案：

  🚀 方案一：Docker 一键部署（推荐）

  - ✅ 最简单：一条命令完成部署
  - ✅ 最稳定：容器化隔离环境
  - ✅ 易维护：标准化运维流程

  🔧 方案二：手动源码部署

  - ✅ 更灵活：可自定义更多配置
  - ✅ 更轻量：直接运行无容器开销
  - ✅ 更可控：完全掌握每个组件

  📋 已提供的文件清单

  核心部署文件

  1. install_docker.sh - Docker环境安装脚本
  2. deploy_mrdoc.sh - 一键部署脚本（推荐）
  3. docker-compose-mrdoc.yml - Docker编排配置
  4. config.ini - MrDoc主配置文件
  5. nginx.conf - Nginx反向代理配置
  6. manual_install.sh - 手动源码部署脚本

  运维管理文档

  7. maintenance_guide.md - 完整运维指南

  ⚡ 快速开始命令

  # 一键部署（最推荐）
  curl -fsSL -o deploy_mrdoc.sh https://raw.githubusercontent.com/your-files/deploy_mrdoc.sh
  chmod +x deploy_mrdoc.sh && ./deploy_mrdoc.sh

  🎛️ 关键配置说明

  端口配置

  - MrDoc服务：10086
  - MySQL：3306（可选）
  - Redis：6379
  - Nginx：80/443

  默认路径

  - 项目目录：~/mrdoc-deploy
  - 数据库：~/mrdoc-deploy/db/db.sqlite3
  - 媒体文件：~/mrdoc-deploy/media/
  - 配置文件：~/mrdoc-deploy/config/config.ini

  管理命令

  cd ~/mrdoc-deploy

  # 启动服务
  ./start.sh

  # 停止服务  
  ./stop.sh

  # 备份数据
  ./backup.sh

  # 查看状态
  docker-compose ps

  # 查看日志
  docker-compose logs -f mrdoc

  🔒 生产环境注意事项

  安全配置

  1. 修改默认密码：Redis、数据库密码
  2. 配置防火墙：限制端口访问
  3. 启用HTTPS：配置SSL证书
  4. 访问控制：限制管理界面访问

  性能优化

  1. 资源配置：建议≥2GB内存，≥10GB磁盘
  2. 缓存优化：Redis缓存配置
  3. 文件限制：上传大小限制100MB
  4. 备份策略：每日自动备份

  📊 系统要求

  | 组件  | 最小配置                 | 推荐配置                 |
  |-----|----------------------|----------------------|
  | CPU | 1核                   | 2核+                  |
  | 内存  | 2GB                  | 4GB+                 |
  | 磁盘  | 10GB                 | 50GB+                |
  | 系统  | Ubuntu 18+/CentOS 7+ | Ubuntu 22+/CentOS 8+ |

  🆘 获取支持

  遇到问题时：

  1. 查看日志：docker-compose logs mrdoc
  2. 检查状态：docker-compose ps
  3. 重启服务：docker-compose restart mrdoc
  4. 参考运维指南：详细故障排除步骤

  技术支持渠道：

  - 📖 官方文档：https://doc.mrdoc.fun/
  - 💬 GitHub Issues
  - 👥 QQ群：735507293

---
  ✨ 立即开始部署

  现在你有了完整的 MrDoc Linux 部署方案。建议按以下顺序执行：

  1. 下载部署脚本
  2. 执行一键部署
  3. 配置域名和SSL
  4. 设置定期备份
  5. 根据运维指南进行日常管理

  准备好开始部署了吗？需要我协助你执行部署的任何步骤！