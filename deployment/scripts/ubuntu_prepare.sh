#!/bin/bash

# MrDoc Ubuntu 服务器环境准备脚本
# 适用于 Ubuntu 20.04+ 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "建议使用普通用户并配置sudo权限运行此脚本"
    fi
}

# 检测系统版本
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
        print_message "检测到系统: $OS $VERSION"

        if [[ "$ID" != "ubuntu" ]]; then
            print_error "此脚本仅支持 Ubuntu 系统"
            exit 1
        fi

        if [[ "${VERSION_ID}" < "20.04" ]]; then
            print_warning "建议使用 Ubuntu 20.04 或更高版本"
        fi
    else
        print_error "无法检测系统版本"
        exit 1
    fi
}

# 更新系统
update_system() {
    print_title "更新系统软件包"

    sudo apt-get update -y
    sudo apt-get upgrade -y
    sudo apt-get install -y curl wget git vim unzip

    print_message "系统更新完成"
}

# 安装 Docker
install_docker() {
    print_title "安装 Docker"

    # 检查是否已安装
    if command -v docker &> /dev/null; then
        print_message "Docker 已安装: $(docker --version)"
        return 0
    fi

    print_message "开始安装 Docker..."

    # 移除旧版本
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

    # 安装依赖
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # 添加 Docker GPG 密钥
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 添加 Docker 仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

    # 启动 Docker 服务
    sudo systemctl start docker
    sudo systemctl enable docker

    # 添加当前用户到 docker 组
    sudo usermod -aG docker $USER

    print_message "Docker 安装完成: $(docker --version)"
}

# 安装 Docker Compose
install_docker_compose() {
    print_title "安装 Docker Compose"

    # 检查是否已安装
    if command -v docker-compose &> /dev/null; then
        print_message "Docker Compose 已安装: $(docker-compose --version)"
        return 0
    fi

    # 获取最新版本号
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

    # 下载并安装
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # 创建软链接
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    print_message "Docker Compose 安装完成: $(docker-compose --version)"
}

# 配置防火墙
configure_firewall() {
    print_title "配置防火墙"

    # 检查是否启用了 UFW
    if command -v ufw &> /dev/null; then
        sudo ufw --force enable

        # 允许 SSH
        sudo ufw allow ssh
        sudo ufw allow 22/tcp

        # 允许 HTTP/HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp

        # 允许 MrDoc 端口（可选）
        # sudo ufw allow 8000/tcp

        sudo ufw reload
        print_message "防火墙配置完成"
    else
        print_warning "UFW 未安装，跳过防火墙配置"
    fi
}

# 创建项目目录
create_project_directory() {
    print_title "创建项目目录"

    PROJECT_DIR="${HOME}/mrdoc-server"

    if [ -d "$PROJECT_DIR" ]; then
        print_warning "项目目录已存在: $PROJECT_DIR"
        read -p "是否删除并重新创建? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            print_message "使用现有目录: $PROJECT_DIR"
            return 0
        fi
    fi

    mkdir -p "$PROJECT_DIR"/{config,data,logs,media,static}
    cd "$PROJECT_DIR"

    print_message "项目目录创建完成: $PROJECT_DIR"
    echo "$PROJECT_DIR" > /tmp/mrdoc_project_path
}

# 优化系统参数
optimize_system() {
    print_title "系统优化"

    # 增加文件描述符限制
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

    # 优化内核参数
    sudo tee -a /etc/sysctl.conf << EOF

# MrDoc 优化参数
vm.max_map_count=262144
vm.swappiness=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF

    # 应用内核参数
    sudo sysctl -p

    print_message "系统优化完成"
}

# 安装必要工具
install_tools() {
    print_title "安装必要工具"

    sudo apt-get install -y \
        htop \
        iotop \
        nethogs \
        tree \
        jq \
        sqlite3 \
        mysql-client \
        nginx \
        certbot \
        python3-certbot-nginx

    print_message "工具安装完成"
}

# 显示安装结果
show_result() {
    print_title "安装完成"

    PROJECT_DIR=$(cat /tmp/mrdoc_project_path 2>/dev/null || echo "${HOME}/mrdoc-server")

    echo -e "${GREEN}🎉 MrDoc 环境准备完成！${NC}"
    echo
    echo -e "${BLUE}📋 系统信息:${NC}"
    echo -e "   OS: $(lsb_release -ds)"
    echo -e "   Docker: $(docker --version)"
    echo -e "   Docker Compose: $(docker-compose --version)"
    echo -e "   项目目录: $PROJECT_DIR"
    echo
    echo -e "${BLUE}📋 下一步操作:${NC}"
    echo -e "   1. 重新登录或运行: newgrp docker"
    echo -e "   2. 进入项目目录: cd $PROJECT_DIR"
    echo -e "   3. 下载 MrDoc 部署文件"
    echo -e "   4. 运行部署脚本"
    echo
    echo -e "${YELLOW}📝 注意事项:${NC}"
    echo -e "   - 请确保服务器有足够的内存 (推荐 2GB+)"
    echo -e "   - 请确保防火墙已正确配置"
    echo -e "   - 建议配置域名和 SSL 证书"
    echo
}

# 主函数
main() {
    print_title "MrDoc Ubuntu 环境准备脚本"

    check_root
    detect_system
    update_system
    install_docker
    install_docker_compose
    configure_firewall
    create_project_directory
    optimize_system
    install_tools
    show_result

    print_message "环境准备脚本执行完成！"
}

# 运行主函数
main "$@"