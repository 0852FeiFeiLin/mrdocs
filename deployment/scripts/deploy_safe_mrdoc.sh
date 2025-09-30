#!/bin/bash

# MrDoc 部署脚本 - SQLite版本
# 使用SQLite数据库，无需MySQL，部署更简单

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

# 默认配置
PROJECT_NAME="mrdocs"
# 获取脚本所在目录的上上级目录 (../../)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MRDOC_REPO_URL="https://github.com/0852FeiFeiLin/mrdocs.git"
MRDOC_BRANCH="master"
DOMAIN_NAME="localhost"

# 端口配置（SQLite版本不需要MySQL端口）
REDIS_PORT="6380"      # 使用6380而不是6379
MRDOC_PORT="8081"      # 使用8081端口
NGINX_HTTP_PORT="8082" # 使用8082端口
NGINX_HTTPS_PORT="8443" # 使用8443而不是443

# 容器名前缀（避免冲突）
CONTAINER_PREFIX="mrdocs-safe"

# 服务模式（SQLite版本只需要考虑Redis）
USE_EXTERNAL_REDIS="false"
EXTERNAL_REDIS_HOST=""
EXTERNAL_REDIS_PORT=""
EXTERNAL_REDIS_PASSWORD=""

# GitHub镜像源配置
GITHUB_MIRRORS=(
    ""  # 官方源
    "https://gh-proxy.com/"
    "https://ghfast.top/"
    "https://gh.api.99988866.xyz/"
    "https://mirror.ghproxy.com/"
)

# Git克隆函数（支持镜像源）
git_clone_with_mirrors() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-}"

    print_message "正在尝试克隆仓库..."

    for mirror in "${GITHUB_MIRRORS[@]}"; do
        local full_url="${mirror}${repo_url}"

        if [ -z "$mirror" ]; then
            print_message "尝试GitHub官方源: $repo_url"
        else
            print_message "尝试镜像源: $mirror"
        fi

        local git_cmd="git clone"
        if [ -n "$branch" ]; then
            git_cmd="$git_cmd -b $branch"
        fi
        git_cmd="$git_cmd $full_url $target_dir"

        if timeout 60 $git_cmd 2>/dev/null; then
            print_success "克隆成功！使用源: ${mirror:-GitHub官方}"
            return 0
        else
            print_warning "克隆失败，尝试下一个源..."
            rm -rf "$target_dir" 2>/dev/null || true
        fi
    done

    print_error "所有Git源都无法访问，请检查网络或手动上传源码"
    return 1
}

# 检查端口占用
check_port_conflict() {
    local port=$1
    local service_name=$2

    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        print_warning "$service_name 端口 $port 已被占用"
        return 1
    fi
    return 0
}

# 检查容器名冲突
check_container_conflict() {
    local container_name=$1

    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_warning "容器名 $container_name 已存在"
        return 1
    fi
    return 0
}

# 检查网络冲突
check_network_conflict() {
    local network_name=$1

    if docker network ls --format '{{.Name}}' | grep -q "^${network_name}$"; then
        print_warning "Docker网络 $network_name 已存在"
        return 1
    fi
    return 0
}

# 显示欢迎信息
show_welcome() {
    print_title "MrDoc SQLite部署脚本"
    echo -e "${BLUE}📦 使用SQLite数据库，简化部署流程${NC}"
    echo
    echo -e "${GREEN}特性：${NC}"
    echo -e "  ✅ 使用SQLite数据库（无需MySQL）"
    echo -e "  ✅ 自动检测端口冲突"
    echo -e "  ✅ 支持外部Redis服务"
    echo -e "  ✅ 使用非标准端口避免冲突"
    echo -e "  ✅ 容器名称加前缀避免重复"
    echo -e "  ✅ 独立网络隔离"
    echo
    read -p "按回车键继续，或Ctrl+C退出..." dummy
}

