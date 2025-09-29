#!/bin/bash

# MrDoc 二次开发版本一键部署脚本
# 针对用户自定义源码仓库的部署方案

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_title() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${PURPLE}🎉 $1${NC}"
}

# 默认配置（针对你的二次开发仓库）
PROJECT_NAME="mrdocs-custom"
PROJECT_DIR="${HOME}/${PROJECT_NAME}"
MRDOC_REPO_URL="https://github.com/0852FeiFeiLin/mrdocs.git"
MRDOC_BRANCH="main"
DOMAIN_NAME="localhost"

# 显示欢迎信息
show_welcome() {
    print_title "MrDoc 二次开发版本部署脚本"
    echo -e "${BLUE}🚀 专为二次开发定制的部署方案${NC}"
    echo
    echo -e "${GREEN}特性：${NC}"
    echo -e "  ✅ 支持自定义源码仓库"
    echo -e "  ✅ 灵活的分支选择"
    echo -e "  ✅ 开发环境友好"
    echo -e "  ✅ 快速重新部署"
    echo
}

# 检查并处理空仓库
handle_empty_repository() {
    print_title "检查源码仓库状态"

    # 先尝试克隆仓库检查是否为空
    temp_dir=$(mktemp -d)
    if git clone "$MRDOC_REPO_URL" "$temp_dir/test" 2>/dev/null; then
        if [ ! "$(ls -A $temp_dir/test)" ] || [ ! -f "$temp_dir/test/manage.py" ]; then
            print_warning "检测到空仓库或缺少Django项目文件"
            rm -rf "$temp_dir"

            echo -e "${YELLOW}选项：${NC}"
            echo -e "  1) 使用原版 MrDoc 源码作为基础"
            echo -e "  2) 从本地现有项目复制文件"
            echo -e "  3) 创建基础项目结构"
            echo -e "  4) 取消部署"
            echo

            read -p "请选择操作 (1-4): " -n 1 -r
            echo

            case $REPLY in
                1)
                    print_message "将使用原版 MrDoc 作为基础，稍后你可以推送修改"
                    MRDOC_REPO_URL="https://github.com/zmister2016/MrDoc.git"
                    SETUP_CUSTOM_REPO=true
                    ;;
                2)
                    read -p "请输入本地项目路径: " local_path
                    if [ -d "$local_path" ] && [ -f "$local_path/manage.py" ]; then
                        LOCAL_PROJECT_PATH="$local_path"
                        USE_LOCAL_PROJECT=true
                        print_message "将使用本地项目: $local_path"
                    else
                        print_error "本地路径无效或不包含 Django 项目"
                        exit 1
                    fi
                    ;;
                3)
                    print_message "将创建基础项目结构"
                    CREATE_BASE_STRUCTURE=true
                    ;;
                4)
                    print_message "部署已取消"
                    exit 0
                    ;;
                *)
                    print_error "无效选择"
                    exit 1
                    ;;
            esac
        else
            print_message "✅ 仓库包含有效的项目文件"
        fi
        rm -rf "$temp_dir"
    else
        print_error "无法访问仓库: $MRDOC_REPO_URL"
        print_error "请检查："
        print_error "1. 仓库地址是否正确"
        print_error "2. 网络连接是否正常"
        print_error "3. 仓库权限是否允许访问"
        exit 1
    fi
}

# 获取用户配置
get_user_config() {
    print_title "配置部署参数"

    # 显示当前配置
    echo -e "${BLUE}当前配置：${NC}"
    echo -e "  仓库地址: ${YELLOW}$MRDOC_REPO_URL${NC}"
    echo -e "  分支: ${YELLOW}$MRDOC_BRANCH${NC}"
    echo -e "  项目目录: ${YELLOW}$PROJECT_DIR${NC}"
    echo

    # 询问是否修改配置
    read -p "是否修改配置? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "源码仓库地址 [${MRDOC_REPO_URL}]: " input_repo
        MRDOC_REPO_URL=${input_repo:-$MRDOC_REPO_URL}

        read -p "分支名称 [${MRDOC_BRANCH}]: " input_branch
        MRDOC_BRANCH=${input_branch:-$MRDOC_BRANCH}

        read -p "项目名称 [${PROJECT_NAME}]: " input_project
        PROJECT_NAME=${input_project:-$PROJECT_NAME}
        PROJECT_DIR="${HOME}/${PROJECT_NAME}"
    fi

    read -p "域名 [${DOMAIN_NAME}]: " input_domain
    DOMAIN_NAME=${input_domain:-$DOMAIN_NAME}
}

