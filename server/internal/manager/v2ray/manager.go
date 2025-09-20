package v2ray

import (
    "bytes"
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"v2ray-mui/internal/config"
	applog "v2ray-mui/internal/manager/log"
	"v2ray-mui/internal/types"
)

type Manager struct {
	config     *config.Config
	process    *exec.Cmd
	ctx        context.Context
	cancel     context.CancelFunc
	mu         sync.RWMutex
	isRunning  bool
	status     string
	configData *types.V2RayConfig
	logger     *applog.Manager
}

func New(cfg *config.Config, logger *applog.Manager) *Manager {
	return &Manager{
		config: cfg,
		status: "disconnected",
		logger: logger,
	}
}

func (m *Manager) Start(config *types.V2RayConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.isRunning {
		return fmt.Errorf("v2ray is already running")
	}

	// 保存配置
	m.configData = config

	// 生成配置文件
	if err := m.generateConfig(config); err != nil {
		return fmt.Errorf("failed to generate config: %w", err)
	}

	// 创建上下文
	m.ctx, m.cancel = context.WithCancel(context.Background())

	// 启动进程
	m.process = exec.CommandContext(m.ctx, m.config.V2Ray.BinaryPath, "-config", m.config.V2Ray.ConfigPath)
	stdout, _ := m.process.StdoutPipe()
	stderr, _ := m.process.StderrPipe()

	if err := m.process.Start(); err != nil {
		m.cancel()
		return fmt.Errorf("failed to start v2ray: %w", err)
	}

	m.isRunning = true
	m.status = "connected"

	// 采集 xray 日志
	go m.captureOutput(stdout, "info")
	go m.captureOutput(stderr, "error")

	// 监控进程
	go m.monitorProcess()

	return nil
}

func (m *Manager) Stop() error {
	m.mu.Lock()
	if !m.isRunning {
		m.mu.Unlock()
		return nil
	}
	cancel := m.cancel
	proc := m.process
	// 先更新状态，避免上层长时间等待
	m.isRunning = false
	m.status = "disconnected"
	m.mu.Unlock()

	if cancel != nil {
		cancel()
	}

	// 超时则强杀，避免阻塞调用方
	go func(cmd *exec.Cmd) {
		if cmd == nil {
			return
		}
		time.Sleep(3 * time.Second)
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
	}(proc)

	return nil
}

func (m *Manager) IsRunning() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.isRunning
}

func (m *Manager) GetStatus() string {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.status
}

func (m *Manager) GetConfig() *types.V2RayConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.configData
}

func (m *Manager) generateConfig(config *types.V2RayConfig) error {
	configData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(m.config.V2Ray.ConfigPath, configData, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

func (m *Manager) monitorProcess() {
	if m.process == nil {
		return
	}

	err := m.process.Wait()
	if err != nil {
		m.mu.Lock()
		m.isRunning = false
		m.status = "error"
		m.mu.Unlock()
	}
}

func (m *Manager) captureOutput(pipe io.ReadCloser, level string) {
	if pipe == nil || m.logger == nil {
		return
	}
	reader := bufio.NewScanner(pipe)
	for reader.Scan() {
		line := strings.TrimSpace(reader.Text())
		if line != "" {
			m.logger.AddLog(level, "xray", line)
		}
	}
}

// GetVersion 返回 xray 核心版本字符串（带超时保护）
func (m *Manager) GetVersion() string {
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()
    cmd := exec.CommandContext(ctx, m.config.V2Ray.BinaryPath, "-version")
    var buf bytes.Buffer
    cmd.Stdout = &buf
    cmd.Stderr = &buf
    if err := cmd.Run(); err != nil {
        return ""
    }
    return strings.TrimSpace(buf.String())
}

func (m *Manager) DownloadBinary() error {
	// 这里可以实现下载 xray 二进制文件的逻辑
	// 根据操作系统和架构下载对应的版本
	return fmt.Errorf("download binary not implemented")
}

func (m *Manager) GetLogs() ([]string, error) {
	// 读取日志文件
	logFile := m.config.V2Ray.LogPath
	if _, err := os.Stat(logFile); os.IsNotExist(err) {
		return []string{}, nil
	}

	content, err := os.ReadFile(logFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read log file: %w", err)
	}

	// 简单的按行分割，实际实现可能需要更复杂的日志解析
	lines := []string{}
	contentStr := string(content)
	contentLines := strings.Split(contentStr, "\n")
	for _, line := range contentLines {
		if strings.TrimSpace(line) != "" {
			lines = append(lines, line)
		}
	}

	return lines, nil
}
