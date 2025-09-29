#!/bin/bash

# MrDoc Ubuntu 服务器一键部署脚本
# 基于源码的 Docker 部署，使用 MySQL 数据库

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

# 配置变量
PROJECT_NAME="mrdoc-server"
PROJECT_DIR="${HOME}/${PROJECT_NAME}"
MRDOC_VERSION="latest"
DOMAIN_NAME="your-domain.com"
# 源码仓库配置
MRDOC_REPO_URL="https://github.com/0852FeiFeiLin/mrdocs.git"
MRDOC_BRANCH="main"

# 检查系统要求
check_requirements() {
    print_title "检查系统要求"

    # 检查系统
    if [[ ! -f /etc/os-release ]] || ! grep -q "ubuntu" /etc/os-release; then
        print_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先运行环境准备脚本"
        exit 1
    fi

    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先运行环境准备脚本"
        exit 1
    fi

    # 检查权限
    if ! docker ps &> /dev/null; then
        print_error "无法连接到Docker，请确保当前用户在docker组中"
        print_error "运行：sudo usermod -aG docker $USER && newgrp docker"
        exit 1
    fi

    print_message "系统要求检查通过"
}

# 创建项目结构
create_project_structure() {
    print_title "创建项目目录结构"

    # 如果目录存在，询问是否重新创建
    if [ -d "$PROJECT_DIR" ]; then
        print_warning "项目目录已存在: $PROJECT_DIR"
        read -p "是否删除并重新创建? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 停止运行中的容器
            cd "$PROJECT_DIR" && docker-compose down 2>/dev/null || true
            rm -rf "$PROJECT_DIR"
        else
            print_message "使用现有目录"
        fi
    fi

    # 创建目录结构
    mkdir -p "$PROJECT_DIR"/{config,data/{mysql,redis},logs/{nginx,mrdoc},media,static,nginx/{conf.d,ssl},mysql/{conf.d,init},redis,source,backup}

    cd "$PROJECT_DIR"

    print_message "项目目录结构创建完成: $PROJECT_DIR"
}