# 准备源码
prepare_source_code() {
    print_title "准备源码"

    cd "$PROJECT_DIR"

    if [ "$USE_LOCAL_PROJECT" = true ]; then
        print_message "从本地项目复制文件..."
        cp -r "$LOCAL_PROJECT_PATH"/* .
        # 初始化git仓库
        git init
        git remote add origin "$MRDOC_REPO_URL"
        print_message "✅ 本地项目文件复制完成"

    elif [ "$CREATE_BASE_STRUCTURE" = true ]; then
        print_message "创建基础项目结构..."
        # 这里可以创建一个基础的Django项目模板
        cat > manage.py << 'EOF'
#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

if __name__ == '__main__':
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'MrDoc.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)
EOF

        cat > requirements.txt << 'EOF'
django==4.2.*
djangorestframework==3.15.2
mysqlclient
redis
gunicorn
EOF

        print_warning "⚠️  创建了基础文件，但你需要手动完善项目结构"

    else
        print_message "下载源码从: $MRDOC_REPO_URL"
        if [ -d "source" ]; then
            rm -rf source
        fi

        git clone -b "$MRDOC_BRANCH" "$MRDOC_REPO_URL" source || {
            print_warning "指定分支不存在，尝试默认分支..."
            git clone "$MRDOC_REPO_URL" source
        }

        cp -r source/* .
        print_message "✅ 源码下载完成"

        # 如果是从原版MrDoc基础开始，设置新的远程仓库
        if [ "$SETUP_CUSTOM_REPO" = true ]; then
            cd source
            git remote set-url origin "https://github.com/0852FeiFeiLin/mrdocs.git"
            cd ..
            print_message "🔄 已设置你的自定义仓库为远程地址"
        fi
    fi

    # 检查关键文件
    if [ ! -f "manage.py" ]; then
        print_error "❌ 未找到 manage.py 文件"
        print_error "请确保项目包含完整的 Django 项目文件"
        exit 1
    fi

    print_message "✅ 项目文件准备完成"
}

# 创建快速部署配置
create_quick_deploy_config() {
    print_title "创建快速部署配置"

    # 创建简化的docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  mrdoc:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-app
    restart: unless-stopped
    ports:
      - "8000:8000"  # 直接暴露端口，方便开发
    volumes:
      - ./:/app/source  # 挂载源码目录，支持热更新
      - ./media:/app/media
      - ./logs:/app/logs
      - ./config:/app/config
    environment:
      - DB_HOST=mysql
      - DB_NAME=mrdoc
      - DB_USER=mrdoc
      - DB_PASSWORD=mrdoc123456
      - REDIS_HOST=redis
      - REDIS_PASSWORD=redis123456
      - DJANGO_DEBUG=True  # 开发模式
      - DJANGO_ALLOWED_HOSTS=*
      - TZ=Asia/Shanghai
    networks:
      - mrdoc-network
    depends_on:
      - mysql
      - redis
    command: python manage.py runserver 0.0.0.0:8000  # 开发服务器

  mysql:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root123456
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: mrdoc123456
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"  # 暴露端口方便管理
    networks:
      - mrdoc-network
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME}-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"  # 暴露端口方便管理
    networks:
      - mrdoc-network
    command: redis-server --requirepass redis123456

volumes:
  mysql_data:
  redis_data:

networks:
  mrdoc-network:
    driver: bridge
EOF

    # 创建开发用Dockerfile
    cat > Dockerfile << EOF
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \\
    gcc g++ pkg-config default-libmysqlclient-dev \\
    libssl-dev libffi-dev libjpeg-dev libpng-dev \\
    libwebp-dev zlib1g-dev git curl vim \\
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY . /app/

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt || \\
    pip install --no-cache-dir django djangorestframework mysqlclient redis gunicorn

# 创建必要目录
RUN mkdir -p /app/logs /app/media /app/static /app/config

EXPOSE 8000

# 开发环境启动脚本
CMD ["sh", "-c", "python manage.py migrate && python manage.py runserver 0.0.0.0:8000"]
EOF

    print_message "✅ 开发环境配置创建完成"
}

# 创建开发工具脚本
create_dev_scripts() {
    print_title "创建开发工具脚本"

    # 开发服务启动脚本
    cat > dev_start.sh << 'EOF'
#!/bin/bash
echo "🚀 启动开发环境..."
docker-compose up -d mysql redis
echo "⏳ 等待数据库启动..."
sleep 10
docker-compose up mrdoc
EOF

    # 快速重启脚本
    cat > dev_restart.sh << 'EOF'
#!/bin/bash
echo "🔄 重启开发服务..."
docker-compose restart mrdoc
echo "✅ 服务已重启"
EOF

    # 代码同步脚本
    cat > sync_code.sh << 'EOF'
#!/bin/bash
echo "📤 同步代码到远程仓库..."
git add .
read -p "提交消息: " commit_msg
git commit -m "$commit_msg"
git push origin main
echo "✅ 代码同步完成"
EOF

    # 数据库管理脚本
    cat > db_manage.sh << 'EOF'
#!/bin/bash
echo "选择数据库操作："
echo "1) 进入MySQL"
echo "2) 导出数据库"
echo "3) 导入数据库"
echo "4) 重置数据库"
read -p "请选择 (1-4): " choice

case $choice in
    1) docker-compose exec mysql mysql -umrdoc -pmrdoc123456 mrdoc ;;
    2) docker-compose exec mysql mysqldump -umrdoc -pmrdoc123456 mrdoc > backup_$(date +%Y%m%d).sql ;;
    3) read -p "SQL文件路径: " sql_file
       docker-compose exec -T mysql mysql -umrdoc -pmrdoc123456 mrdoc < "$sql_file" ;;
    4) docker-compose exec mysql mysql -umrdoc -pmrdoc123456 -e "DROP DATABASE mrdoc; CREATE DATABASE mrdoc CHARACTER SET utf8mb4;"
       docker-compose exec mrdoc python manage.py migrate ;;
esac
EOF

    # 日志查看脚本
    cat > logs.sh << 'EOF'
#!/bin/bash
echo "选择要查看的日志："
echo "1) MrDoc应用日志"
echo "2) MySQL日志"
echo "3) Redis日志"
echo "4) 实时跟踪所有日志"
read -p "请选择 (1-4): " choice

case $choice in
    1) docker-compose logs -f mrdoc ;;
    2) docker-compose logs -f mysql ;;
    3) docker-compose logs -f redis ;;
    4) docker-compose logs -f ;;
esac
EOF

    # 设置执行权限
    chmod +x dev_start.sh dev_restart.sh sync_code.sh db_manage.sh logs.sh

    print_message "✅ 开发工具脚本创建完成"
}

# 启动服务
start_services() {
    print_title "启动服务"

    print_message "构建应用镜像..."
    docker-compose build

    print_message "启动数据库和缓存..."
    docker-compose up -d mysql redis

    print_message "等待数据库启动..."
    sleep 15

    print_message "启动应用服务..."
    docker-compose up -d mrdoc

    print_message "检查服务状态..."
    docker-compose ps
}

# 显示部署结果
show_deployment_result() {
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

    print_title "部署完成"
    print_success "MrDoc 二次开发环境部署成功！"

    echo
    echo -e "${BLUE}🌐 访问信息:${NC}"
    echo -e "   开发服务器: http://${server_ip}:8000"
    echo -e "   数据库: ${server_ip}:3306 (mrdoc/mrdoc123456)"
    echo -e "   Redis: ${server_ip}:6379 (密码: redis123456)"
    echo -e "   项目目录: $PROJECT_DIR"

    echo -e "${BLUE}🛠️  开发工具:${NC}"
    echo -e "   ./dev_start.sh    # 启动开发环境"
    echo -e "   ./dev_restart.sh  # 重启应用"
    echo -e "   ./sync_code.sh    # 同步代码"
    echo -e "   ./db_manage.sh    # 数据库管理"
    echo -e "   ./logs.sh         # 查看日志"

    echo -e "${BLUE}📋 开发提示:${NC}"
    echo -e "   • 源码目录已挂载，修改代码会自动生效"
    echo -e "   • 数据库和Redis端口已暴露，方便调试"
    echo -e "   • 使用开发服务器运行，支持热重载"
    echo -e "   • 初次运行需要创建管理员账户"

    if [ "$SETUP_CUSTOM_REPO" = true ]; then
        echo
        echo -e "${YELLOW}📝 下一步操作:${NC}"
        echo -e "   1. 根据需要修改源码"
        echo -e "   2. 使用 ./sync_code.sh 推送到你的仓库"
        echo -e "   3. 配置 GitHub Pages 或部署到服务器"
    fi

    echo
    print_success "开始你的 MrDoc 二次开发之旅吧！"
}

# 主函数
main() {
    show_welcome
    get_user_config
    handle_empty_repository

    # 创建项目目录
    print_message "创建项目目录: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    prepare_source_code
    create_quick_deploy_config
    create_dev_scripts
    start_services
    show_deployment_result
}

# 运行主函数
main "$@"