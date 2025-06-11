#!/bin/bash

set -e

IMAGE_NAME="nexus-node"
CONTAINER_NAME="nexus-node"
DOCKERFILE_URL="https://raw.githubusercontent.com/nexus-xyz/nexus-cli/main/Dockerfile"

install_docker() {
    echo "🚀 安装 Docker 中..."
    curl -fsSL https://get.docker.com | bash
    echo "✅ Docker 安装完成"
}

build_image() {
    echo "🔨 正在构建 Docker 镜像..."

    cat > Dockerfile <<EOF
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y curl git screen bash ca-certificates build-essential pkg-config libssl-dev clang cmake \
    && curl https://sh.rustup.rs -sSf | bash -s -- -y \
    && /root/.cargo/bin/rustc --version

ENV PATH="/root/.cargo/bin:\$PATH"

RUN git clone https://github.com/nexus-xyz/nexus-cli.git && \
    cd nexus-cli && \
    cargo build --release && \
    cp target/release/nexus-network /usr/local/bin/ && \
    chmod +x /usr/local/bin/nexus-network && \
    cd .. && rm -rf nexus-cli

WORKDIR /root
EOF

    docker build -t $IMAGE_NAME .
    rm -f Dockerfile
    echo "✅ 镜像构建完成：$IMAGE_NAME"
}

run_container() {
    echo "🟢 启动 Nexus 节点容器..."

    read -p "请输入你的 node-id: " NODE_ID
    docker run -d --name $CONTAINER_NAME --restart unless-stopped $IMAGE_NAME nexus-network run --node-id $NODE_ID

    echo "✅ 容器已启动，使用以下命令查看日志："
    echo "   docker logs -f $CONTAINER_NAME"
}

show_logs() {
    docker logs -f $CONTAINER_NAME
}

show_node_id() {
    echo "📍 当前容器命令:"
    docker exec $CONTAINER_NAME ps -ef | grep nexus-network
}

menu() {
    while true; do
        echo -e "\n========== Nexus 节点管理 =========="
        echo "1. 安装 Docker"
        echo "2. 构建镜像"
        echo "3. 运行容器"
        echo "4. 查看容器日志"
        echo "5. 显示容器运行参数"
        echo "6. 退出"
        read -p "请输入选项 [1-6]: " choice
        case "$choice" in
            1) install_docker ;;
            2) build_image ;;
            3) run_container ;;
            4) show_logs ;;
            5) show_node_id ;;
            6) exit 0 ;;
            *) echo "无效选项，请重新输入" ;;
        esac
    done
}

menu
