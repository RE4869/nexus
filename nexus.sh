#!/bin/bash

set -e

APP_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
CONTAINER_NAME="nexus-node"

# 创建 Dockerfile
cat > Dockerfile <<'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PROVER_ID_FILE=/root/.nexus/node-id

RUN apt-get update && apt-get install -y \
    curl screen bash ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/nexus-xyz/nexus-cli/releases/latest/download/nexus-network-x86_64-unknown-linux-gnu.tar.gz \
    -o nexus.tar.gz && \
    tar -xzf nexus.tar.gz && \
    mv nexus-network /usr/local/bin/nexus-network && \
    chmod +x /usr/local/bin/nexus-network && \
    rm -rf nexus.tar.gz

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

# 创建 entrypoint.sh
cat > entrypoint.sh <<'EOF'
#!/bin/bash

set -e

mkdir -p /root/.nexus

if [ ! -f "$PROVER_ID_FILE" ]; then
    node_id=$(shuf -i 1000000-9999999 -n 1)
    echo "$node_id" > "$PROVER_ID_FILE"
    echo "生成新的 node-id: $node_id"
else
    node_id=$(cat "$PROVER_ID_FILE")
    echo "使用的 node-id: $node_id"
fi

if ! command -v nexus-network &> /dev/null; then
    echo "错误：nexus-network 未安装或不可用"
    exit 1
fi

nexus-network \
    --node-id "$node_id" \
    --validator-endpoint "https://validators.nexus.xyz" \
    --chain-id "celestia" \
    --log-level "info"
EOF

# 构建镜像
echo "🔨 正在构建 Docker 镜像..."
docker build -t $IMAGE_NAME .

# 移除已有容器
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "🧹 移除旧容器..."
    docker rm -f $CONTAINER_NAME
fi

# 启动新容器
echo "🚀 启动新节点容器..."
docker run -d --name $CONTAINER_NAME --restart unless-stopped $IMAGE_NAME

# 提示
echo "✅ 节点容器已启动，请稍等片刻后通过以下命令查看日志："
echo "   docker logs -f $CONTAINER_NAME"