# 下载 MrDoc 源码
download_source_code() {
    print_title "下载 MrDoc 源码"

    if [ -d "source/.git" ]; then
        print_message "源码已存在，更新中..."
        cd source
        # 检查远程仓库URL是否需要更新
        current_url=$(git remote get-url origin)
        if [ "$current_url" != "$MRDOC_REPO_URL" ]; then
            print_message "更新远程仓库地址: $MRDOC_REPO_URL"
            git remote set-url origin "$MRDOC_REPO_URL"
        fi
        git pull origin "$MRDOC_BRANCH" || {
            print_error "更新源码失败，尝试重新克隆..."
            cd ..
            rm -rf source
            git clone -b "$MRDOC_BRANCH" "$MRDOC_REPO_URL" source || {
                print_error "克隆源码失败，请检查仓库地址和网络连接"
                print_error "仓库地址: $MRDOC_REPO_URL"
                print_error "分支: $MRDOC_BRANCH"
                exit 1
            }
        }
        cd ..
    else
        print_message "克隆 MrDoc 源码从: $MRDOC_REPO_URL"
        print_message "分支: $MRDOC_BRANCH"

        # 尝试克隆指定分支
        if ! git clone -b "$MRDOC_BRANCH" "$MRDOC_REPO_URL" source; then
            print_warning "指定分支 '$MRDOC_BRANCH' 不存在，尝试克隆默认分支..."
            git clone "$MRDOC_REPO_URL" source || {
                print_error "克隆源码失败，请检查："
                print_error "1. 仓库地址是否正确: $MRDOC_REPO_URL"
                print_error "2. 网络连接是否正常"
                print_error "3. 仓库是否为空或私有"
                exit 1
            }
        fi
    fi

    # 检查源码目录是否包含必要文件
    if [ ! -f "source/manage.py" ] && [ ! -f "source/requirements.txt" ]; then
        print_error "源码目录缺少关键文件 (manage.py, requirements.txt)"
        print_error "这可能不是一个有效的 Django 项目"
        print_warning "继续部署可能会失败"

        read -p "是否继续部署? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "部署已取消"
            exit 1
        fi
    fi

    # 复制源码到当前目录（用于构建Docker镜像）
    if [ -d "source" ] && [ "$(ls -A source)" ]; then
        cp -r source/* . 2>/dev/null || {
            print_warning "复制源码文件时遇到问题，尝试创建基础文件..."
            # 如果源码为空，创建基础的Django项目结构提示
            if [ ! -f "manage.py" ]; then
                print_error "未找到 manage.py 文件"
                print_error "请确保你的源码仓库包含完整的 Django 项目文件"
                exit 1
            fi
        }
    else
        print_error "源码目录为空或不存在"
        exit 1
    fi

    print_message "源码下载完成"

    # 显示项目信息
    if [ -f "manage.py" ]; then
        print_message "✅ Django 项目文件检测成功"
    fi
    if [ -f "requirements.txt" ]; then
        print_message "✅ 依赖文件检测成功"
        print_message "主要依赖包："
        head -5 requirements.txt | sed 's/^/   - /'
    fi
}

# 生成配置文件
generate_config_files() {
    print_title "生成配置文件"

    # 生成随机密码
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    SECRET_KEY=$(openssl rand -base64 50 | tr -d "=+/" | cut -c1-50)

    print_message "生成的密码信息："
    echo -e "   MySQL 密码: ${YELLOW}$DB_PASSWORD${NC}"
    echo -e "   Redis 密码: ${YELLOW}$REDIS_PASSWORD${NC}"
    echo -e "   Django 密钥: ${YELLOW}$SECRET_KEY${NC}"

    # 创建环境变量文件
    cat > .env << EOF
# MrDoc 环境配置文件

# 项目信息
COMPOSE_PROJECT_NAME=${PROJECT_NAME}
PROJECT_DIR=${PROJECT_DIR}

# 数据库配置
DB_HOST=mysql
DB_PORT=3306
DB_NAME=mrdoc
DB_USER=mrdoc
DB_PASSWORD=${DB_PASSWORD}
MYSQL_ROOT_PASSWORD=root_${DB_PASSWORD}

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}

# Django 配置
DJANGO_SECRET_KEY=${SECRET_KEY}
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*

# 管理员配置
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_EMAIL=admin@${DOMAIN_NAME}
DJANGO_SUPERUSER_PASSWORD=admin123456

# 时区设置
TZ=Asia/Shanghai

# 域名设置
DOMAIN_NAME=${DOMAIN_NAME}
EOF

    # 创建 MrDoc 配置文件
    cat > config/config.ini << EOF
[site]
debug = False
sitename = 企业知识库系统
sitedesc = 基于MrDoc构建的企业级知识管理平台

[database]
engine = mysql
name = mrdoc
user = mrdoc
password = ${DB_PASSWORD}
host = mysql
port = 3306

[redis]
host = redis
port = 6379
password = ${REDIS_PASSWORD}
db = 0

[email]
email_backend = smtp
email_host = smtp.gmail.com
email_port = 587
email_host_user = your-email@gmail.com
email_host_password = your-app-password
email_use_tls = True

[media]
max_upload_size = 100

[logging]
log_level = INFO
log_file = /app/logs/mrdoc.log

[security]
secure_ssl_redirect = False

[features]
allow_register = True
enable_search = True
enable_api = True
EOF

    # 创建 MySQL 配置
    cat > mysql/conf.d/my.cnf << EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_connections = 1000
innodb_buffer_pool_size = 256M
query_cache_size = 64M
slow_query_log = 1
long_query_time = 2

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF

    # 创建 Redis 配置
    cat > redis/redis.conf << EOF
bind 0.0.0.0
port 6379
requirepass ${REDIS_PASSWORD}
save 900 1
save 300 10
save 60 10000
maxmemory 256mb
maxmemory-policy allkeys-lru
EOF

    # 创建 Nginx 主配置
    cat > nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                   '\$status \$body_bytes_sent "\$http_referer" '
                   '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    client_max_body_size 100M;

    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    upstream mrdoc_backend {
        server mrdoc:8000;
        keepalive 32;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 创建 Nginx 站点配置
    cat > nginx/conf.d/mrdoc.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    root /var/www;

    client_max_body_size 100M;

    location /static/ {
        alias /var/www/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /var/www/media/;
        expires 7d;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://mrdoc_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 300s;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }

    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF

    print_message "配置文件生成完成"
}

# 创建 Docker 文件
create_docker_files() {
    print_title "创建 Docker 配置文件"

    # 创建 Dockerfile
    cat > Dockerfile << EOF
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \\
    gcc g++ pkg-config default-libmysqlclient-dev \\
    libssl-dev libffi-dev libjpeg-dev libpng-dev \\
    libwebp-dev zlib1g-dev git curl vim \\
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 mrdoc && chown -R mrdoc:mrdoc /app

USER mrdoc

COPY --chown=mrdoc:mrdoc . /app/
RUN mkdir -p /app/logs /app/media /app/static /app/config

RUN pip install --no-cache-dir --user -r requirements.txt
RUN pip install --no-cache-dir --user \\
    cryptography django-filter gunicorn mysqlclient

COPY --chown=mrdoc:mrdoc docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8000/ || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
EOF

    # 创建启动脚本目录
    mkdir -p docker

    # 创建启动脚本
    cat > docker/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 启动 MrDoc 应用..."

# 等待数据库
while ! mysqladmin ping -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" --silent; do
    echo "⏳ 等待数据库启动..."
    sleep 5
done

# 创建数据库
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || true

# 数据库迁移
cd /app
python manage.py makemigrations --noinput || true
python manage.py migrate --noinput

# 收集静态文件
python manage.py collectstatic --noinput --clear || true

# 创建超级用户
python manage.py shell << PYTHON_EOF
from django.contrib.auth.models import User
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
    print("超级用户创建成功: $DJANGO_SUPERUSER_USERNAME")
else:
    print("超级用户已存在: $DJANGO_SUPERUSER_USERNAME")
PYTHON_EOF

# 设置权限
mkdir -p /app/media /app/logs
chmod -R 755 /app/media /app/static

echo "✅ MrDoc 初始化完成！"

# 启动应用
if [ "${1}" = 'runserver' ]; then
    exec python manage.py runserver 0.0.0.0:8000
else
    exec gunicorn --bind 0.0.0.0:8000 \\
        --workers 4 --worker-class gevent \\
        --worker-connections 1000 --max-requests 1000 \\
        --timeout 120 --keep-alive 5 --log-level info \\
        --access-logfile /app/logs/access.log \\
        --error-logfile /app/logs/error.log \\
        --capture-output MrDoc.wsgi:application
fi
EOF

    chmod +x docker/entrypoint.sh

    # 创建 Docker Compose 文件
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  mrdoc:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-app
    restart: unless-stopped
    command: gunicorn
    volumes:
      - ./media:/app/media
      - ./logs/mrdoc:/app/logs
      - ./static:/app/static
      - ./config:/app/config
    environment:
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_NAME=mrdoc
      - DB_USER=mrdoc
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - DJANGO_SETTINGS_MODULE=MrDoc.settings
      - DJANGO_SECRET_KEY=${SECRET_KEY}
      - DJANGO_DEBUG=False
      - DJANGO_ALLOWED_HOSTS=*
      - DJANGO_SUPERUSER_USERNAME=admin
      - DJANGO_SUPERUSER_EMAIL=admin@${DOMAIN_NAME}
      - DJANGO_SUPERUSER_PASSWORD=admin123456
      - TZ=Asia/Shanghai
    networks:
      - mrdoc-network
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy

  mysql:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root_${DB_PASSWORD}
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_unicode_ci
    volumes:
      - ./data/mysql:/var/lib/mysql
      - ./mysql/conf.d:/etc/mysql/conf.d
    networks:
      - mrdoc-network
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-proot_${DB_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME}-redis
    restart: unless-stopped
    volumes:
      - ./data/redis:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - mrdoc-network
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: ${PROJECT_NAME}-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./static:/var/www/static
      - ./media:/var/www/media
      - ./logs/nginx:/var/log/nginx
    networks:
      - mrdoc-network
    depends_on:
      - mrdoc

networks:
  mrdoc-network:
    driver: bridge
EOF

    print_message "Docker 配置文件创建完成"
}

# 构建和启动服务
build_and_start_services() {
    print_title "构建和启动服务"

    print_message "构建 MrDoc 镜像..."
    docker-compose build --no-cache mrdoc

    print_message "启动所有服务..."
    docker-compose up -d

    print_message "等待服务启动..."
    sleep 30

    # 检查服务状态
    print_message "检查服务状态..."
    docker-compose ps
}

# 创建管理脚本
create_management_scripts() {
    print_title "创建管理脚本"

    # 启动脚本
    cat > start.sh << EOF
#!/bin/bash
cd ${PROJECT_DIR}
docker-compose up -d
echo "✅ MrDoc 服务已启动"
echo "🌐 访问地址: http://\$(hostname -I | awk '{print \$1}')"
EOF

    # 停止脚本
    cat > stop.sh << EOF
#!/bin/bash
cd ${PROJECT_DIR}
docker-compose down
echo "⏹️ MrDoc 服务已停止"
EOF

    # 重启脚本
    cat > restart.sh << EOF
#!/bin/bash
cd ${PROJECT_DIR}
docker-compose down
docker-compose up -d
echo "🔄 MrDoc 服务已重启"
EOF

    # 备份脚本
    cat > backup.sh << EOF
#!/bin/bash
cd ${PROJECT_DIR}
BACKUP_DIR="./backup/\$(date +%Y%m%d_%H%M%S)"
echo "📦 创建备份: \$BACKUP_DIR"
mkdir -p "\$BACKUP_DIR"

# 导出数据库
docker-compose exec -T mysql mysqldump -uroot -proot_${DB_PASSWORD} mrdoc > "\$BACKUP_DIR/database.sql"

# 备份媒体文件
tar -czf "\$BACKUP_DIR/media.tar.gz" media/

# 备份配置文件
cp -r config "\$BACKUP_DIR/"
cp .env "\$BACKUP_DIR/"

echo "✅ 备份完成: \$BACKUP_DIR"
EOF

    # 日志查看脚本
    cat > logs.sh << EOF
#!/bin/bash
cd ${PROJECT_DIR}
echo "选择要查看的日志："
echo "1) MrDoc 应用日志"
echo "2) MySQL 数据库日志"
echo "3) Redis 缓存日志"
echo "4) Nginx 访问日志"
echo "5) 所有服务日志"
read -p "请输入选择 (1-5): " choice

case \$choice in
    1) docker-compose logs -f mrdoc ;;
    2) docker-compose logs -f mysql ;;
    3) docker-compose logs -f redis ;;
    4) docker-compose logs -f nginx ;;
    5) docker-compose logs -f ;;
    *) echo "无效选择" ;;
esac
EOF

    # 设置执行权限
    chmod +x start.sh stop.sh restart.sh backup.sh logs.sh

    print_message "管理脚本创建完成"
}

# 显示部署结果
show_deployment_result() {
    local server_ip=$(hostname -I | awk '{print $1}')

    print_title "部署完成"

    print_success "MrDoc 部署成功！"
    echo
    echo -e "${BLUE}📋 访问信息:${NC}"
    echo -e "   🌐 访问地址: http://${server_ip}"
    echo -e "   👤 管理员账户: admin"
    echo -e "   🔑 管理员密码: admin123456"
    echo -e "   📁 项目目录: ${PROJECT_DIR}"
    echo
    echo -e "${BLUE}📋 管理命令:${NC}"
    echo -e "   🚀 启动服务: ./start.sh"
    echo -e "   ⏹️ 停止服务: ./stop.sh"
    echo -e "   🔄 重启服务: ./restart.sh"
    echo -e "   📦 数据备份: ./backup.sh"
    echo -e "   📋 查看日志: ./logs.sh"
    echo -e "   📊 服务状态: docker-compose ps"
    echo
    echo -e "${BLUE}📋 重要信息:${NC}"
    echo -e "   📄 配置文件: config/config.ini"
    echo -e "   🗃️ 数据目录: data/"
    echo -e "   📝 日志目录: logs/"
    echo -e "   📁 媒体文件: media/"
    echo
    echo -e "${YELLOW}📝 后续操作建议:${NC}"
    echo -e "   1. 配置域名解析到此服务器"
    echo -e "   2. 申请并配置 SSL 证书"
    echo -e "   3. 修改默认管理员密码"
    echo -e "   4. 配置邮箱服务（config/config.ini）"
    echo -e "   5. 设置定期备份任务"
    echo
    print_success "开始使用您的企业知识库吧！"
}

# 主函数
main() {
    print_title "MrDoc Ubuntu 服务器一键部署"

    # 获取用户配置
    echo -e "${BLUE}📋 部署配置${NC}"
    echo -e "当前源码仓库: ${YELLOW}$MRDOC_REPO_URL${NC}"
    echo -e "当前分支: ${YELLOW}$MRDOC_BRANCH${NC}"
    echo

    # 询问是否使用自定义源码仓库
    read -p "是否使用自定义源码仓库地址? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入源码仓库地址 (默认: $MRDOC_REPO_URL): " input_repo
        MRDOC_REPO_URL=${input_repo:-$MRDOC_REPO_URL}

        read -p "请输入分支名称 (默认: $MRDOC_BRANCH): " input_branch
        MRDOC_BRANCH=${input_branch:-$MRDOC_BRANCH}
    fi

    # 获取域名配置
    read -p "请输入您的域名 (默认: localhost): " input_domain
    DOMAIN_NAME=${input_domain:-localhost}

    # 显示最终配置
    print_message "📋 部署配置确认:"
    echo -e "   源码仓库: ${YELLOW}$MRDOC_REPO_URL${NC}"
    echo -e "   分支: ${YELLOW}$MRDOC_BRANCH${NC}"
    echo -e "   域名: ${YELLOW}$DOMAIN_NAME${NC}"
    echo -e "   项目目录: ${YELLOW}$PROJECT_DIR${NC}"
    echo

    read -p "确认开始部署? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_message "部署已取消"
        exit 0
    fi

    check_requirements
    create_project_structure
    download_source_code
    generate_config_files
    create_docker_files
    build_and_start_services
    create_management_scripts
    show_deployment_result
}

# 运行主函数
main "$@"