# 环境冲突检测
detect_conflicts() {
    print_title "检测服务冲突"

    local conflicts_found=0

    # 检查端口冲突
    print_message "检查端口占用情况..."

    # SQLite版本不需要检查MySQL端口

    if ! check_port_conflict $REDIS_PORT "Redis"; then
        conflicts_found=1
    fi

    if ! check_port_conflict $MRDOC_PORT "MrDoc应用"; then
        conflicts_found=1
    fi

    if ! check_port_conflict $NGINX_HTTP_PORT "Nginx HTTP"; then
        conflicts_found=1
    fi

    # 检查容器名冲突
    print_message "检查容器名冲突..."

    # SQLite版本不需要MySQL容器

    if ! check_container_conflict "${CONTAINER_PREFIX}-redis"; then
        conflicts_found=1
    fi

    if ! check_container_conflict "${CONTAINER_PREFIX}-app"; then
        conflicts_found=1
    fi

    if ! check_container_conflict "${CONTAINER_PREFIX}-nginx"; then
        conflicts_found=1
    fi

    # 检查网络冲突
    if ! check_network_conflict "${CONTAINER_PREFIX}-network"; then
        conflicts_found=1
    fi

    if [ $conflicts_found -eq 1 ]; then
        print_warning "检测到潜在冲突，建议使用外部服务或修改端口"
        return 1
    else
        print_success "未检测到冲突，可以安全部署"
        return 0
    fi
}

# 配置外部服务
configure_external_services() {
    print_title "外部服务配置"

    echo -e "${YELLOW}使用SQLite数据库，只需配置Redis${NC}"
    echo

    # Redis配置
    read -p "是否使用外部Redis服务? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_EXTERNAL_REDIS="true"
        read -p "Redis主机地址 [localhost]: " EXTERNAL_REDIS_HOST
        EXTERNAL_REDIS_HOST=${EXTERNAL_REDIS_HOST:-localhost}

        read -p "Redis端口 [6379]: " EXTERNAL_REDIS_PORT
        EXTERNAL_REDIS_PORT=${EXTERNAL_REDIS_PORT:-6379}

        read -p "Redis密码 (可为空): " EXTERNAL_REDIS_PASSWORD

        # 测试连接
        print_message "测试Redis连接..."
        if command -v redis-cli >/dev/null 2>&1; then
            local redis_cmd="redis-cli -h $EXTERNAL_REDIS_HOST -p $EXTERNAL_REDIS_PORT"
            if [ -n "$EXTERNAL_REDIS_PASSWORD" ]; then
                redis_cmd="$redis_cmd -a $EXTERNAL_REDIS_PASSWORD"
            fi

            if $redis_cmd ping 2>/dev/null | grep -q "PONG"; then
                print_success "Redis连接测试成功"
            else
                print_warning "Redis连接测试失败，请检查配置"
            fi
        else
            print_warning "未安装redis-cli，无法测试连接"
        fi
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
    echo -e "  应用端口: ${YELLOW}$MRDOC_PORT${NC}"
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

        echo
        print_message "项目目录配置："
        echo -e "  1) 使用默认目录: $PROJECT_DIR"
        echo -e "  2) 自定义完整路径"
        read -p "选择项目目录 (1-2) [1]: " -n 1 -r dir_choice
        echo

        case ${dir_choice:-1} in
            2)
                while true; do
                    read -p "请输入完整项目路径 [${PROJECT_DIR}]: " input_dir
                    PROJECT_DIR=${input_dir:-$PROJECT_DIR}

                    # 验证路径格式
                    if [[ ! "$PROJECT_DIR" =~ ^/ ]]; then
                        PROJECT_DIR="${HOME}/${PROJECT_DIR}"
                        print_warning "相对路径已转换为: $PROJECT_DIR"
                    fi

                    # 检查父目录是否存在或可创建
                    parent_dir=$(dirname "$PROJECT_DIR")
                    if [ -d "$parent_dir" ] || mkdir -p "$parent_dir" 2>/dev/null; then
                        print_success "项目目录设置为: $PROJECT_DIR"
                        break
                    else
                        print_error "无法创建父目录: $parent_dir，请重新输入"
                    fi
                done
                ;;
            *)
                # 使用已设置的默认PROJECT_DIR（脚本目录的../../）
                ;;
        esac

        # 端口配置
        echo
        print_message "端口配置 (避免与现有服务冲突)："
        read -p "MrDoc应用端口 [${MRDOC_PORT}]: " input_port
        MRDOC_PORT=${input_port:-$MRDOC_PORT}

        if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
            read -p "Redis端口 [${REDIS_PORT}]: " input_redis_port
            REDIS_PORT=${input_redis_port:-$REDIS_PORT}
        fi

        read -p "Nginx HTTP端口 [${NGINX_HTTP_PORT}]: " input_nginx_port
        NGINX_HTTP_PORT=${input_nginx_port:-$NGINX_HTTP_PORT}
    fi

    read -p "域名 [${DOMAIN_NAME}]: " input_domain
    DOMAIN_NAME=${input_domain:-$DOMAIN_NAME}

    # 显示最终配置
    echo
    print_title "最终部署配置"
    echo -e "${GREEN}✅ 仓库地址: ${YELLOW}$MRDOC_REPO_URL${NC}"
    echo -e "${GREEN}✅ 分支: ${YELLOW}$MRDOC_BRANCH${NC}"
    echo -e "${GREEN}✅ 项目名称: ${YELLOW}$PROJECT_NAME${NC}"
    echo -e "${GREEN}✅ 项目目录: ${YELLOW}$PROJECT_DIR${NC}"
    echo -e "${GREEN}✅ 访问域名: ${YELLOW}$DOMAIN_NAME${NC}"
    echo -e "${GREEN}✅ 数据库: ${YELLOW}SQLite (内置)${NC}"
    echo
    echo -e "${BLUE}端口配置：${NC}"
    echo -e "  📱 MrDoc应用: ${YELLOW}$MRDOC_PORT${NC}"
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo -e "  ⚡ Redis: ${YELLOW}$REDIS_PORT${NC}"
    else
        echo -e "  ⚡ Redis: ${YELLOW}外部服务 $EXTERNAL_REDIS_HOST:$EXTERNAL_REDIS_PORT${NC}"
    fi
    echo -e "  🌐 Nginx: ${YELLOW}$NGINX_HTTP_PORT${NC}"
    echo

    read -p "确认以上配置开始部署? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "部署已取消"
        exit 0
    fi
}

