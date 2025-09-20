package proxy

import (
	"fmt"
	"os/exec"
	"runtime"
	"strings"

	"v2ray-mui/internal/config"
)

type Manager struct {
	config *config.Config
}

func New(cfg *config.Config) *Manager {
	return &Manager{
		config: cfg,
	}
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
	return nil
	cmd := exec.Command("networksetup", "-listallnetworkservices")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list network services: %w", err)
	}

	services := strings.Split(string(output), "\n")
	var activeService string

	// 找到活跃的网络服务（通常是 Wi-Fi 或以太网）
	for _, service := range services {
		service = strings.TrimSpace(service)
		if service != "" && !strings.Contains(service, "*") {
			activeService = service
			break
		}
	}

	if activeService == "" {
		return fmt.Errorf("no active network service found")
	}
	activeService = "Wi-Fi"
	fmt.Printf("xxxxxxxx%s", activeService, activeService, m.config.Proxy.HTTP.Host, fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))

	// 设置 HTTP 代理
	// httpProxy := fmt.Sprintf("%s:%d", m.config.Proxy.HTTP.Host, m.config.Proxy.HTTP.Port)
	cmd = exec.Command("networksetup", "-setwebproxy", activeService, m.config.Proxy.HTTP.Host, fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTP proxy: %w", err)
	}

	cmd = exec.Command("networksetup", "-setsecurewebproxy", activeService, m.config.Proxy.HTTP.Host, fmt.Sprintf("%d", m.config.Proxy.HTTP.Port))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set HTTPS proxy: %w", err)
	}

	// 设置 SOCKS 代理
	cmd = exec.Command("networksetup", "-setsocksfirewallproxy", activeService, m.config.Proxy.SOCKS.Host, fmt.Sprintf("%d", m.config.Proxy.SOCKS.Port))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set SOCKS proxy: %w", err)
	}

	// 启用代理
	cmd = exec.Command("networksetup", "-setwebproxystate", activeService, "on")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to enable HTTP proxy: %w", err)
	}

	cmd = exec.Command("networksetup", "-setsecurewebproxystate", activeService, "on")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to enable HTTPS proxy: %w", err)
	}

	cmd = exec.Command("networksetup", "-setsocksfirewallproxystate", activeService, "on")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to enable SOCKS proxy: %w", err)
	}

	return nil
}

func (m *Manager) clearMacOSProxy() error {
	// 获取网络服务列表
	cmd := exec.Command("networksetup", "-listallnetworkservices")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to list network services: %w", err)
	}

	services := strings.Split(string(output), "\n")
	var activeService string

	// 找到活跃的网络服务
	for _, service := range services {
		service = strings.TrimSpace(service)
		if service != "" && !strings.HasPrefix(service, "*") {
			activeService = service
			break
		}
	}

	if activeService == "" {
		return fmt.Errorf("no active network service found")
	}

	// 关闭代理
	cmd = exec.Command("networksetup", "-setwebproxystate", activeService, "off")
	cmd.Run()

	cmd = exec.Command("networksetup", "-setsecurewebproxystate", activeService, "off")
	cmd.Run()

	cmd = exec.Command("networksetup", "-setsocksfirewallproxystate", activeService, "off")
	cmd.Run()

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
