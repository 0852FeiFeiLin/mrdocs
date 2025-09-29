# 🛠️ MrDoc 二次开发部署指南

> 专为 MrDoc 二次开发者设计的快速部署方案

## 🎯 适用场景

- ✅ 正在进行 MrDoc 二次开发
- ✅ 使用自定义源码仓库
- ✅ 需要开发环境友好的配置
- ✅ 想要快速原型开发和测试

## 🚀 一键部署

```bash
# 使用二次开发专用脚本
cd /path/to/mrdoc-source-deploy/deployment/scripts/
./deploy_custom_mrdoc.sh
```

## 📋 部署流程详解

### 1. 脚本会自动检测你的仓库状态

**情况A：仓库为空或缺少文件**
- 选项1：使用原版 MrDoc 作为基础（推荐）
- 选项2：从本地现有项目复制
- 选项3：创建基础项目结构
- 选项4：取消部署

**情况B：仓库包含完整项目**
- 直接克隆并部署

### 2. 配置部署参数

脚本会询问：
- 源码仓库地址（默认：你的仓库）
- 分支名称（默认：main）
- 项目名称（默认：mrdocs-custom）
- 域名配置

### 3. 自动创建开发环境

- 🐳 Docker Compose 配置（开发模式）
- 🔧 开发工具脚本
- 📊 数据库和缓存（端口暴露）
- 🔄 源码热重载支持

## 🛠️ 开发工具脚本

部署完成后，你将获得以下开发工具：

### `./dev_start.sh` - 启动开发环境
```bash
./dev_start.sh
# 启动数据库 → 等待启动 → 启动应用（交互模式）
```

### `./dev_restart.sh` - 快速重启应用
```bash
./dev_restart.sh
# 快速重启 MrDoc 应用服务
```

### `./sync_code.sh` - 同步代码到仓库
```bash
./sync_code.sh
# 添加文件 → 提交 → 推送到远程仓库
```

### `./db_manage.sh` - 数据库管理
```bash
./db_manage.sh
# 1) 进入MySQL命令行
# 2) 导出数据库
# 3) 导入数据库
# 4) 重置数据库
```

### `./logs.sh` - 日志查看
```bash
./logs.sh
# 选择查看不同服务的日志
```

## 🔧 开发环境特点

### Docker 配置优化
```yaml
# 开发友好的配置
mrdoc:
  ports:
    - "8000:8000"        # 直接暴露端口
  volumes:
    - ./:/app/source     # 源码目录挂载，支持热重载
  environment:
    - DJANGO_DEBUG=True  # 开发模式
  command: python manage.py runserver 0.0.0.0:8000  # 开发服务器
```

### 端口暴露
- **应用端口**：8000（开发服务器）
- **MySQL**：3306（方便数据库管理工具连接）
- **Redis**：6379（方便调试缓存）

### 默认账户信息
- **MySQL**：mrdoc/mrdoc123456
- **Redis**：密码 redis123456

## 📝 开发工作流

### 1. 初次部署
```bash
# 运行部署脚本
./deploy_custom_mrdoc.sh

# 选择"使用原版MrDoc作为基础"（如果仓库为空）
# 等待部署完成
```

### 2. 开始开发
```bash
# 进入项目目录
cd ~/mrdocs-custom

# 修改源码文件
vim app_doc/views.py

# 实时查看效果（热重载）
# 访问 http://your-server:8000
```

### 3. 提交更改
```bash
# 同步代码到你的仓库
./sync_code.sh

# 输入提交信息
# 代码自动推送到 GitHub
```

### 4. 数据库操作
```bash
# 数据库迁移
docker-compose exec mrdoc python manage.py makemigrations
docker-compose exec mrdoc python manage.py migrate

# 创建超级用户
docker-compose exec mrdoc python manage.py createsuperuser

# 或使用管理脚本
./db_manage.sh
```

## 🔄 从原版 MrDoc 开始开发

如果你的仓库是空的，建议选择"使用原版 MrDoc 作为基础"：

### 优势
1. **完整功能**：获得 MrDoc 的全部功能
2. **稳定基础**：基于经过测试的代码
3. **渐进开发**：可以逐步进行定制化修改
4. **文档齐全**：有完整的开发文档支持

### 操作流程
1. 脚本下载原版 MrDoc 源码
2. 设置你的仓库为远程地址
3. 你可以开始进行定制化开发
4. 使用 `sync_code.sh` 提交到你的仓库

## 🎨 自定义开发建议

### 目录结构
```
mrdocs-custom/
├── app_admin/          # 管理功能（可自定义）
├── app_doc/            # 文档功能（主要开发区域）
├── app_api/            # API接口（可扩展）
├── template/           # 前端模板（UI定制）
├── static/             # 静态文件（样式、脚本）
├── config/             # 配置文件
└── requirements.txt    # 依赖管理
```

### 常见定制点
1. **UI界面**：修改 `template/` 目录下的模板
2. **功能扩展**：在 `app_doc/` 中添加新功能
3. **API定制**：扩展 `app_api/` 接口
4. **权限控制**：自定义 `app_admin/` 权限逻辑

### 开发最佳实践
1. **分支管理**：使用 git 分支管理功能开发
2. **配置分离**：环境配置和代码分离
3. **文档更新**：及时更新自定义功能文档
4. **测试验证**：充分测试定制功能

## 🐛 故障排除

### 源码相关问题

#### 1. 仓库克隆失败
```bash
# 检查仓库地址
git ls-remote https://github.com/0852FeiFeiLin/mrdocs.git

# 检查网络连接
ping github.com

# 尝试使用SSH地址
git@github.com:0852FeiFeiLin/mrdocs.git
```

#### 2. 项目文件缺失
```bash
# 手动添加基础文件
touch manage.py requirements.txt

# 或重新选择"使用原版MrDoc作为基础"
./deploy_custom_mrdoc.sh
```

#### 3. 依赖安装失败
```bash
# 查看构建日志
docker-compose logs mrdoc

# 手动进入容器安装
docker-compose exec mrdoc pip install package_name
```

### 开发环境问题

#### 1. 热重载不生效
```bash
# 检查源码挂载
docker-compose exec mrdoc ls -la /app/source

# 重启开发服务器
./dev_restart.sh
```

#### 2. 数据库连接失败
```bash
# 检查数据库状态
docker-compose ps

# 重置数据库
./db_manage.sh
# 选择选项4：重置数据库
```

#### 3. 端口冲突
```bash
# 查看端口占用
sudo netstat -tlpn | grep 8000

# 修改docker-compose.yml中的端口映射
# 将"8000:8000"改为"8001:8000"
```

## 📚 参考资源

- **MrDoc 官方文档**：https://doc.mrdoc.fun/
- **Django 开发文档**：https://docs.djangoproject.com/
- **Docker Compose 参考**：https://docs.docker.com/compose/

## 🤝 社区支持

- **GitHub Issues**：https://github.com/zmister2016/MrDoc/issues
- **QQ 群**：735507293
- **开发讨论**：欢迎在你的仓库中创建 Issues 讨论定制功能

---

🎉 **开始你的 MrDoc 二次开发之旅吧！**

有问题随时查看此文档或联系社区支持。