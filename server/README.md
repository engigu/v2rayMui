# V2Ray MUI

一个基于 Golang 后端和 Vue 前端的 V2Ray 图形客户端，支持一键连接、自动系统代理、状态栏控制、可视化日志与多路由模式。

## 功能特性

- ✅ **一键连接/断开**：主界面和状态栏均可控制连接
- ✅ **自动系统代理**：连接后自动启用 HTTP/HTTPS/SOCKS 代理；断开/退出自动关闭
- ✅ **多协议支持**：`vmess`、`vless`、`trojan`、`shadowsocks`
- ✅ **路由模式**：全局、绕过大陆、直连；支持自定义代理/直连/拦截规则
- ✅ **日志面板**：捕获核心输出，自动滚动与筛选，支持导出
- ✅ **设置项**：端口/地址、UDP、日志级别、Dock 显示、开机启动、自动连接等
- ✅ **现代化 UI**：基于 shadcn-vue 的美观界面
- ✅ **跨平台**：支持 Windows、macOS、Linux

## 系统要求

- Go 1.21+
- Node.js 18+
- Xray 二进制文件

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd v2ray-mui
```

### 2. 安装依赖

#### 后端依赖
```bash
go mod tidy
```

#### 前端依赖
```bash
cd web
npm install
```

### 3. 下载 Xray 二进制文件

将 Xray 二进制文件放置在 `bin/xray` 路径下，或修改 `config.yaml` 中的 `v2ray.binary_path` 配置。

### 4. 启动应用

#### 启动后端
```bash
go run main.go
```

#### 启动前端（开发模式）
```bash
cd web
npm run dev
```

#### 构建前端
```bash
cd web
npm run build
```

### 5. 访问应用

打开浏览器访问 `http://localhost:3000`

## 配置说明

### 后端配置 (config.yaml)

```yaml
server:
  address: "127.0.0.1"  # 服务器监听地址
  port: 58080           # 服务器端口

v2ray:
  binary_path: "./bin/xray"     # Xray 二进制文件路径
  config_path: "./config.json"  # V2Ray 配置文件路径
  log_path: "./logs/v2ray.log"  # V2Ray 日志文件路径

proxy:
  http:
    host: "127.0.0.1"  # HTTP 代理地址
    port: 1087         # HTTP 代理端口
  socks:
    host: "127.0.0.1"  # SOCKS 代理地址
    port: 1088         # SOCKS 代理端口

log:
  level: "info"    # 日志级别
  max_age: 7       # 日志保留天数

settings:
  data_path: "./data"  # 数据存储路径
```

### 前端配置

前端配置通过 API 接口动态管理，无需手动配置文件。

## 项目结构

```
v2ray-mui/
├── main.go                 # 主程序入口
├── go.mod                  # Go 模块文件
├── config.yaml             # 配置文件
├── internal/               # 内部包
│   ├── api/               # API 服务器
│   ├── config/            # 配置管理
│   ├── manager/           # 业务管理器
│   │   ├── v2ray/         # V2Ray 管理
│   │   ├── proxy/         # 代理管理
│   │   ├── settings/      # 设置管理
│   │   ├── configmgr/     # 配置管理
│   │   └── log/           # 日志管理
│   └── types/             # 类型定义
├── web/                   # 前端项目
│   ├── src/
│   │   ├── components/    # UI 组件
│   │   ├── views/         # 页面组件
│   │   ├── stores/        # Pinia 状态管理
│   │   ├── lib/           # 工具库
│   │   └── types/         # 类型定义
│   ├── package.json
│   └── vite.config.ts
└── README.md
```

## API 接口

### 状态相关
- `GET /api/v1/status` - 获取连接状态
- `POST /api/v1/connect` - 连接服务器
- `POST /api/v1/disconnect` - 断开连接

### 服务器管理
- `GET /api/v1/servers` - 获取服务器列表
- `POST /api/v1/servers` - 添加服务器
- `PUT /api/v1/servers/:id` - 更新服务器
- `DELETE /api/v1/servers/:id` - 删除服务器
- `POST /api/v1/servers/:id/select` - 选择服务器
- `GET /api/v1/servers/selected` - 获取选中的服务器

### 设置管理
- `GET /api/v1/settings` - 获取设置
- `PUT /api/v1/settings` - 更新设置

### 日志管理
- `GET /api/v1/logs` - 获取日志
- `DELETE /api/v1/logs` - 清空日志
- `GET /api/v1/logs/export` - 导出日志

### 代理管理
- `GET /api/v1/proxy/status` - 获取代理状态
- `POST /api/v1/proxy/set` - 设置代理
- `POST /api/v1/proxy/clear` - 清除代理

## 开发说明

### 后端开发

1. 使用 Go 1.21+ 版本
2. 遵循 Go 项目结构规范
3. 使用 Gin 框架提供 RESTful API
4. 使用 Pinia 进行状态管理

### 前端开发

1. 使用 Vue 3 + TypeScript
2. 使用 Vite 作为构建工具
3. 使用 Tailwind CSS 进行样式管理
4. 使用 shadcn-vue 组件库
5. 使用 Pinia 进行状态管理

### 构建部署

#### 构建后端
```bash
go build -o v2ray-mui main.go
```

#### 构建前端
```bash
cd web
npm run build
```

#### 运行
```bash
./v2ray-mui
```

## 常见问题

### 1. 代理端口不一致
如果系统代理端口为 10808 等，可能被其他代理工具覆盖；请统一端口或手动清理后再连接。

### 2. 需要管理员权限
修改系统网络设置通常需要管理员权限；本应用仅在会话首次写入时提示一次，后续自动。

### 3. 无法修改代理
企业/MDM 环境可能限制；请手动在系统设置里调整或联系管理员。

### 4. Xray 二进制文件缺失
请确保 Xray 二进制文件存在于指定路径，或修改配置文件中的路径。

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- [V2Ray](https://github.com/v2fly/v2ray-core) - 核心代理工具
- [Xray](https://github.com/XTLS/Xray-core) - V2Ray 的分支版本
- [Vue](https://vuejs.org/) - 前端框架
- [shadcn-vue](https://www.shadcn-vue.com/) - UI 组件库
- [Tailwind CSS](https://tailwindcss.com/) - CSS 框架
