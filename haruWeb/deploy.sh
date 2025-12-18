#!/bin/bash
# HaruWeb 部署脚本

set -e

echo "🌸 HaruWeb 部署"
echo "==============="

echo "📦 构建镜像..."
docker-compose build

echo "🔄 重启服务..."
docker-compose down 2>/dev/null || true
docker-compose up -d

sleep 5

if curl -s http://localhost:3000 > /dev/null; then
    echo ""
    echo "✅ 部署成功！"
    echo "📡 http://localhost:3000"
else
    echo "❌ 启动失败"
    docker-compose logs --tail=20
fi