# 创建安全的docker-compose配置
create_safe_docker_compose() {
    print_title "生成安全Docker配置"

    # 创建docker-compose.yml（不使用version属性以避免警告）
    cat > deployment/docker/docker-compose.yml << EOF
services:
  # MrDoc 主应用
  ${CONTAINER_PREFIX}-app:
    build:
      context: ../..
      dockerfile: deployment/docker/Dockerfile.mrdoc
    container_name: ${CONTAINER_PREFIX}-app
    restart: unless-stopped
    ports:
      - "${MRDOC_PORT}:8000"
    volumes:
      - ../../media:/app/media
      - ../../logs:/app/logs
      - ../../static:/app/static
      - ../../config:/app/config
      - sqlite_data:/app/db
    environment:
      - DB_ENGINE=sqlite
      - DB_NAME=/app/config/db.sqlite3
EOF

    # Redis环境变量
    if [ "$USE_EXTERNAL_REDIS" = "true" ]; then
        cat >> deployment/docker/docker-compose.yml << EOF
      - REDIS_HOST=${EXTERNAL_REDIS_HOST}
      - REDIS_PORT=${EXTERNAL_REDIS_PORT}
EOF
        if [ -n "$EXTERNAL_REDIS_PASSWORD" ]; then
            echo "      - REDIS_PASSWORD=${EXTERNAL_REDIS_PASSWORD}" >> deployment/docker/docker-compose.yml
        fi
    else
        cat >> deployment/docker/docker-compose.yml << EOF
      - REDIS_HOST=${CONTAINER_PREFIX}-redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=redispassword123
EOF
    fi

    # 应用其他环境变量
    cat >> deployment/docker/docker-compose.yml << EOF
      - DJANGO_SETTINGS_MODULE=MrDoc.settings
      - DJANGO_SECRET_KEY=django_safe_secret_$(openssl rand -base64 32 | tr -d '=+/')
      - DJANGO_DEBUG=False
      - DJANGO_ALLOWED_HOSTS=*
      - DJANGO_SUPERUSER_USERNAME=admin
      - DJANGO_SUPERUSER_EMAIL=admin@example.com
      - DJANGO_SUPERUSER_PASSWORD=admin123456
      - REDIS_DB=4
      - TZ=Asia/Shanghai
    networks:
      - ${CONTAINER_PREFIX}-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s
    depends_on:
EOF

    # 依赖服务（SQLite版本只依赖Redis）
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo "      - ${CONTAINER_PREFIX}-redis" >> deployment/docker/docker-compose.yml
    fi

    # Redis服务（如果不使用外部）
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        cat >> deployment/docker/docker-compose.yml << EOF

  # Redis 缓存
  ${CONTAINER_PREFIX}-redis:
    image: redis:7-alpine
    container_name: ${CONTAINER_PREFIX}-redis
    restart: unless-stopped
    volumes:
      - ${CONTAINER_PREFIX}_redis_data:/data
    ports:
      - "${REDIS_PORT}:6379"
    networks:
      - ${CONTAINER_PREFIX}-network
    command: redis-server --requirepass redispassword123 --databases 16
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redispassword123", "ping"]
      interval: 30s
      timeout: 3s
      retries: 5
EOF
    fi

    # Nginx服务
    cat >> deployment/docker/docker-compose.yml << EOF

  # Nginx 反向代理
  ${CONTAINER_PREFIX}-nginx:
    image: nginx:alpine
    container_name: ${CONTAINER_PREFIX}-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_HTTP_PORT}:80"
      - "${NGINX_HTTPS_PORT}:443"
    volumes:
      - ../nginx/nginx.conf:/etc/nginx/nginx.conf
      - ../nginx/mrdoc.conf:/etc/nginx/conf.d/default.conf
      - ../../static:/var/www/static
      - ../../media:/var/www/media
    networks:
      - ${CONTAINER_PREFIX}-network
    depends_on:
      - ${CONTAINER_PREFIX}-app

