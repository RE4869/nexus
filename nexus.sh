#!/bin/bash
set -e

CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_FILE="/root/nexus.log"

# 检查 Docker 是否安装
function check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "检测到未安装 Docker，正在安装..."
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce
        systemctl enable docker
        systemctl start docker
    fi
}

# 构建docker镜像函数
function build_image() {
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    cat > Dockerfile <<EOF
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \\
    curl \\
    screen \\
    bash \\
    ca-certificates \\
    && rm -rf /var/lib/apt/lists/*

# 下载并安装 nexus-network 二进制文件
RUN curl -L https://github.com/nexus-xyz/nexus-cli/releases/latest/download/nexus-network-x86_64-unknown-linux-gnu.tar.gz -o nexus.tar.gz && \\
    tar -xzf nexus.tar.gz && \\
    mv nexus-network /usr/local/bin/nexus-network && \\
    chmod +x /usr/local/bin/nexus-network && \\
    rm -rf nexus.tar.gz

WORKDIR /root

EOF

    docker build -t "$IMAGE_NAME" .

    cd -
    rm -rf "$WORKDIR"
}

# 启动容器（运行时输入 node-id）
function run_container() {
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo "检测到旧容器 $CONTAINER_NAME，先删除..."
        docker rm -f "$CONTAINER_NAME"
    fi

    read -rp "请输入你的 node-id: " NODE_ID
    if [ -z "$NODE_ID" ]; then
        echo "node-id 不能为空，取消启动。"
        return
    fi

    docker run -d --name "$CONTAINER_NAME" --restart unless-stopped "$IMAGE_NAME" \
        nexus-network run --node-id "$NODE_ID"

    echo "容器已启动！"
    echo "使用以下命令查看日志："
    echo "  docker logs -f $CONTAINER_NAME"
}

# 停止并卸载容器和镜像、删除日志
function uninstall_node() {
    echo "停止并删除容器 $CONTAINER_NAME..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || echo "容器不存在或已停止"

    echo "删除镜像 $IMAGE_NAME..."
    docker rmi "$IMAGE_NAME" 2>/dev/null || echo "镜像不存在或已删除"

    if [ -f "$LOG_FILE" ]; then
        echo "删除日志文件 $LOG_FILE ..."
        rm -f "$LOG_FILE"
    else
        echo "日志文件不存在：$LOG_FILE"
    fi

    echo "节点已卸载完成。"
}

# 主菜单
while true; do
    clear
    echo "脚本由哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
    echo "如有问题，可联系推特，仅此只有一个号"
    echo "========== Nexus 节点管理 =========="
    echo "1. 安装并启动节点"
    echo "2. 显示节点 ID"
    echo "3. 停止并卸载节点"
    echo "4. 查看节点日志"
    echo "5. 退出"
    echo "==================================="

    read -rp "请输入选项(1-5): " choice

    case $choice in
        1)
            check_docker
            echo "开始构建镜像..."
            build_image
            run_container
            read -p "按任意键返回菜单"
            ;;
        2)
            if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
                echo "节点 ID:"
                docker exec "$CONTAINER_NAME" cat /root/.nexus/node-id || echo "无法读取节点 ID"
            else
                echo "容器未运行，请先安装并启动节点（选项1）"
            fi
            read -p "按任意键返回菜单"
            ;;
        3)
            uninstall_node
            read -p "按任意键返回菜单"
            ;;
        4)
            if docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
                echo "查看日志，按 Ctrl+C 退出日志查看"
                docker logs -f "$CONTAINER_NAME"
            else
                echo "容器未运行，请先安装并启动节点（选项1）"
                read -p "按任意键返回菜单"
            fi
            ;;
        5)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入。"
            read -p "按任意键返回菜单"
            ;;
    esac
done
