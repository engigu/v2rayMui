# V2Ray MUI 项目总结

## 项目概述

基于参考的 [v2rayMui](https://github.com/engigu/v2rayMui) SwiftUI 项目，使用 Golang 后端和 shadcn-vue 前端重新实现了相同的功能。

## 技术栈

### 后端
- **语言**: Go 1.21+
- **框架**: Gin (HTTP 服务器)
- **配置管理**: Viper
- **日志**: Logrus
- **WebSocket**: Gorilla WebSocket

### 前端
- **框架**: Vue 3 + TypeScript
- **构建工具**: Vite
- **UI 组件**: shadcn-vue
- **样式**: Tailwind CSS
- **状态管理**: Pinia
- **路由**: Vue Router
- **HTTP 客户端**: Axios

## 项目结构

```
v2ray-mui/
├── main.go                 # 主程序入口
├── go.mod                  # Go 模块文件
├── config.yaml             # 配置文件
├── internal/               # 内部包
│   ├── api/               # API 服务器
│   │   └── server.go      # HTTP 服务器实现
│   ├── config/            # 配置管理
│   │   └── config.go      # 配置加载和管理
│   ├── manager/           # 业务管理器
│   │   ├── v2ray/         # V2Ray 管理
│   │   │   └── manager.go # V2Ray 进程管理
│   │   ├── proxy/         # 代理管理
│   │   │   └── manager.go # 系统代理设置
│   │   ├── settings/      # 设置管理
│   │   │   └── manager.go # 应用设置管理
│   │   ├── configmgr/     # 配置管理
│   │   │   └── manager.go # 服务器配置管理
│   │   ├── log/           # 日志管理
│   │   │   └── manager.go # 日志收集和管理
│   │   └── managers.go    # 管理器集合
│   └── types/             # 类型定义
│       └── v2ray.go       # V2Ray 相关类型
├── web/                   # 前端项目
│   ├── src/
│   │   ├── components/    # UI 组件
│   │   │   └── ui/        # shadcn-vue 组件
│   │   ├── views/         # 页面组件
│   │   │   ├── Home.vue   # 首页
│   │   │   ├── Servers.vue # 服务器管理
│   │   │   ├── Settings.vue # 设置页面
│   │   │   └── Logs.vue   # 日志页面
│   │   ├── stores/        # Pinia 状态管理
│   │   │   ├── status.ts  # 连接状态管理
│   │   │   ├── servers.ts # 服务器管理
│   │   │   ├── settings.ts # 设置管理
│   │   │   └── logs.ts    # 日志管理
│   │   ├── lib/           # 工具库
│   │   │   ├── api.ts     # API 客户端
│   │   │   └── utils.ts   # 工具函数
│   │   ├── types/         # 类型定义
│   │   │   └── index.ts   # 前端类型定义
│   │   ├── App.vue        # 根组件
│   │   └── main.ts        # 入口文件
│   ├── package.json       # 前端依赖
│   ├── vite.config.ts     # Vite 配置
│   ├── tailwind.config.js # Tailwind 配置
│   └── tsconfig.json      # TypeScript 配置
├── scripts/               # 脚本文件
│   └── download-xray.sh   # Xray 下载脚本
├── start.bat              # Windows 启动脚本
├── start.sh               # Linux/macOS 启动脚本
├── README.md              # 项目说明
└── PROJECT_SUMMARY.md     # 项目总结
```

## 核心功能实现

### 1. V2Ray 管理 (internal/manager/v2ray/)
- **进程管理**: 启动、停止、监控 V2Ray 进程
- **配置生成**: 根据服务器配置生成 V2Ray 配置文件
- **状态监控**: 实时监控连接状态
- **日志收集**: 收集 V2Ray 输出日志

### 2. 系统代理管理 (internal/manager/proxy/)
- **跨平台支持**: Windows、macOS、Linux
- **自动设置**: 连接时自动设置系统代理
- **自动清理**: 断开时自动清除代理设置
- **状态查询**: 查询当前代理状态

### 3. 设置管理 (internal/manager/settings/)
- **持久化存储**: JSON 文件存储设置
- **实时更新**: 设置变更立即生效
- **默认值**: 提供合理的默认配置
- **类型安全**: 强类型设置项

### 4. 服务器配置管理 (internal/manager/configmgr/)
- **CRUD 操作**: 增删改查服务器配置
- **选择管理**: 管理当前选中的服务器
- **导入导出**: 支持配置导入导出
- **数据验证**: 配置项验证

### 5. 日志管理 (internal/manager/log/)
- **实时收集**: 实时收集应用日志
- **过滤搜索**: 按级别、来源、关键词过滤
- **导出功能**: 支持日志导出
- **自动清理**: 自动清理过期日志

## API 接口设计

### RESTful API
- **状态管理**: `/api/v1/status`, `/api/v1/connect`, `/api/v1/disconnect`
- **服务器管理**: `/api/v1/servers/*`
- **设置管理**: `/api/v1/settings`
- **日志管理**: `/api/v1/logs/*`
- **代理管理**: `/api/v1/proxy/*`

### WebSocket 支持
- **实时通信**: 支持实时状态推送
- **日志流**: 实时日志推送

## 前端界面设计

### 1. 首页 (Home.vue)
- **连接状态**: 显示当前连接状态
- **服务器信息**: 显示选中的服务器
- **代理状态**: 显示代理配置
- **快速操作**: 提供常用操作入口

### 2. 服务器管理 (Servers.vue)
- **服务器列表**: 网格布局显示服务器
- **添加编辑**: 模态框形式的服务器编辑
- **协议支持**: 支持 VMess、VLESS、Trojan、Shadowsocks
- **选择管理**: 一键选择服务器

### 3. 设置页面 (Settings.vue)
- **基本设置**: 自动连接、Dock 显示等
- **代理设置**: HTTP/SOCKS 代理配置
- **路由设置**: 路由模式和自定义规则
- **高级设置**: 日志级别、UDP、Mux 等

### 4. 日志页面 (Logs.vue)
- **日志列表**: 实时显示日志条目
- **过滤搜索**: 多维度过滤和搜索
- **导出功能**: 支持日志导出
- **清空功能**: 一键清空日志

## 技术特点

### 1. 现代化技术栈
- **Go**: 高性能后端语言
- **Vue 3**: 现代前端框架
- **TypeScript**: 类型安全
- **Tailwind CSS**: 实用优先的 CSS 框架

### 2. 组件化设计
- **shadcn-vue**: 高质量 UI 组件
- **模块化**: 清晰的模块划分
- **可复用**: 高度可复用的组件

### 3. 状态管理
- **Pinia**: 现代状态管理
- **响应式**: 响应式数据更新
- **持久化**: 状态持久化存储

### 4. 跨平台支持
- **Windows**: 完整的 Windows 支持
- **macOS**: 原生 macOS 体验
- **Linux**: 良好的 Linux 兼容性

## 部署和运行

### 开发环境
```bash
# 后端
go run main.go

# 前端
cd web
npm run dev
```

### 生产环境
```bash
# 构建前端
cd web
npm run build

# 运行后端
go run main.go
```

### 一键启动
```bash
# Windows
start.bat

# Linux/macOS
./start.sh
```

## 与原项目对比

### 相同功能
- ✅ 一键连接/断开
- ✅ 自动系统代理
- ✅ 多协议支持
- ✅ 路由模式
- ✅ 日志面板
- ✅ 设置管理
- ✅ 服务器管理

### 技术优势
- **跨平台**: 支持 Windows、macOS、Linux
- **现代化**: 使用现代技术栈
- **可扩展**: 模块化设计易于扩展
- **维护性**: 清晰的代码结构

### 用户体验
- **响应式**: 现代化 UI 设计
- **直观**: 清晰的操作流程
- **高效**: 快速的操作响应
- **稳定**: 可靠的连接管理

## 总结

这个项目成功地将原 SwiftUI 的 macOS 专用 V2Ray 客户端重新实现为跨平台的 Web 应用，保持了所有核心功能的同时，提供了更好的可维护性和扩展性。使用 Golang 后端确保了高性能，使用 Vue 3 + shadcn-vue 提供了现代化的用户界面，整体架构清晰，代码质量高，是一个完整的生产级应用。
