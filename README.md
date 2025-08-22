## v2rayMui

一个基于 SwiftUI 的 macOS V2Ray/Xray 图形客户端，支持一键连接、自动系统代理、状态栏控制、可视化日志与多路由模式。支持 Xcode 调试环境与用户环境分离存储，提供一键下载 Xray 二进制与 GitHub Actions 打包。
![](https://github.com/user-attachments/assets/1ac35afa-d023-47ab-aed8-de838599155f)
![](https://github.com/user-attachments/assets/f05b10a4-5f45-48bd-a53e-a673b3b06035)

### 功能支持进度
- [ ] vless、ssr 待测试
- [x] vmess连接

### 主要特性
- 一键连接/断开：主界面和状态栏均可控制连接。
- 自动系统代理：连接后自动启用 HTTP/HTTPS/SOCKS 代理；断开/退出自动关闭。
- 多协议：`vmess`、`vless`、`trojan`、`shadowsocks`。
- 路由模式：全局、绕过大陆、直连；支持自定义代理/直连/拦截规则。
- 日志面板：捕获核心输出，自动滚动与筛选，支持导出。
- 设置项：端口/地址、UDP、日志级别、Dock 显示、开机启动、自动连接等。
- 状态栏：快速查看状态、配置与一键连接。
- Xcode 开发隔离：在 Xcode 调试运行时，应用数据写入 `Application Support/<bundleId>/dev`。

### 系统要求
- macOS（Apple Silicon 或 Intel）
- Xcode 15+（开发/构建）

### 获取 Xray 二进制
资源目录优先读取：`v2rayMui/Resources/v2ray-core/v2ray`（兼容 `v2rayMui/Resources/v2ray`）。

下载脚本（自动识别架构并安装到 Resources/v2ray-core/v2ray）：
```bash
./scripts/download_xray.sh
```

### 构建与运行
1) Xcode 打开 `v2rayMui.xcodeproj` → 选择 scheme `v2rayMui`。
2) 运行（⌘R）。首次运行可能出现网络/系统设置权限提示；请允许。

GitHub Actions（手动触发）：`.github/workflows/build-macos.yml`
- 构建未签名 Release `.app`，并打包可拖拽安装的 `.dmg`。
- 工作流会（可选）执行脚本下载 Xray 并写入资源目录（当前步骤默认注释，可按需放开）。

### 快速开始
1) “配置”页添加或选择一个服务器配置。
2) “设置”页确认本地监听：HTTP `127.0.0.1:1087`，SOCKS `127.0.0.1:1088`（可改）。
3) 在主界面或状态栏点击“连接”。成功后：
   - 生成并写入 `config.json`；
   - 启动 Xray；
   - 自动为当前网络服务启用系统代理。
4) 点击“断开”或退出应用自动清理代理并停止进程。

### 自动系统代理说明
- 优先通过 SystemConfiguration 写入当前主网络服务的 HTTP/HTTPS/SOCKS 代理；失败则回退 `networksetup`。
- 断开、进程异常退出或应用退出时，自动关闭上述代理。
- 首次写入可能需要一次管理员授权；同一会话后续复用，尽量减少弹窗。

自检命令（以 Wi‑Fi 为例）：
```bash
/usr/sbin/networksetup -listallnetworkservices | cat
/usr/sbin/networksetup -getwebproxy Wi-Fi
/usr/sbin/networksetup -getsecurewebproxy Wi-Fi
/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi
```

终端不读系统代理时可临时设置：
```bash
export http_proxy=http://127.0.0.1:1087
export https_proxy=http://127.0.0.1:1087
export all_proxy=socks5://127.0.0.1:1088
```

### 自动连接与 Dock
- 自动连接：
  - 启动时若开启且存在选中配置，会自动连接；
  - 修改“自动连接”或“选中配置”时按状态自动连接/断开；
  - 设置加载完成后二次检查，保证时序正确。
- Dock 显示：
  - “显示在Dock”开关实时控制；
  - 关闭窗口时，如设置关闭 Dock，则仅保留状态栏图标。

### 路由与日志
- 路由：全局/绕过大陆/直连，支持自定义规则（域名/IP/CIDR，每行一条）。
- 日志：级别筛选、来源筛选、搜索、清空与导出；避免“先显示再消失”的闪烁问题。

### 目录结构（节选）
- `v2rayMui/Managers/V2RayManager.swift`：连接、进程、配置生成、代理清理。
- `v2rayMui/Managers/ProxyManager.swift`：系统代理开关（SystemConfiguration 优先，`networksetup` 回退；会话授权复用）。
- `v2rayMui/Managers/SettingsManager.swift`：设置读写与通知（自动连接、Dock 等）。
- `v2rayMui/Managers/ConfigManager.swift`：配置管理、导入、选中项持久化。
- `v2rayMui/Managers/LogManager.swift`：日志采集、合并、持久化，避免闪烁。
- `v2rayMui/Managers/AppEnvironment.swift`：Xcode/调试/预览环境检测。
- `v2rayMui/Views/*`：SwiftUI 界面与状态栏弹窗、日志页等。
- `v2rayMui/Resources/v2ray-core/v2ray`：Xray 可执行文件（如存在）。
- `scripts/download_xray.sh`：下载最新 Xray 并安装到资源目录。

### 常见问题
- 代理端口不一致：若系统代理端口为 10808 等，可能被其他代理工具覆盖；请统一端口或手动清理后再连接。
- 需要授权：修改系统网络设置通常需要管理员权限；本应用仅在会话首次写入时提示一次，后续自动。
- 无法修改代理：企业/MDM 环境可能限制；请手动在系统设置里调整或联系管理员。

### 许可
见根目录 `LICENSE`。