# 数据卷定义
volumes:
  sqlite_data:
EOF

    # Redis数据卷
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo "  ${CONTAINER_PREFIX}_redis_data:" >> deployment/docker/docker-compose.yml
    fi

    # 网络定义
    cat >> deployment/docker/docker-compose.yml << EOF

# 网络定义
networks:
  ${CONTAINER_PREFIX}-network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.31.0.0/16
          gateway: 172.31.0.1
EOF

    print_success "安全Docker配置生成完成"
}

# 主函数
main() {
    # 检查是否为root用户
    if [ "$EUID" -eq 0 ]; then
        print_warning "正在使用root用户运行脚本，请确保您了解相关安全风险"
        read -p "继续运行? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "部署已取消"
            exit 1
        fi
    fi

    show_welcome

    # 检测冲突
    if ! detect_conflicts; then
        configure_external_services
    fi

    get_user_config

    # 创建项目目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    # 下载源码
    if [ ! -f "manage.py" ]; then
        print_title "下载源码"
        git_clone_with_mirrors "$MRDOC_REPO_URL" . "$MRDOC_BRANCH"
    fi

    # 确保部署目录存在
    mkdir -p deployment/docker

    # 创建必要的配置文件
    print_message "创建配置文件..."

    # SQLite版本不需要MySQL初始化脚本

    # 创建entrypoint.sh
    cat > deployment/docker/entrypoint.sh << 'EOF'
#!/bin/bash

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_info "🚀 启动 MrDoc 应用 (SQLite版本)..."

# 显示环境配置
echo_info "环境配置:"
echo "  数据库: SQLite"
echo "  REDIS_HOST=$REDIS_HOST"
echo "  REDIS_PORT=$REDIS_PORT"

cd /app

# 确保config目录和SQLite数据库文件存在
echo_info "📦 初始化SQLite数据库..."
mkdir -p /app/config
if [ ! -f "/app/config/db.sqlite3" ]; then
    touch /app/config/db.sqlite3
    chmod 664 /app/config/db.sqlite3
    echo_info "✅ SQLite数据库文件已创建"
else
    echo_info "ℹ️ SQLite数据库文件已存在"
fi

# Django操作
echo_info "🔄 执行数据库迁移..."
python manage.py makemigrations --noinput || echo_warn "makemigrations失败，可能没有新的迁移"
python manage.py migrate --noinput || { echo_error "数据库迁移失败"; exit 1; }

echo_info "📁 收集静态文件..."
python manage.py collectstatic --noinput --clear || echo_warn "收集静态文件失败"

echo_info "👤 创建超级用户..."
python manage.py shell << PYTHON_EOF
import os
from django.contrib.auth.models import User
username = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
email = os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@example.com')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'admin123456')
if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username, email, password)
    print(f"✅ 超级用户创建成功: {username}")
