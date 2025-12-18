#!/bin/bash
# HaruChat Server 部署脚本

set -e

echo "🚀 HaruChat Server 部署"
echo "======================"

# 检查配置
if [ ! -f .env ]; then
    echo "❌ 请先配置 .env 文件"
    echo "   cp env.template.txt .env && nano .env"
    exit 1
fi

if [ ! -d ssl ] || [ ! -f ssl/fullchain.pem ]; then
    echo "⚠️  SSL 证书未配置，将只启动 API 服务"
    echo "   请将证书放到 ssl/ 目录"
    echo ""
    docker-compose up -d haruserver
else
    echo "📦 启动完整服务（含 Nginx）..."
    docker-compose up -d
fi

sleep 3

if curl -s http://localhost:8000/health | grep -q "healthy"; then
    echo ""
    echo "✅ 部署成功！"
    echo "📡 API: http://localhost:8000"
    echo "📡 域名: https://www.nietaijun.cloud"
else
    echo "❌ 启动失败"
    docker-compose logs --tail=20
fi

