@echo off
echo Starting V2Ray MUI...

REM 检查 Go 是否安装
go version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Go is not installed or not in PATH
    pause
    exit /b 1
)

REM 检查 Node.js 是否安装
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Node.js is not installed or not in PATH
    pause
    exit /b 1
)

REM 安装后端依赖
echo Installing backend dependencies...
go mod tidy
if %errorlevel% neq 0 (
    echo Error: Failed to install backend dependencies
    pause
    exit /b 1
)

REM 安装前端依赖
echo Installing frontend dependencies...
cd web
npm install
if %errorlevel% neq 0 (
    echo Error: Failed to install frontend dependencies
    pause
    exit /b 1
)

REM 构建前端
echo Building frontend...
npm run build
if %errorlevel% neq 0 (
    echo Error: Failed to build frontend
    pause
    exit /b 1
)

cd ..

REM 创建必要的目录
if not exist "bin" mkdir bin
if not exist "data" mkdir data
if not exist "logs" mkdir logs

REM 启动后端
echo Starting backend server...
start "V2Ray MUI Backend" go run main.go

REM 等待后端启动
timeout /t 3 /nobreak >nul

REM 打开浏览器
echo Opening browser...
start http://localhost:3000

echo V2Ray MUI started successfully!
echo Backend: http://localhost:58080
echo Frontend: http://localhost:3000
pause