else:
    print(f"ℹ️ 超级用户已存在: {username}")
PYTHON_EOF

# 创建目录
mkdir -p /app/media/uploads /app/logs
chmod -R 755 /app/media /app/static /app/config

echo_info "🎉 MrDoc 初始化完成!"

# 启动服务
exec gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 --log-level info --access-logfile - --error-logfile - MrDoc.wsgi:application
EOF
    chmod +x deployment/docker/entrypoint.sh

    # 创建Dockerfile.mrdoc
    cat > deployment/docker/Dockerfile.mrdoc << 'EOF'
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=MrDoc.settings

# 安装系统依赖（SQLite版本不需要MySQL客户端）
RUN apt-get update && apt-get install -y \
    gcc g++ pkg-config \
    libssl-dev libffi-dev \
    libjpeg-dev libpng-dev libwebp-dev zlib1g-dev \
    git curl wget vim netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 创建非root用户
RUN useradd -m -u 1000 mrdoc && chown -R mrdoc:mrdoc /app

USER mrdoc

# 复制项目文件
COPY --chown=mrdoc:mrdoc . /app/

# 创建目录
RUN mkdir -p /app/logs /app/media /app/static /app/config /app/db

# 安装Python依赖（SQLite版本不需要mysqlclient）
RUN pip install --no-cache-dir --user -r requirements.txt && \
    pip install --no-cache-dir --user \
    cryptography==41.0.7 \
    django-filter==23.5 \
    gunicorn==21.2.0

# 复制启动脚本
COPY --chown=mrdoc:mrdoc deployment/docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
EOF

    # 创建Nginx配置
    mkdir -p deployment/nginx

    cat > deployment/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    upstream mrdoc_backend {
        server mrdocs-safe-app:8000;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF

    cat > deployment/nginx/mrdoc.conf << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 100M;

    location /static/ {
        alias /var/www/static/;
        expires 30d;
    }

    location /media/ {
        alias /var/www/media/;
        expires 7d;
    }

    location / {
        proxy_pass http://mrdoc_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

    # 创建安全的docker配置
    create_safe_docker_compose

    # 构建和启动
    print_title "构建和启动服务"
    docker-compose -f deployment/docker/docker-compose.yml build
    docker-compose -f deployment/docker/docker-compose.yml up -d

    # 等待服务启动
    print_message "等待服务启动..."

    # SQLite版本不需要等待数据库服务，直接等待应用启动
    print_message "等待应用初始化完成..."
    for i in {1..60}; do
        # 检查容器是否正在运行且健康
        container_status=$(docker inspect ${CONTAINER_PREFIX}-app --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

        if [ "$container_status" = "running" ]; then
            # 测试应用是否响应
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:${MRDOC_PORT} 2>/dev/null | grep -qE "200|301|302"; then
                print_success "应用初始化完成"
                break
            fi
        fi

        echo -n "."
        sleep 2
    done
    echo

    # 显示容器日志的最后几行
    print_message "应用启动日志："
    docker logs ${CONTAINER_PREFIX}-app --tail 20

    # 显示部署结果
    print_title "部署完成"
    print_success "MrDoc SQLite版本部署成功！"
    echo
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}✅ 访问地址: ${YELLOW}http://$SERVER_IP:$MRDOC_PORT${NC}"
    echo -e "${GREEN}✅ 管理后台: ${YELLOW}http://$SERVER_IP:$MRDOC_PORT/admin${NC}"
    echo -e "${GREEN}✅ 管理员: ${YELLOW}admin / admin123456${NC}"
    echo
    echo -e "${BLUE}📊 服务端口：${NC}"
    echo -e "  MrDoc应用: $MRDOC_PORT"
    echo -e "  数据库: SQLite (内置)"
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo -e "  Redis: $REDIS_PORT"
    fi
    echo -e "  Nginx: $NGINX_HTTP_PORT"
    echo
    print_message "使用SQLite数据库，部署更简单！"
}

# 错误处理
trap 'print_error "部署过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"