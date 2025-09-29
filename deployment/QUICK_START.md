# ⚡ MrDoc 快速开始指南

## 🎯 选择你的部署方案

### 🛠️ 方案1：二次开发部署（推荐给你）

适合正在做二次开发的用户：

```bash
cd mrdoc-source-deploy/deployment/scripts/
./deploy_custom_mrdoc.sh
```

**特点：**
- ✅ 专为你的源码仓库 `https://github.com/0852FeiFeiLin/mrdocs.git` 优化
- ✅ 自动处理空仓库情况
- ✅ 开发环境友好（热重载、端口暴露）
- ✅ 包含开发工具脚本

### 🏭 方案2：生产环境部署

适合部署到生产服务器：

```bash
cd mrdoc-source-deploy/deployment/scripts/
./ubuntu_prepare.sh    # 首次需要准备环境
./deploy_mrdoc.sh      # 部署生产环境
```

## 📋 部署后你将得到什么

### 🐳 容器化服务
- **MrDoc 应用**：Django + Gunicorn
- **MySQL 数据库**：数据持久化存储
- **Redis 缓存**：性能优化
- **Nginx 代理**：静态文件服务（生产环境）

### 🛠️ 开发工具（二次开发版）
- `dev_start.sh` - 启动开发环境
- `dev_restart.sh` - 快速重启
- `sync_code.sh` - 同步代码到GitHub
- `db_manage.sh` - 数据库管理
- `logs.sh` - 日志查看

### 📊 访问端口
**开发环境：**
- MrDoc：http://server:8000
- MySQL：server:3306（用户：mrdoc，密码：mrdoc123456）
- Redis：server:6379（密码：redis123456）

**生产环境：**
- MrDoc：http://server（通过Nginx）
- 管理后台：http://server/admin

## 🚀 立即开始

### 如果你的仓库是空的（推荐流程）

```bash
# 1. 运行二次开发部署脚本
./deploy_custom_mrdoc.sh

# 2. 选择"使用原版MrDoc作为基础"
# 3. 等待部署完成
# 4. 访问 http://your-server:8000
# 5. 开始进行定制化开发
# 6. 使用 ./sync_code.sh 提交到你的仓库
```

### 如果你已有自定义代码

```bash
# 1. 确保代码已推送到你的仓库
# 2. 运行部署脚本
./deploy_custom_mrdoc.sh

# 3. 确认使用你的仓库地址
# 4. 等待部署完成
```

## 📚 详细文档

- **完整部署指南**：[README.md](./README.md)
- **二次开发指南**：[CUSTOM_DEV_GUIDE.md](./CUSTOM_DEV_GUIDE.md)

## 💡 提示

1. **首次部署**建议选择二次开发方案，更灵活
2. **生产部署**时再使用生产环境脚本
3. 遇到问题查看对应的详细文档
4. 开发工具脚本让你的开发更高效

---

🎉 **选择适合的方案，开始你的 MrDoc 之旅吧！**