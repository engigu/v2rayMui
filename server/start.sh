#!/bin/bash

echo "Starting V2Ray MUI..."

# 检查 Go 是否安装
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed or not in PATH"
    exit 1
fi

# 检查 Node.js 是否安装
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH"
    exit 1
fi

# 安装后端依赖
echo "Installing backend dependencies..."
go mod tidy
if [ $? -ne 0 ]; then
    echo "Error: Failed to install backend dependencies"
    exit 1
fi

# 安装前端依赖
echo "Installing frontend dependencies..."
cd web
npm install
if [ $? -ne 0 ]; then
    echo "Error: Failed to install frontend dependencies"
    exit 1
fi

# 构建前端
echo "Building frontend..."
npm run build
if [ $? -ne 0 ]; then
    echo "Error: Failed to build frontend"
    exit 1
fi

cd ..

# 创建必要的目录
mkdir -p bin data logs

# 启动后端
echo "Starting backend server..."
go run main.go &
BACKEND_PID=$!

# 等待后端启动
sleep 3

# 打开浏览器
echo "Opening browser..."
if command -v xdg-open &> /dev/null; then
    xdg-open http://localhost:3000
elif command -v open &> /dev/null; then
    open http://localhost:3000
fi

echo "V2Ray MUI started successfully!"
echo "Backend: http://localhost:58080"
echo "Frontend: http://localhost:3000"
echo "Press Ctrl+C to stop"

# 等待用户中断
trap "kill $BACKEND_PID; exit" INT
wait
