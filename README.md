## v2rayMui

一个基于 SwiftUI 的 macOS V2Ray 图形客户端，提供一键连接/断开、系统代理自动配置、状态栏快捷控制、可视化日志与多路由模式等功能。

### 主要特性
- **一键连接/断开**：从主界面或状态栏控制 V2Ray 连接。
- **自动配置系统代理**：连接成功后自动为当前网络启用 HTTP/HTTPS/SOCKS 代理，断开/退出时自动关闭。
- **多协议支持**：`vmess`、`vless`、`trojan`、`shadowsocks`。
- **路由模式**：全局代理、绕过大陆、直连，可叠加自定义规则。
- **本地入站端口可配**：HTTP、SOCKS 监听地址与端口可在“设置”中修改。
- **状态栏与主窗口**：状态栏弹窗快速操作，主窗口提供详细配置与日志。
- **日志查看**：实时捕获 V2Ray 输出，支持查看与持久化。

### 系统要求
- macOS（Intel 或 Apple Silicon）
- Xcode 15+（开发/构建）

### 构建与运行
1. 使用 Xcode 打开工程 `v2rayMui.xcodeproj`。
2. 在目标 `v2rayMui` 的 Signing 中设置你的开发者签名。
3. 运行（⌘R）。首次运行如遇权限弹窗，请允许网络与系统设置相关权限。

### 快速开始
1. 在“配置管理”中添加或选择一个服务器配置。
2. 在“设置”中确认本地监听：
   - **HTTP**：默认 `127.0.0.1:1087`
   - **SOCKS**：默认 `127.0.0.1:1088`
3. 点击“连接”。成功后应用会：
   - 启动 V2Ray（以所选配置生成 JSON 并拉起进程）。
   - 自动为当前网络服务启用系统 HTTP/HTTPS/SOCKS 代理。
4. 点击“断开”或退出应用时，会自动关闭上述系统代理并停止进程。

### 代理自动设置说明
- 应用在连接成功后优先通过 SystemConfiguration API 为“当前主网络服务”设置代理；若不可用，则回退到 `networksetup` 为可用网络服务批量设置。
- 断开、进程意外退出或应用退出时，会自动关闭代理。
- 在企业/受管设备或有描述文件（MDM）限制的环境下，系统可能拒绝修改代理；此时请手动在“系统设置 → 网络 → Wi‑Fi/以太网 → 详情 → 代理”中开启/关闭，或联系管理员。

### 自检与排障
以下命令可帮助快速定位系统代理是否已被正确应用（服务名以 `Wi‑Fi` 为例）：

```bash
/usr/sbin/networksetup -listallnetworkservices | cat
/usr/sbin/networksetup -getwebproxy Wi-Fi
/usr/sbin/networksetup -getsecurewebproxy Wi-Fi
/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi
```

若显示的端口不是应用设置中的端口（默认 HTTP: 1087、SOCKS: 1088），说明系统代理被其他软件或旧设置覆盖：
- 关闭其他代理/网络工具或将本应用端口调整为一致。
- 在“系统设置 → 网络 → Wi‑Fi/以太网 → 详情 → 代理”中先全部关闭，再回到应用点击“连接”。

进一步连通性测试（以 HTTP 代理为例）：

```bash
curl -I --proxy http://127.0.0.1:1087 https://www.google.com
```

终端程序默认不读取系统代理，可临时设置环境变量：

```bash
export http_proxy=http://127.0.0.1:1087
export https_proxy=http://127.0.0.1:1087
export all_proxy=socks5://127.0.0.1:1088
```

常见问题：
- **代理端口不一致**：其他软件启用了 10808 等端口，或你此前手动设置过代理。解决：统一端口或手动清理系统代理后重连。
- **无法修改系统代理**：沙盒/权限限制、企业策略或需要授权。请在系统设置中手动开启，或以开发模式禁用 Sandbox 做对比测试。
- **连接成功但无法访问**：核对服务器配置、TLS/REALITY 参数、路由模式（直连模式不会下发 routing）。

### 设置与路由
- `设置` 页面可调整：
  - 本地监听：`httpHost/httpPort`、`socksHost/socksLocalPort`、是否开启 `socksUdpEnabled`。
  - 路由模式：`全局 / 绕过大陆 / 直连`，并可叠加自定义规则（代理/直连/拦截）。
  - 日志相关：等级、最大文件大小等。

### 目录结构（节选）
- `v2rayMui/Managers/V2RayManager.swift`：连接、配置生成、进程管理。
- `v2rayMui/Managers/ProxyManager.swift`：系统代理开关（SystemConfiguration 优先，`networksetup` 回退）。
- `v2rayMui/Managers/SettingsManager.swift`：应用设置与持久化。
- `v2rayMui/Views/*`：SwiftUI 界面与状态栏弹窗。
- `v2rayMui/Resources/v2ray`：内置 V2Ray 可执行文件（如有）。

### 许可
本项目遵循仓库根目录中的 `LICENSE`。
