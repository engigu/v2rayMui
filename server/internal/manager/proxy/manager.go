package proxy

import (
	"fmt"
	"os/exec"
	"runtime"
	"strings"

	"v2ray-mui/internal/config"
    applog "v2ray-mui/internal/manager/log"
)

type Manager struct {
	config *config.Config
    logger *applog.Manager
}

func New(cfg *config.Config, logger *applog.Manager) *Manager {
    return &Manager{
        config: cfg,
        logger: logger,
    }
}

// runLogged 运行命令并打印命令与输出，便于排查
func (m *Manager) runLogged(cmd *exec.Cmd) error {
    // 注意：cmd.String() 包含可执行文件与参数
    fmt.Printf("[proxy] $ %s\n", cmd.String())
    if m != nil && m.logger != nil {
        m.logger.AddLog("info", "proxy", "$ "+cmd.String())
    }
    out, err := cmd.CombinedOutput()
    if len(out) > 0 {
        fmt.Printf("[proxy] -> %s\n", strings.TrimSpace(string(out)))
        if m != nil && m.logger != nil {
            m.logger.AddLog("info", "proxy", strings.TrimSpace(string(out)))
        }
    }
    if err != nil {
        // 在 macOS 上尝试使用 osascript 提权执行（弹出管理员密码框），并在密码错误时重试最多 2 次
        if runtime.GOOS == "darwin" {
            // 严格逐参数 shell 转义，避免服务名包含空格/特殊符号导致脚本报错而不弹窗
            shQuote := func(s string) string {
                // 单引号安全包裹：' -> '\''
                return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
            }
            args := []string{}
            if cmd.Path != "" {
                args = append(args, cmd.Path)
            } else if len(cmd.Args) > 0 {
                args = append(args, cmd.Args[0])
            }
            if len(cmd.Args) > 1 {
                args = append(args, cmd.Args[1:]...)
            }
            for i := range args { args[i] = shQuote(args[i]) }
            joined := strings.Join(args, " ")

            for attempt := 1; attempt <= 3; attempt++ {
                // 注意：AppleScript 字符串用双引号，内部无需再对空格做特殊处理
                script := fmt.Sprintf("do shell script \"%s\" with administrator privileges", joined)
                osa := exec.Command("/usr/bin/osascript", "-e", script)
                if m != nil && m.logger != nil {
                    m.logger.AddLog("info", "proxy", fmt.Sprintf("$ osascript (attempt %d)", attempt))
                }
                out2, err2 := osa.CombinedOutput()
                if len(out2) > 0 && m != nil && m.logger != nil {
                    m.logger.AddLog("info", "proxy", strings.TrimSpace(string(out2)))
                }
                if err2 == nil {
                    return nil
                }
                // -60005: 管理员用户名或密码不正确；-128: 用户取消
                serr := err2.Error()
                if strings.Contains(serr, "-128") {
                    if m != nil && m.logger != nil { m.logger.AddLog("error", "proxy", "用户取消了管理员授权") }
                    return fmt.Errorf("administrator authorization cancelled")
                }
                if strings.Contains(serr, "-60005") {
                    if m != nil && m.logger != nil { m.logger.AddLog("error", "proxy", "管理员用户名或密码不正确，请重试") }
                    // 下一轮重试
                    continue
                }
                // 其他错误直接返回
                if m != nil && m.logger != nil { m.logger.AddLog("error", "proxy", serr) }
                return fmt.Errorf("command failed (osascript): %w", err2)
            }
        }
        if m != nil && m.logger != nil {
            m.logger.AddLog("error", "proxy", err.Error())
        }
        return fmt.Errorf("command failed: %w", err)
    }
    return nil
}

func (m *Manager) SetSystemProxy() error {
	if runtime.GOOS == "windows" {
		return m.setWindowsProxy()
	} else if runtime.GOOS == "darwin" {
		return m.setMacOSProxy()
	} else if runtime.GOOS == "linux" {
		return m.setLinuxProxy()
	}
	return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
}

func (m *Manager) ClearSystemProxy() error {
	if runtime.GOOS == "windows" {
		return m.clearWindowsProxy()
	} else if runtime.GOOS == "darwin" {
		return m.clearMacOSProxy()
	} else if runtime.GOOS == "linux" {
		return m.clearLinuxProxy()
	}
	return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
}

func (m *Manager) setWindowsProxy() error {
	httpProxy := fmt.Sprintf("http://%s:%d", m.config.Proxy.HTTP.Host, m.config.Proxy.HTTP.Port)
	// socksProxy := fmt.Sprintf("socks=%s:%d", m.config.Proxy.SOCKS.Host, m.config.Proxy.SOCKS.Port)

	// 设置 HTTP 代理
	cmd := exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyEnable", "/t", "REG_DWORD", "/d", "1", "/f")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to enable proxy: %w", err)
	}

	cmd = exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyServer", "/t", "REG_SZ", "/d", httpProxy, "/f")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTP proxy: %w", err)
	}

	// 设置 SOCKS 代理
	cmd = exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyOverride", "/t", "REG_SZ", "/d", "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*", "/f")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set proxy override: %w", err)
	}

	return nil
}

func (m *Manager) clearWindowsProxy() error {
	cmd := exec.Command("reg", "add", "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
		"/v", "ProxyEnable", "/t", "REG_DWORD", "/d", "0", "/f")
	return cmd.Run()
}

