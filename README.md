# V2Ray MUI（macOS + Go + Vue）

一个基于 Go 后端与 Vue 3 前端的现代化 V2Ray/Xray 图形客户端，并提供原生 macOS 外壳（SwiftUI）。支持一键连接、系统代理自动切换、状态栏控制、可视化日志、可配置的路由规则等。

## 功能特性
- 一键连接/断开（主页与状态栏菜单均可控制）
- 自动系统代理（HTTP/HTTPS/SOCKS），断开/退出自动清理
- 多协议：vmess、vless、trojan、shadowsocks
- 路由模式：全局/绕过大陆/直连，自定义 代理/直连/拦截 规则
- 日志面板：捕获核心日志，过滤/导出
- 设置项：端口/地址、UDP、日志级别、Dock 显示、开机启动、自动连接等
- 现代化 UI（shadcn-vue + Tailwind CSS）
- 跨平台后端（Go），macOS 原生外壳（SwiftUI）

## 架构概览
- macOS App（SwiftUI）内置并启动 Go 服务进程（`v2rayMuiGoServer`）
- Go 服务提供 REST API 与静态 Web 资源（生产模式）
- Vue 前端在开发模式下由 Vite Dev Server 提供（端口 3000）
- Xray 核心二进制随 App 一起打包在 `v2rayMui/Resources/bin` 下

关键路径：
- Swift 端口：`v2rayMui/Config.swift`（DEBUG=58081，Release=58080）
- Go 主入口：`server/main.go`
- Web 前端：`server/web/`
- 内置资源放置：`v2rayMui/Resources/bin/`

## 端口与环境
- App 内置 Go API 端口：
  - Xcode/DEBUG 运行：58081
  - Release/打包运行：58080
- Vite 开发服务器：3000
  - 代理到 `http://localhost:${VITE_API_PORT|58080}`（见 `server/web/vite.config.ts`）

## 快速开始（开发）
1) 安装依赖
```bash
# 前端
cd server/web && npm install

# 后端（可选）
cd ../.. && cd server && go mod tidy
```

2) 启动后端（开发）
```bash
cd server
go run main.go
```
> 默认监听 `127.0.0.1:58080`。

3) 启动前端（开发）
```bash
cd server/web
npm run dev
```
> 浏览器访问 `http://localhost:3000`。

4) 运行 macOS App（可选）
- 打开 `v2rayMui.xcodeproj`，选择 `v2rayMui` 目标，Run。
- DEBUG 下 App 会连接 `127.0.0.1:58081`，右上角会显示 “DEV” 角标。
- 首次需要授予“修改网络设置”权限；会话内缓存授权，退出清理仅执行一次，避免反复弹窗。

## 一键构建与打包
项目提供脚本协助将 Web+Go 嵌入到 App 资源目录：

```bash
# 构建 Web、构建 Go（universal arm64+amd64）、拷贝到 Resources/bin
./build.sh

# 下载并放置 Xray 二进制到 Resources/bin（自动赋权）
./download_xray.sh
```
完成后，打开 Xcode 进行 Run/Archive 即可。

目录期望：
- `v2rayMui/Resources/bin/v2rayMuiGoServer`
- `v2rayMui/Resources/bin/xray`（`download_xray.sh` 会帮你放好）
- `v2rayMui/Resources/bin/geoip.dat`、`geosite.dat`（若需要）

## 使用说明（应用内）
- 状态栏图标：白色模板主图标；右下角小圆点指示连接（绿=已连接，红=未连接）
- DEBUG 构建：状态栏图标右上角显示小黄标“DEV”
- 首页：
  - 显示连接状态、当前服务器、代理端口
  - “终端启用命令/终端关闭命令”可复制到终端快速切换环境变量代理
- 服务器页：新增/编辑/选择服务器，切换线路会自动重启 Xray
- 设置页：端口、UDP、日志、路由模式与自定义规则
- 日志页：查看/导出/清空日志

## 常见问题（FAQ）
- 为什么会弹多次 Touch ID/授权？
  - 已在会话内缓存授权，并将退出清理收敛为只执行一次；若仍频繁弹窗，请反馈触发路径。
- 退出是否一定清理系统代理？
  - 是。若希望“完全无授权弹窗退出”，可以改为仅清理动态存储（副作用是系统设置里可能短暂保留代理）。
- 前端 TypeCheck 报错（vue-tsc 与 Node 版本）
  - 如遇 `Search string not found` 等报错，建议使用 Node 18/20 运行 type-check，或跳过该步骤。
- Web 生产资源如何提供？
  - Go 在生产模式会嵌入并服务 `server/dist`；开发模式下由 Vite 提供。

## 项目脚本
- `build.sh`：构建 Web、Go，并将 Go 可执行放入 App 资源
- `download_xray.sh`：自动下载最新 Xray（含架构判断与赋权）
- `server/start.sh`、`server/start.bat`：后端快捷启动

## 项目结构（概要）
```
v2rayMui/
├─ server/                # Go 后端 + Web 前端
│  ├─ internal/           # 业务与 API 实现
│  ├─ web/                # Vue 3 + Vite 前端
│  ├─ dist/               # 前端打包产物（供嵌入/静态服务）
│  └─ main.go             # 后端入口
├─ v2rayMui/              # macOS SwiftUI App（外壳）
│  ├─ Resources/bin/      # 内置 v2rayMuiGoServer 与 xray
│  ├─ SystemProxyManager.swift
│  ├─ GoServerManager.swift
│  └─ StatusBarIconView.swift
└─ build.sh / download_xray.sh
```

## 许可协议
MIT

## 致谢
- Xray `https://github.com/XTLS/Xray-core`
- Vue 3、Vite、Tailwind CSS、shadcn-vue
- Gin（Go HTTP 框架）
