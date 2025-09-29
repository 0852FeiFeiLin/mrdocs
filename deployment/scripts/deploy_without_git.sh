#!/bin/bash

# MrDoc 无网络部署脚本
# 适用于服务器无法访问GitHub的情况
# 需要提前手动上传源码

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
PROJECT_NAME="mrdocs"
PROJECT_DIR="${HOME}/${PROJECT_NAME}"
DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 显示欢迎信息
show_welcome() {
    print_title "MrDoc 无网络部署脚本"
    echo -e "${BLUE}🚀 适用于无GitHub访问权限的服务器${NC}"
    echo
    echo -e "${GREEN}部署流程：${NC}"
    echo "  1. 检查源码完整性"
    echo "  2. 配置Docker环境"
    echo "  3. 生成安全配置"
    echo "  4. 启动所有服务"
    echo "  5. 初始化数据库"
    echo
    echo -e "${YELLOW}注意：请确保已手动上传源码到 $PROJECT_DIR${NC}"
    echo
    read -p "按回车键继续，或Ctrl+C退出..." dummy
}

# 检查前置条件
check_prerequisites() {
    print_title "检查部署前置条件"

    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先运行 ubuntu_prepare.sh"
        exit 1
    fi

    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose未安装，请先运行 ubuntu_prepare.sh"
        exit 1
    fi

    # 检查Docker服务状态
    if ! systemctl is-active --quiet docker; then
        print_error "Docker服务未运行"
        sudo systemctl start docker
        print_message "Docker服务已启动"
    fi

    # 检查用户是否在docker组中
    if ! groups | grep -q docker; then
        print_warning "当前用户不在docker组中，请重新登录或运行："
        echo "sudo usermod -aG docker $USER"
        echo "然后重新登录"
        exit 1
    fi

    print_success "前置条件检查通过"
}

# 检查源码
check_source_code() {
    print_title "检查源码完整性"

    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "项目目录不存在: $PROJECT_DIR"
        print_message "请先执行以下步骤："
        echo "  1. 在本地打包源码: tar -czf mrdocs-source.tar.gz ."
        echo "  2. 上传到服务器: scp mrdocs-source.tar.gz user@server:~/"
        echo "  3. 解压源码: mkdir -p $PROJECT_DIR && tar -xzf ~/mrdocs-source.tar.gz -C $PROJECT_DIR"
        exit 1
    fi

    # 检查关键Django文件
    if [ ! -f "$PROJECT_DIR/manage.py" ]; then
        print_error "未找到Django项目文件 manage.py"
        print_message "请确保源码已正确解压到: $PROJECT_DIR"
        exit 1
    fi

    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        print_error "未找到依赖文件 requirements.txt"
        exit 1
    fi

    # 检查是否有mysqlclient依赖
    if ! grep -q "mysqlclient" "$PROJECT_DIR/requirements.txt"; then
        print_warning "requirements.txt中未找到mysqlclient依赖"
        print_message "添加mysqlclient到requirements.txt"
        echo "mysqlclient" >> "$PROJECT_DIR/requirements.txt"
    fi

    print_success "源码检查完成"
    print_message "项目目录: $PROJECT_DIR"
    print_message "源码文件数量: $(find $PROJECT_DIR -name '*.py' | wc -l) 个Python文件"
}

# 准备部署环境
prepare_deployment() {
    print_title "准备部署环境"

    # 切换到项目目录
    cd "$PROJECT_DIR"

    # 复制部署配置文件
    print_message "复制Docker配置..."
    cp -r "$DEPLOYMENT_DIR/docker" ./

    print_message "复制应用配置..."
    cp -r "$DEPLOYMENT_DIR/config" ./

    print_message "复制Nginx配置..."
    cp -r "$DEPLOYMENT_DIR/nginx" ./

    # 创建必要的目录
    print_message "创建必要目录..."
    mkdir -p data/mysql data/redis logs/nginx media static

    print_success "部署环境准备完成"
}

