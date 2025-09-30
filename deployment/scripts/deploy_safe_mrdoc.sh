#!/bin/bash

# MrDoc 安全部署脚本 - 适配现有服务环境
# 避免与现有MySQL、Redis、Nginx服务冲突

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
PROJECT_NAME="mrdocs-safe"
# 获取脚本所在目录的上上级目录 (../../)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MRDOC_REPO_URL="https://github.com/0852FeiFeiLin/mrdocs.git"
MRDOC_BRANCH="master"
DOMAIN_NAME="localhost"

# 安全端口配置（避免冲突）
MYSQL_PORT="3307"      # 使用3307而不是3306
REDIS_PORT="6380"      # 使用6380而不是6379
MRDOC_PORT="8081"      # 使用8081端口
NGINX_HTTP_PORT="8082" # 使用8082端口
NGINX_HTTPS_PORT="8443" # 使用8443而不是443

# 容器名前缀（避免冲突）
CONTAINER_PREFIX="mrdoc-safe"

# 服务模式
USE_EXTERNAL_MYSQL="false"
USE_EXTERNAL_REDIS="false"
EXTERNAL_MYSQL_HOST=""
EXTERNAL_MYSQL_PORT=""
EXTERNAL_MYSQL_USER=""
EXTERNAL_MYSQL_PASSWORD=""
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
    print_title "MrDoc 安全部署脚本"
    echo -e "${BLUE}🛡️ 避免与现有服务冲突的安全部署方案${NC}"
    echo
    echo -e "${GREEN}安全特性：${NC}"
    echo -e "  ✅ 自动检测端口冲突"
    echo -e "  ✅ 支持外部MySQL/Redis服务"
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

    if ! check_port_conflict $MYSQL_PORT "MySQL"; then
        conflicts_found=1
    fi

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

    if ! check_container_conflict "${CONTAINER_PREFIX}-mysql"; then
        conflicts_found=1
    fi

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

    echo -e "${YELLOW}由于检测到现有服务，建议复用外部MySQL和Redis${NC}"
    echo

    # MySQL配置
    read -p "是否使用外部MySQL服务? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_EXTERNAL_MYSQL="true"
        read -p "MySQL主机地址 [localhost]: " EXTERNAL_MYSQL_HOST
        EXTERNAL_MYSQL_HOST=${EXTERNAL_MYSQL_HOST:-localhost}

        read -p "MySQL端口 [3306]: " EXTERNAL_MYSQL_PORT
        EXTERNAL_MYSQL_PORT=${EXTERNAL_MYSQL_PORT:-3306}

        read -p "MySQL用户名: " EXTERNAL_MYSQL_USER
        read -p "MySQL密码: " EXTERNAL_MYSQL_PASSWORD

        # 测试连接
        print_message "测试MySQL连接..."
        if command -v mysql >/dev/null 2>&1; then
            if mysql -h"$EXTERNAL_MYSQL_HOST" -P"$EXTERNAL_MYSQL_PORT" -u"$EXTERNAL_MYSQL_USER" -p"$EXTERNAL_MYSQL_PASSWORD" -e "SELECT 1" 2>/dev/null; then
                print_success "MySQL连接测试成功"
            else
                print_warning "MySQL连接测试失败，请检查配置"
            fi
        else
            print_warning "未安装mysql客户端，无法测试连接"
        fi
    fi

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

        if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
            read -p "MySQL端口 [${MYSQL_PORT}]: " input_mysql_port
            MYSQL_PORT=${input_mysql_port:-$MYSQL_PORT}
        fi

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
    echo
    echo -e "${BLUE}端口配置：${NC}"
    echo -e "  📱 MrDoc应用: ${YELLOW}$MRDOC_PORT${NC}"
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo -e "  🗄️  MySQL: ${YELLOW}$MYSQL_PORT${NC}"
    else
        echo -e "  🗄️  MySQL: ${YELLOW}外部服务 $EXTERNAL_MYSQL_HOST:$EXTERNAL_MYSQL_PORT${NC}"
    fi
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

    # 创建docker-compose.yml
    cat > docker/docker-compose.yml << EOF
version: '3.8'

services:
  # MrDoc 主应用
  ${CONTAINER_PREFIX}-app:
    build:
      context: ..
      dockerfile: Dockerfile
    container_name: ${CONTAINER_PREFIX}-app
    restart: unless-stopped
    ports:
      - "${MRDOC_PORT}:8000"
    volumes:
      - ./media:/app/media
      - ./logs:/app/logs
      - ./static:/app/static
      - ./config:/app/config
    environment:
EOF

    # 数据库环境变量
    if [ "$USE_EXTERNAL_MYSQL" = "true" ]; then
        cat >> docker/docker-compose.yml << EOF
      - DB_HOST=${EXTERNAL_MYSQL_HOST}
      - DB_PORT=${EXTERNAL_MYSQL_PORT}
      - DB_USER=${EXTERNAL_MYSQL_USER}
      - DB_PASSWORD=${EXTERNAL_MYSQL_PASSWORD}
EOF
    else
        cat >> docker/docker-compose.yml << EOF
      - DB_HOST=${CONTAINER_PREFIX}-mysql
      - DB_PORT=3306
      - DB_USER=mrdoc
      - DB_PASSWORD=mrdoc_safe_password_$(date +%s)
EOF
    fi

    # Redis环境变量
    if [ "$USE_EXTERNAL_REDIS" = "true" ]; then
        cat >> docker/docker-compose.yml << EOF
      - REDIS_HOST=${EXTERNAL_REDIS_HOST}
      - REDIS_PORT=${EXTERNAL_REDIS_PORT}
