package settings

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"sync"

	"v2ray-mui/internal/config"
	"v2ray-mui/internal/storage"
	"v2ray-mui/internal/types"
)

type Manager struct {
	config   *config.Config
	settings *types.AppSettings
	mu       sync.RWMutex
	loaded   bool
	store    *storage.Store
}

func New(cfg *config.Config) *Manager {
	m := &Manager{
		config: cfg,
		settings: &types.AppSettings{
			AutoConnect:    false,
			ShowInDock:     true,
			StartAtLogin:   false,
			LogLevel:       "info",
			HTTPPort:       cfg.Proxy.HTTP.Port,
			SOCKSPort:      cfg.Proxy.SOCKS.Port,
			HTTPHost:       cfg.Proxy.HTTP.Host,
			SOCKSHost:      cfg.Proxy.SOCKS.Host,
			RoutingMode:    "bypass",
			CustomRules:    []string{},
			UDPEnabled:     true,
			MuxEnabled:     false,
			MuxConcurrency: 8,
			LogMaxMB:       6,
			DomainStrategy: "AsIs",
			ProxyRules:     []string{},
			DirectRules:    []string{},
			BlockRules:     []string{},
		},
	}
	// 打开 sqlite 存储
	dbPath := filepath.Join(cfg.Settings.DataPath, "app.db")
	s, err := storage.New(dbPath)
	if err == nil {
		m.store = s
	}
	return m
}

func (m *Manager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.loaded {
		return nil
	}
	if m.store == nil {
		return fmt.Errorf("sqlite store not initialized")
	}
	if val, ok, err := m.store.GetItem("settings", "settings"); err == nil && ok {
		if err := json.Unmarshal([]byte(val), m.settings); err == nil {
			m.loaded = true
			return nil
		}
	}
	// 未找到则写入默认值
	if err := m.save(); err != nil {
		return err
	}
	m.loaded = true
	return nil
}

func (m *Manager) Save() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.save()
}

func (m *Manager) save() error {
	data, err := json.MarshalIndent(m.settings, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal settings: %w", err)
	}

	if m.store == nil {
		return fmt.Errorf("sqlite store not initialized")
	}
	if err := m.store.SetItem("settings", "settings", string(data)); err != nil {
		return fmt.Errorf("failed to write sqlite settings: %w", err)
	}
	return nil
}

func (m *Manager) GetSettings() *types.AppSettings {
	// 延迟加载，避免每次从磁盘读取
	m.mu.RLock()
	loaded := m.loaded
	m.mu.RUnlock()
	if !loaded {
		// 仅在未加载时读取一次
		_ = m.Load()
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings
}

func (m *Manager) UpdateSettings(settings *types.AppSettings) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings = settings
	m.loaded = true
	return m.save()
}

func (m *Manager) GetAutoConnect() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.AutoConnect
}

func (m *Manager) SetAutoConnect(autoConnect bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.AutoConnect = autoConnect
	return m.save()
}

func (m *Manager) GetShowInDock() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.ShowInDock
}

func (m *Manager) SetShowInDock(showInDock bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.ShowInDock = showInDock
	return m.save()
}

func (m *Manager) GetStartAtLogin() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.StartAtLogin
}

func (m *Manager) SetStartAtLogin(startAtLogin bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.StartAtLogin = startAtLogin
	return m.save()
}

func (m *Manager) GetLogLevel() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.LogLevel
}

func (m *Manager) SetLogLevel(logLevel string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.LogLevel = logLevel
	return m.save()
}

func (m *Manager) GetProxyPorts() (int, int) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.HTTPPort, m.settings.SOCKSPort
}

func (m *Manager) SetProxyPorts(httpPort, socksPort int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.HTTPPort = httpPort
	m.settings.SOCKSPort = socksPort
	return m.save()
}

func (m *Manager) GetRoutingMode() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.RoutingMode
}

func (m *Manager) SetRoutingMode(mode string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.RoutingMode = mode
	return m.save()
}

func (m *Manager) GetCustomRules() []string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.CustomRules
}

func (m *Manager) SetCustomRules(rules []string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.CustomRules = rules
	return m.save()
}

func (m *Manager) GetUDPEnabled() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.UDPEnabled
}

func (m *Manager) SetUDPEnabled(enabled bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.UDPEnabled = enabled
	return m.save()
}

func (m *Manager) GetMuxEnabled() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.MuxEnabled
}

func (m *Manager) SetMuxEnabled(enabled bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.MuxEnabled = enabled
	return m.save()
}

func (m *Manager) GetMuxConcurrency() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.settings.MuxConcurrency
}

func (m *Manager) SetMuxConcurrency(concurrency int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.settings.MuxConcurrency = concurrency
	return m.save()
}