# 生成安全配置
generate_security_config() {
    print_title "生成安全配置"

    # 生成随机密码
    print_message "生成数据库密码..."
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)

    print_message "生成Redis密码..."
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)

    print_message "生成Django Secret Key..."
    DJANGO_SECRET=$(openssl rand -base64 50 | tr -d "=+/")

    print_success "安全配置生成完成"

    # 更新docker-compose.yml中的密码
    print_message "更新Docker配置文件..."
    sed -i "s/root_password_2024/$MYSQL_ROOT_PASSWORD/g" docker/docker-compose.yml
    sed -i "s/mrdoc_password_2024/$MYSQL_PASSWORD/g" docker/docker-compose.yml
    sed -i "s/redis_password_2024/$REDIS_PASSWORD/g" docker/docker-compose.yml
    sed -i "s/your-very-secret-key-change-in-production-2024/$DJANGO_SECRET/g" docker/docker-compose.yml

    # 保存密码到文件（仅root可读）
    cat > .env << EOF
# MrDoc 部署配置 - $(date)
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
DJANGO_SECRET_KEY=$DJANGO_SECRET
PROJECT_DIR=$PROJECT_DIR
EOF
    chmod 600 .env

    print_message "配置文件更新完成"
}

# 构建和启动服务
deploy_services() {
    print_title "构建和启动Docker服务"

    # 停止可能存在的旧容器
    print_message "清理旧容器..."
    docker-compose -f docker/docker-compose.yml down 2>/dev/null || true

    # 清理旧镜像（可选）
    print_message "清理未使用的镜像..."
    docker image prune -f 2>/dev/null || true

    # 构建MrDoc镜像
    print_message "构建MrDoc镜像（这可能需要几分钟）..."
    docker-compose -f docker/docker-compose.yml build --no-cache mrdoc

    # 拉取其他镜像
    print_message "拉取MySQL和Redis镜像..."
    docker-compose -f docker/docker-compose.yml pull mysql redis nginx

    # 启动所有服务
    print_message "启动所有服务..."
    docker-compose -f docker/docker-compose.yml up -d

    # 等待服务启动
    print_message "等待服务启动（60秒）..."
    for i in {1..12}; do
        echo -n "."
        sleep 5
    done
    echo

    print_success "Docker服务启动完成"
}

# 初始化数据库
initialize_database() {
    print_title "初始化数据库"

    # 等待数据库完全启动
    print_message "等待MySQL数据库启动..."
    for i in {1..30}; do
        if docker-compose -f docker/docker-compose.yml exec -T mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT 1" &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo

    # 执行数据库迁移
    print_message "执行数据库迁移..."
    docker-compose -f docker/docker-compose.yml exec -T mrdoc python manage.py migrate

    # 收集静态文件
    print_message "收集静态文件..."
    docker-compose -f docker/docker-compose.yml exec -T mrdoc python manage.py collectstatic --noinput

    # 创建超级用户
    print_message "创建管理员账户..."
    docker-compose -f docker/docker-compose.yml exec -T mrdoc python manage.py shell << 'PYEOF'
from django.contrib.auth.models import User
import os

# 检查是否已存在管理员用户
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(
        username='admin',
        email='admin@example.com',
        password='admin123456'
    )
    print('管理员用户创建成功')
else:
    print('管理员用户已存在')
PYEOF

    print_success "数据库初始化完成"
}

# 创建管理脚本
create_management_scripts() {
    print_title "创建管理脚本"

    # 启动脚本
    cat > start.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "🚀 启动MrDoc服务..."
docker-compose -f docker/docker-compose.yml up -d
echo "✅ 服务启动完成"
docker-compose -f docker/docker-compose.yml ps
SCRIPT_EOF

    # 停止脚本
    cat > stop.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "🛑 停止MrDoc服务..."
docker-compose -f docker/docker-compose.yml down
echo "✅ 服务已停止"
SCRIPT_EOF

    # 重启脚本
    cat > restart.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "🔄 重启MrDoc服务..."
docker-compose -f docker/docker-compose.yml restart
echo "✅ 服务重启完成"
docker-compose -f docker/docker-compose.yml ps
SCRIPT_EOF

    # 日志查看脚本
    cat > logs.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "📋 选择要查看的服务日志："
echo "1) MrDoc应用"
echo "2) MySQL数据库"
echo "3) Redis缓存"
echo "4) Nginx代理"
echo "5) 所有服务"

read -p "请选择 [1-5]: " choice

case $choice in
    1) docker-compose -f docker/docker-compose.yml logs -f mrdoc ;;
    2) docker-compose -f docker/docker-compose.yml logs -f mysql ;;
    3) docker-compose -f docker/docker-compose.yml logs -f redis ;;
    4) docker-compose -f docker/docker-compose.yml logs -f nginx ;;
    5) docker-compose -f docker/docker-compose.yml logs -f ;;
    *) echo "无效选择" ;;
