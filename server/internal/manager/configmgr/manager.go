package configmgr

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"v2ray-mui/internal/config"
	"v2ray-mui/internal/types"
	"v2ray-mui/internal/storage"

	"github.com/google/uuid"
)

type Manager struct {
	config       *config.Config
	servers      []*types.ServerConfig
	selectedID   string
	mu           sync.RWMutex
	store        *storage.Store
}

func New(cfg *config.Config) *Manager {
	m := &Manager{
		config:       cfg,
		servers:      []*types.ServerConfig{},
	}
	// try open sqlite store
	dbPath := filepath.Join(cfg.Settings.DataPath, "app.db")
	if s, err := storage.New(dbPath); err == nil {
		m.store = s
	}
	return m
}

func (m *Manager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 加载服务器列表
	if err := m.loadServers(); err != nil {
		return fmt.Errorf("failed to load servers: %w", err)
	}

	// 加载选中的服务器
	if err := m.loadSelected(); err != nil {
		return fmt.Errorf("failed to load selected server: %w", err)
	}

	return nil
}

func (m *Manager) loadServers() error {
    if m.store == nil { return fmt.Errorf("sqlite store not initialized") }
    values, err := m.store.ListItems("server")
    if err != nil { return err }
    var list []*types.ServerConfig
    for _, v := range values {
        var s types.ServerConfig
        if err := json.Unmarshal([]byte(v), &s); err == nil {
            // capture copy
            ss := s
            list = append(list, &ss)
        }
    }
    m.servers = list
    return nil
}

func (m *Manager) loadSelected() error {
    if m.store == nil { return fmt.Errorf("sqlite store not initialized") }
    if val, ok, err := m.store.GetItem("meta", "selected"); err == nil && ok {
        var sel struct{ ID string `json:"id"` }
        if err := json.Unmarshal([]byte(val), &sel); err == nil {
            m.selectedID = sel.ID
        }
    }
    return nil
}

func (m *Manager) saveServers() error {
    if m.store == nil { return fmt.Errorf("sqlite store not initialized") }
    // rewrite all servers
    for _, s := range m.servers {
        b, err := json.MarshalIndent(s, "", "  ")
        if err != nil { return err }
        if err := m.store.SetItem("server", s.ID, string(b)); err != nil { return err }
    }
    return nil
}

func (m *Manager) saveSelected() error {
	selected := struct {
		ID string `json:"id"`
	}{
		ID: m.selectedID,
	}
    data, err := json.MarshalIndent(selected, "", "  ")
    if err != nil { return fmt.Errorf("failed to marshal selected: %w", err) }
    if m.store == nil { return fmt.Errorf("sqlite store not initialized") }
    return m.store.SetItem("meta", "selected", string(data))
}

func (m *Manager) GetServers() []*types.ServerConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()

	servers := make([]*types.ServerConfig, len(m.servers))
	for i, server := range m.servers {
		servers[i] = server
	}
	return servers
}

func (m *Manager) GetServer(id string) *types.ServerConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, server := range m.servers {
		if server.ID == id {
			return server
		}
	}
	return nil
}

func (m *Manager) AddServer(server *types.ServerConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if server.ID == "" { server.ID = uuid.New().String() }
	server.CreatedAt = time.Now()
	server.UpdatedAt = time.Now()
	m.servers = append(m.servers, server)
	return m.saveServers()
}

func (m *Manager) UpdateServer(server *types.ServerConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, s := range m.servers {
		if s.ID == server.ID {
			server.UpdatedAt = time.Now()
			m.servers[i] = server
			return m.saveServers()
		}
	}
	return fmt.Errorf("server not found: %s", server.ID)
}

func (m *Manager) DeleteServer(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, server := range m.servers {
		if server.ID == id {
			m.servers = append(m.servers[:i], m.servers[i+1:]...)
			if m.selectedID == id { m.selectedID = ""; m.saveSelected() }
			return m.saveServers()
		}
	}
	return fmt.Errorf("server not found: %s", id)
}

func (m *Manager) GetSelectedServer() *types.ServerConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if m.selectedID == "" { return nil }
	for _, server := range m.servers {
		if server.ID == m.selectedID { return server }
	}
	return nil
}

func (m *Manager) SetSelectedServer(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, server := range m.servers {
		if server.ID == id {
			m.selectedID = id
			return m.saveSelected()
		}
	}
	return fmt.Errorf("server not found: %s", id)
}

func (m *Manager) ClearSelectedServer() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.selectedID = ""
	return m.saveSelected()
}

func (m *Manager) ImportFromURL(url string) error { return fmt.Errorf("import from URL not implemented") }
func (m *Manager) ImportFromFile(filePath string) error { return fmt.Errorf("import from file not implemented") }
func (m *Manager) ExportToFile(filePath string) error {
	m.mu.RLock(); defer m.mu.RUnlock()
	data, err := json.MarshalIndent(m.servers, "", "  ")
	if err != nil { return fmt.Errorf("failed to marshal servers: %w", err) }
	if err := os.WriteFile(filePath, data, 0644); err != nil { return fmt.Errorf("failed to write file: %w", err) }
	return nil
}
