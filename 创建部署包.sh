#!/bin/bash
# MrDoc DSM部署包创建脚本

set -e

echo "==================================="
echo "创建MrDoc DSM部署包"
echo "==================================="

# 定义变量
PROJECT_DIR="/Users/x/mrdoc-dev"
DEPLOY_PKG_NAME="mrdoc-docker-dsm-$(date +%Y%m%d)"
DEPLOY_DIR="/tmp/${DEPLOY_PKG_NAME}"

# 清理旧的临时目录
if [ -d "$DEPLOY_DIR" ]; then
    echo "清理旧的临时目录..."
    rm -rf "$DEPLOY_DIR"
fi

# 创建部署目录
echo "创建部署目录..."
mkdir -p "$DEPLOY_DIR"

# 复制必要的文件
echo "复制文件..."

# 1. 核心代码和配置
cp -r "${PROJECT_DIR}/MrDoc" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/app_admin" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/app_doc" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/app_api" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/app_ai" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/config" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/static" "$DEPLOY_DIR/"
cp -r "${PROJECT_DIR}/template" "$DEPLOY_DIR/"

# 2. Python依赖和管理脚本
cp "${PROJECT_DIR}/requirements.txt" "$DEPLOY_DIR/"
cp "${PROJECT_DIR}/manage.py" "$DEPLOY_DIR/"

# 3. Docker配置文件
cp "${PROJECT_DIR}/Dockerfile.dsm" "$DEPLOY_DIR/"
cp "${PROJECT_DIR}/docker-entrypoint-dsm.sh" "$DEPLOY_DIR/"
cp "${PROJECT_DIR}/docker-compose-dsm.yml" "$DEPLOY_DIR/"

# 4. 数据文件
cp "${PROJECT_DIR}/mrdoc_data.json" "$DEPLOY_DIR/"

# 5. 部署文档
cp "${PROJECT_DIR}/DSM部署指南.md" "$DEPLOY_DIR/"

# 6. 搜索API相关文档
if [ -f "${PROJECT_DIR}/API响应格式说明.md" ]; then
    cp "${PROJECT_DIR}/API响应格式说明.md" "$DEPLOY_DIR/"
fi
if [ -f "${PROJECT_DIR}/字段名称对照表.md" ]; then
    cp "${PROJECT_DIR}/字段名称对照表.md" "$DEPLOY_DIR/"
fi

# 创建README
cat > "$DEPLOY_DIR/README.md" << 'EOF'
# MrDoc Docker DSM 部署包

## 快速开始

### 1. 上传到DSM

将此文件夹上传到DSM的 `/docker/mrdoc` 目录

### 2. SSH登录并部署

```bash
ssh 你的DSM用户名@DSM的IP地址
cd /volume1/docker/mrdoc
sudo docker-compose -f docker-compose-dsm.yml up -d
```

### 3. 访问系统

浏览器打开：`http://你的DSM地址:8000`

- 管理员账号：admin
- 管理员密码：admin123

## 详细说明

请查看 `DSM部署指南.md` 获取详细的部署步骤和配置说明。

## 包含内容

- ✅ 完整MrDoc源代码
- ✅ Docker配置文件
- ✅ 128篇文档数据
- ✅ 29个文集（所有已设为私密）
- ✅ 搜索索引配置
- ✅ API Token已配置

## 系统信息

- MrDoc版本：0.9.6
- Python版本：3.11
- 数据库：SQLite
- API Token：43c395f68784452784585da896cb5c66
EOF

# 设置脚本可执行权限
chmod +x "$DEPLOY_DIR/docker-entrypoint-dsm.sh"

# 创建data目录结构
echo "创建数据目录结构..."
mkdir -p "$DEPLOY_DIR/data/db"
mkdir -p "$DEPLOY_DIR/data/media"
mkdir -p "$DEPLOY_DIR/data/log"
mkdir -p "$DEPLOY_DIR/data/whoosh_index"

# 打包
echo "打包文件..."
cd /tmp
tar -czf "${DEPLOY_PKG_NAME}.tar.gz" "${DEPLOY_PKG_NAME}"

# 计算文件大小
PKG_SIZE=$(du -h "${DEPLOY_PKG_NAME}.tar.gz" | cut -f1)

echo "==================================="
echo "✅ 部署包创建完成！"
echo "==================================="
echo ""
echo "📦 文件位置：/tmp/${DEPLOY_PKG_NAME}.tar.gz"
echo "📊 文件大小：${PKG_SIZE}"
echo ""
echo "📋 包含内容："
echo "  - MrDoc完整源代码"
echo "  - Docker配置（Dockerfile.dsm, docker-compose-dsm.yml）"
echo "  - 数据库数据（128篇文档，29个文集）"
echo "  - 部署文档和API说明"
echo ""
echo "📝 下一步："
echo "  1. 将 /tmp/${DEPLOY_PKG_NAME}.tar.gz 上传到DSM"
echo "  2. 在DSM上解压：tar -xzf ${DEPLOY_PKG_NAME}.tar.gz"
echo "  3. 按照 DSM部署指南.md 进行部署"
echo ""
echo "==================================="