EOF
        if [ -n "$EXTERNAL_REDIS_PASSWORD" ]; then
            echo "      - REDIS_PASSWORD=${EXTERNAL_REDIS_PASSWORD}" >> docker/docker-compose.yml
        fi
    else
        cat >> docker/docker-compose.yml << EOF
      - REDIS_HOST=${CONTAINER_PREFIX}-redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=redis_safe_password_$(date +%s)
EOF
    fi

    # 应用其他环境变量
    cat >> docker/docker-compose.yml << EOF
      - DB_NAME=mrdoc
      - DJANGO_SETTINGS_MODULE=MrDoc.settings
      - DJANGO_SECRET_KEY=django_safe_secret_$(openssl rand -base64 32 | tr -d '=+/')
      - DJANGO_DEBUG=False
      - DJANGO_ALLOWED_HOSTS=*
      - DJANGO_SUPERUSER_USERNAME=admin
      - DJANGO_SUPERUSER_EMAIL=admin@example.com
      - DJANGO_SUPERUSER_PASSWORD=admin123456
      - TZ=Asia/Shanghai
    networks:
      - ${CONTAINER_PREFIX}-network
    depends_on:
EOF

    # 依赖服务
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo "      - ${CONTAINER_PREFIX}-mysql" >> docker/docker-compose.yml
    fi
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo "      - ${CONTAINER_PREFIX}-redis" >> docker/docker-compose.yml
    fi

    # MySQL服务（如果不使用外部）
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        cat >> docker/docker-compose.yml << EOF

  # MySQL 数据库
  ${CONTAINER_PREFIX}-mysql:
    image: mysql:8.0
    container_name: ${CONTAINER_PREFIX}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root_safe_password_$(date +%s)
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: mrdoc_safe_password_$(date +%s)
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_unicode_ci
    volumes:
      - ${CONTAINER_PREFIX}_mysql_data:/var/lib/mysql
    ports:
      - "${MYSQL_PORT}:3306"
    networks:
      - ${CONTAINER_PREFIX}-network
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5
EOF
    fi

    # Redis服务（如果不使用外部）
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        cat >> docker/docker-compose.yml << EOF

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
    command: redis-server --requirepass redis_safe_password_$(date +%s)
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 3s
      retries: 5
EOF
    fi

    # Nginx服务
    cat >> docker/docker-compose.yml << EOF

  # Nginx 反向代理
  ${CONTAINER_PREFIX}-nginx:
    image: nginx:alpine
    container_name: ${CONTAINER_PREFIX}-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_HTTP_PORT}:80"
      - "${NGINX_HTTPS_PORT}:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./static:/var/www/static
      - ./media:/var/www/media
    networks:
      - ${CONTAINER_PREFIX}-network
    depends_on:
      - ${CONTAINER_PREFIX}-app

# 数据卷定义
volumes:
EOF

    # 数据卷
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo "  ${CONTAINER_PREFIX}_mysql_data:" >> docker/docker-compose.yml
    fi
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo "  ${CONTAINER_PREFIX}_redis_data:" >> docker/docker-compose.yml
    fi

    # 网络定义
    cat >> docker/docker-compose.yml << EOF

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

    # 复制部署文件
    if [ ! -d "docker" ]; then
        print_message "复制部署配置..."

        # 从项目根目录使用相对路径到deployment目录
        if [ -d "deployment/docker" ]; then
            cp -r deployment/docker ./
            print_message "已复制docker配置"
        else
            print_warning "docker配置目录不存在，将创建基础配置"
            mkdir -p docker
        fi

        if [ -d "deployment/nginx" ]; then
            cp -r deployment/nginx ./
            print_message "已复制nginx配置"
        else
            print_warning "nginx配置目录不存在，将创建基础配置"
            mkdir -p nginx
        fi

        if [ -d "deployment/config" ]; then
            cp -r deployment/config ./
            print_message "已复制config配置"
        else
            print_warning "config配置目录不存在，将创建基础配置"
            mkdir -p config
        fi
    fi

    # 创建安全的docker配置
    create_safe_docker_compose

    # 构建和启动
    print_title "构建和启动服务"
    docker-compose -f docker/docker-compose.yml build
    docker-compose -f docker/docker-compose.yml up -d

    # 等待服务启动
    print_message "等待服务启动..."
    sleep 30

    # 数据库迁移
    print_message "执行数据库迁移..."
    docker-compose -f docker/docker-compose.yml exec -T ${CONTAINER_PREFIX}-app python manage.py migrate

    # 创建超级用户
    print_message "创建管理员账户..."
    docker-compose -f docker/docker-compose.yml exec -T ${CONTAINER_PREFIX}-app python manage.py shell << 'PYEOF'
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123456')
    print('管理员用户创建成功')
PYEOF

    # 显示部署结果
    print_title "部署完成"
    print_success "MrDoc 安全部署成功！"
    echo
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}✅ 访问地址: ${YELLOW}http://$SERVER_IP:$MRDOC_PORT${NC}"
    echo -e "${GREEN}✅ 管理后台: ${YELLOW}http://$SERVER_IP:$MRDOC_PORT/admin${NC}"
    echo -e "${GREEN}✅ 管理员: ${YELLOW}admin / admin123456${NC}"
    echo
    echo -e "${BLUE}📊 服务端口：${NC}"
    echo -e "  MrDoc应用: $MRDOC_PORT"
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo -e "  MySQL: $MYSQL_PORT"
    fi
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo -e "  Redis: $REDIS_PORT"
    fi
    echo -e "  Nginx: $NGINX_HTTP_PORT"
    echo
    print_message "所有服务使用独立端口，不会与现有服务冲突"
}

# 错误处理
trap 'print_error "部署过程中发生错误"; exit 1' ERR

# 运行主函数
main "$@"