esac
SCRIPT_EOF

    # 备份脚本
    cat > backup.sh << 'SCRIPT_EOF'
#!/bin/bash
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 备份MrDoc数据..."

# 备份数据库
echo "备份MySQL数据库..."
source .env
docker-compose -f docker/docker-compose.yml exec -T mysql mysqldump \
    -uroot -p$MYSQL_ROOT_PASSWORD mrdoc > "$BACKUP_DIR/database.sql"

# 备份媒体文件
echo "备份媒体文件..."
cp -r media "$BACKUP_DIR/"

# 备份配置文件
echo "备份配置文件..."
cp .env "$BACKUP_DIR/"
cp -r config "$BACKUP_DIR/"

echo "✅ 备份完成: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
SCRIPT_EOF

    # 状态检查脚本
    cat > status.sh << 'SCRIPT_EOF'
#!/bin/bash
echo "📊 MrDoc服务状态："
echo "==================="

# 显示容器状态
docker-compose -f docker/docker-compose.yml ps

echo
echo "📊 系统资源使用："
echo "=================="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo
echo "🌐 服务端点："
echo "============="
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "MrDoc访问地址: http://$SERVER_IP:8000"
echo "管理后台: http://$SERVER_IP:8000/admin"
echo "数据库连接: $SERVER_IP:3306"
echo "Redis连接: $SERVER_IP:6379"
SCRIPT_EOF

    # 设置执行权限
    chmod +x *.sh

    print_success "管理脚本创建完成"
}

# 显示部署结果
show_deployment_result() {
    print_title "部署完成"

    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    # 加载配置
    source .env

    print_success "MrDoc 已成功部署！"
    echo
    echo -e "${BLUE}📋 服务信息：${NC}"
    echo "  🌐 访问地址: http://$SERVER_IP:8000"
    echo "  🔐 管理后台: http://$SERVER_IP:8000/admin"
    echo "  👤 管理员账户: admin"
    echo "  🔑 管理员密码: admin123456"
    echo "  🏠 项目目录: $PROJECT_DIR"
    echo
    echo -e "${BLUE}📋 数据库信息：${NC}"
    echo "  📊 MySQL端口: 3306"
    echo "  👤 数据库用户: mrdoc"
    echo "  🔑 数据库密码: $MYSQL_PASSWORD"
    echo
    echo -e "${BLUE}🛠️ 管理命令：${NC}"
    echo "  ./start.sh    - 启动所有服务"
    echo "  ./stop.sh     - 停止所有服务"
    echo "  ./restart.sh  - 重启所有服务"
    echo "  ./logs.sh     - 查看服务日志"
    echo "  ./backup.sh   - 备份数据"
    echo "  ./status.sh   - 查看服务状态"
    echo
    echo -e "${BLUE}📁 重要文件：${NC}"
    echo "  .env          - 环境变量配置"
    echo "  docker/       - Docker配置文件"
    echo "  config/       - 应用配置文件"
    echo "  logs/         - 日志文件目录"
    echo "  backups/      - 备份文件目录"
    echo
    echo -e "${YELLOW}⚠️  安全提醒：${NC}"
    echo "  - 请及时修改默认管理员密码"
    echo "  - 生产环境建议配置SSL证书"
    echo "  - 定期备份重要数据"
    echo "  - .env文件包含敏感信息，注意保护"
    echo
    echo -e "${GREEN}🎉 开始使用你的MrDoc知识库吧！${NC}"

    # 显示容器状态
    echo
    print_title "当前服务状态"
    docker-compose -f docker/docker-compose.yml ps
}

# 主函数
main() {
    # 检查是否为root用户
    if [ "$EUID" -eq 0 ]; then
        print_error "请不要使用root用户运行此脚本"
        exit 1
    fi

    # 执行部署流程
    show_welcome
    check_prerequisites
    check_source_code
    prepare_deployment
    generate_security_config
    deploy_services
    initialize_database
    create_management_scripts
    show_deployment_result

    print_success "部署流程全部完成！"
}

# 错误处理
trap 'print_error "部署过程中发生错误，请检查上面的错误信息"; exit 1' ERR

# 运行主函数
main "$@"