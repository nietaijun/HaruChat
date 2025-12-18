#!/bin/bash

# HaruChat 完整部署脚本
# 包含: haruServer (后端) + haruWeb (前端) + Nginx (代理)

set -e

echo "🚀 开始部署 HaruChat..."

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "⚠️  未找到 .env 文件，从模板创建..."
    cp env.template.txt .env
    echo "📝 请编辑 .env 文件配置 API Keys"
    exit 1
fi

# 检查 SSL 证书
if [ ! -d ssl ] || [ ! -f ssl/fullchain.pem ] || [ ! -f ssl/privkey.pem ]; then
    echo "⚠️  未找到 SSL 证书，创建 ssl 目录..."
    mkdir -p ssl
    echo "📝 请将 SSL 证书放入 ssl 目录:"
    echo "   - ssl/fullchain.pem"
    echo "   - ssl/privkey.pem"
    echo ""
    echo "可使用 certbot 获取免费证书:"
    echo "   certbot certonly --standalone -d www.nietaijun.cloud"
    exit 1
fi

# 检查 haruWeb 目录
if [ ! -d ../haruWeb ]; then
    echo "❌ 未找到 ../haruWeb 目录"
    exit 1
fi

# 停止旧容器
echo "🛑 停止旧服务..."
docker-compose down || true

# 构建并启动
echo "🔨 构建 Docker 镜像..."
docker-compose build --no-cache

echo "🚀 启动服务..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "📊 服务状态:"
docker-compose ps

# 测试健康检查
echo ""
echo "🔍 健康检查:"
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ 后端 API: 正常"
else
    echo "⚠️  后端 API: 可能仍在启动中"
fi

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ 前端 Web: 正常"
else
    echo "⚠️  前端 Web: 可能仍在启动中"
fi

echo ""
echo "✅ 部署完成!"
echo ""
echo "📡 访问地址:"
echo "   - 主页: https://www.nietaijun.cloud"
echo "   - API:  https://www.nietaijun.cloud/api/"
echo ""
echo "📋 常用命令:"
echo "   查看日志: docker-compose logs -f"
echo "   重启服务: docker-compose restart"
echo "   停止服务: docker-compose down"
