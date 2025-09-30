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
PROJECT_NAME="mrdocs"
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
CONTAINER_PREFIX="mrdocs-safe"

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
      - ../config:/app/config
    environment:
EOF

    # 数据库环境变量
    if [ "$USE_EXTERNAL_MYSQL" = "true" ]; then
        cat >> deployment/docker/docker-compose.yml << EOF
      - DB_HOST=${EXTERNAL_MYSQL_HOST}
      - DB_PORT=${EXTERNAL_MYSQL_PORT}
      - DB_USER=${EXTERNAL_MYSQL_USER}
      - DB_PASSWORD=${EXTERNAL_MYSQL_PASSWORD}
EOF
    else
        cat >> deployment/docker/docker-compose.yml << EOF
      - DB_HOST=${CONTAINER_PREFIX}-mysql
      - DB_PORT=3306
      - DB_USER=mrdoc
      - DB_PASSWORD=mrdocpassword123
EOF
    fi

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
      - DB_NAME=mrdoc
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

    # 依赖服务
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo "      - ${CONTAINER_PREFIX}-mysql" >> deployment/docker/docker-compose.yml
    fi
    if [ "$USE_EXTERNAL_REDIS" = "false" ]; then
        echo "      - ${CONTAINER_PREFIX}-redis" >> deployment/docker/docker-compose.yml
    fi

    # MySQL服务（如果不使用外部）
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        cat >> deployment/docker/docker-compose.yml << EOF

  # MySQL 数据库
  ${CONTAINER_PREFIX}-mysql:
    image: mysql:5.7
    container_name: ${CONTAINER_PREFIX}-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword123
      MYSQL_DATABASE: mrdoc
      MYSQL_USER: mrdoc
      MYSQL_PASSWORD: mrdocpassword123
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_unicode_ci
    volumes:
      - ${CONTAINER_PREFIX}_mysql_data:/var/lib/mysql
      - ../docker/mysql-init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    ports:
      - "${MYSQL_PORT}:3306"
    networks:
      - ${CONTAINER_PREFIX}-network
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5
EOF
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
EOF

    # 数据卷
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        echo "  ${CONTAINER_PREFIX}_mysql_data:" >> deployment/docker/docker-compose.yml
    fi
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

    # 创建MySQL初始化脚本
    cat > deployment/docker/mysql-init.sql << 'EOF'
-- MySQL初始化脚本
-- 确保mrdoc用户有正确的权限

-- 创建数据库
CREATE DATABASE IF NOT EXISTS mrdoc CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 确保用户权限（MySQL 5.7会自动创建MYSQL_USER，这里补充权限）
GRANT ALL PRIVILEGES ON *.* TO 'mrdoc'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON mrdoc.* TO 'mrdoc'@'%';
FLUSH PRIVILEGES;
EOF

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

echo_info "🚀 启动 MrDoc 应用..."

# 显示环境变量调试信息
echo_info "环境配置:"
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=$DB_PORT"
echo "  DB_NAME=$DB_NAME"
echo "  DB_USER=$DB_USER"
echo "  REDIS_HOST=$REDIS_HOST"

# 使用Python检查数据库连接
echo_info "⏳ 等待数据库服务启动..."
python << 'PYTHON_EOF'
import time
import os
import sys

try:
    import MySQLdb
except ImportError:
    print("[ERROR] MySQLdb模块未安装")
    sys.exit(1)

max_retries = 30
retry_count = 0
db_host = os.environ.get('DB_HOST', 'localhost')
db_user = os.environ.get('DB_USER', 'mrdoc')
db_password = os.environ.get('DB_PASSWORD', 'mrdocpassword123')
db_port = int(os.environ.get('DB_PORT', '3306'))

while retry_count < max_retries:
    try:
        conn = MySQLdb.connect(
            host=db_host,
            user=db_user,
            passwd=db_password,
            port=db_port,
            connect_timeout=5
        )
        conn.close()
        print("[INFO] ✅ 数据库连接成功!")
        break
    except Exception as e:
        retry_count += 1
        print(f"[WARN] 等待数据库 ({retry_count}/{max_retries})...")
        time.sleep(5)

if retry_count == max_retries:
    print(f"[ERROR] 无法连接到数据库 {db_host}:{db_port}")
    sys.exit(1)
PYTHON_EOF

cd /app

# 创建数据库
echo_info "📊 确保数据库存在..."
python << 'PYTHON_EOF'
import os
import MySQLdb

try:
    conn = MySQLdb.connect(
        host=os.environ.get('DB_HOST', 'localhost'),
        user=os.environ.get('DB_USER', 'mrdoc'),
        passwd=os.environ.get('DB_PASSWORD', 'mrdocpassword123'),
        port=int(os.environ.get('DB_PORT', '3306'))
    )
    cursor = conn.cursor()
    db_name = os.environ.get('DB_NAME', 'mrdoc')
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
    conn.commit()
    conn.close()
    print(f"[INFO] 数据库 {db_name} 已准备就绪")
except Exception as e:
    print(f"[WARN] {e}")
PYTHON_EOF

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
chmod -R 755 /app/media /app/static

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

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc g++ pkg-config \
    default-libmysqlclient-dev \
    default-mysql-client \
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
RUN mkdir -p /app/logs /app/media /app/static /app/config

# 安装Python依赖
RUN pip install --no-cache-dir --user -r requirements.txt && \
    pip install --no-cache-dir --user \
    cryptography==41.0.7 \
    django-filter==23.5 \
    gunicorn==21.2.0 \
    mysqlclient==2.2.0

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

    # 检查MySQL是否就绪
    if [ "$USE_EXTERNAL_MYSQL" = "false" ]; then
        print_message "检查MySQL服务状态..."
        for i in {1..30}; do
            if docker exec ${CONTAINER_PREFIX}-mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
                print_success "MySQL服务已就绪"
                break
            fi
            echo -n "."
            sleep 2
        done
        echo
    fi

    # 等待应用容器完全启动（entrypoint.sh会自动执行迁移和创建用户）
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