func (m *Manager) setMacOSProxy() error {
    // 获取网络服务列表
    cmd := exec.Command("/usr/sbin/networksetup", "-listallnetworkservices")
    output, err := cmd.Output()
    if err != nil {
        return fmt.Errorf("failed to list network services: %w", err)
    }

    services := strings.Split(string(output), "\n")
    success := 0
    var lastErr error

    for _, service := range services {
        s := strings.TrimSpace(service)
        if s == "" || strings.HasPrefix(s, "*") || strings.HasPrefix(strings.ToLower(s), "an asterisk") {
            continue
        }
		
        // 设置 HTTP/HTTPS 代理
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setwebproxy", s, m.config.Proxy.HTTP.Host, fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))); err != nil {
            lastErr = fmt.Errorf("%s: set HTTP proxy: %w", s, err)
            continue
        }
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsecurewebproxy", s, m.config.Proxy.HTTP.Host, fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))); err != nil {
            lastErr = fmt.Errorf("%s: set HTTPS proxy: %w", s, err)
            continue
        }
        // 设置 SOCKS 代理
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsocksfirewallproxy", s, m.config.Proxy.SOCKS.Host, fmt.Sprintf("%d", m.config.Proxy.SOCKS.Port))); err != nil {
            lastErr = fmt.Errorf("%s: set SOCKS proxy: %w", s, err)
            continue
        }
        // 启用三类代理
        _ = m.runLogged(exec.Command("/usr/sbin/networksetup", "-setwebproxystate", s, "on"))
        _ = m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsecurewebproxystate", s, "on"))
        _ = m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsocksfirewallproxystate", s, "on"))
        success++
    }

    if success == 0 && lastErr != nil {
        return lastErr
    }
    return nil
}

func (m *Manager) clearMacOSProxy() error {
    // 获取网络服务列表
    cmd := exec.Command("/usr/sbin/networksetup", "-listallnetworkservices")
    output, err := cmd.Output()
    if err != nil {
        return fmt.Errorf("failed to list network services: %w", err)
    }

    services := strings.Split(string(output), "\n")
    success := 0
    var lastErr error

    for _, service := range services {
        s := strings.TrimSpace(service)
        if s == "" || strings.HasPrefix(s, "*") || strings.HasPrefix(strings.ToLower(s), "an asterisk") {
            continue
        }
        // 关闭三类代理，若部分失败继续下一项
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setwebproxystate", s, "off")); err != nil { lastErr = err }
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsecurewebproxystate", s, "off")); err != nil { lastErr = err }
        if err := m.runLogged(exec.Command("/usr/sbin/networksetup", "-setsocksfirewallproxystate", s, "off")); err != nil { lastErr = err }
        success++
    }

    if success == 0 && lastErr != nil {
        return lastErr
    }
    return nil
}

func (m *Manager) setLinuxProxy() error {
	// Linux 系统代理设置比较复杂，这里提供基本的实现
	// 实际使用时可能需要根据具体的桌面环境进行调整

	// 设置环境变量
	httpProxy := fmt.Sprintf("http://%s:%d", m.config.Proxy.HTTP.Host, m.config.Proxy.HTTP.Port)
	socksProxy := fmt.Sprintf("socks5://%s:%d", m.config.Proxy.SOCKS.Host, m.config.Proxy.SOCKS.Port)

	// 尝试使用 gsettings (GNOME)
	cmd := exec.Command("gsettings", "set", "org.gnome.system.proxy", "mode", "manual")
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.http", "host", m.config.Proxy.HTTP.Host)
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.http", "port", fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.https", "host", m.config.Proxy.HTTP.Host)
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.https", "port", fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.socks", "host", m.config.Proxy.SOCKS.Host)
	cmd.Run()

	cmd = exec.Command("gsettings", "set", "org.gnome.system.proxy.socks", "port", fmt.Sprintf("%d", m.config.Proxy.SOCKS.Port))
	cmd.Run()

	// 设置环境变量
	cmd = exec.Command("export", fmt.Sprintf("http_proxy=%s", httpProxy))
	cmd.Run()

	cmd = exec.Command("export", fmt.Sprintf("https_proxy=%s", httpProxy))
	cmd.Run()

	cmd = exec.Command("export", fmt.Sprintf("all_proxy=%s", socksProxy))
	cmd.Run()

	return nil
}

func (m *Manager) clearLinuxProxy() error {
	// 关闭代理
	cmd := exec.Command("gsettings", "set", "org.gnome.system.proxy", "mode", "none")
	cmd.Run()

	// 清除环境变量
	cmd = exec.Command("unset", "http_proxy")
	cmd.Run()

	cmd = exec.Command("unset", "https_proxy")
	cmd.Run()

	cmd = exec.Command("unset", "all_proxy")
	cmd.Run()

	return nil
}

func (m *Manager) GetProxyStatus() (map[string]interface{}, error) {
	status := make(map[string]interface{})

	if runtime.GOOS == "darwin" {
		// 获取 macOS 代理状态
		cmd := exec.Command("networksetup", "-getwebproxy", "Wi-Fi")
		output, err := cmd.Output()
		if err == nil {
			status["http_proxy"] = strings.TrimSpace(string(output))
		}

		cmd = exec.Command("networksetup", "-getsocksfirewallproxy", "Wi-Fi")
		output, err = cmd.Output()
		if err == nil {
			status["socks_proxy"] = strings.TrimSpace(string(output))
		}
	}

	return status, nil
}
