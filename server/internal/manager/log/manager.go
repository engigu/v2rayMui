package log

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"v2ray-mui/internal/config"
)

type LogEntry struct {
	Time    time.Time `json:"time"`
	Level   string    `json:"level"`
	Source  string    `json:"source"`
	Message string    `json:"message"`
}

type Manager struct {
	config     *config.Config
	logs       []LogEntry
	mu         sync.RWMutex
	logFile    string
	maxEntries int
}

func New(cfg *config.Config) *Manager {
	return &Manager{
		config:     cfg,
		logs:       []LogEntry{},
		logFile:    filepath.Join(cfg.Settings.DataPath, "app.log"),
		maxEntries: 1000, // 最多保存 1000 条日志
	}
}

func (m *Manager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, err := os.Stat(m.logFile); os.IsNotExist(err) {
		// 文件不存在，使用空日志
		return nil
	}

	file, err := os.Open(m.logFile)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		var entry LogEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			// 如果解析失败，创建一个简单的日志条目
			entry = LogEntry{
				Time:    time.Now(),
				Level:   "info",
				Source:  "system",
				Message: line,
			}
		}

		m.logs = append(m.logs, entry)
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("failed to read log file: %w", err)
	}

	// 限制日志条目数量
	if len(m.logs) > m.maxEntries {
		m.logs = m.logs[len(m.logs)-m.maxEntries:]
	}

	return nil
}

func (m *Manager) AddLog(level, source, message string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	entry := LogEntry{
		Time:    time.Now(),
		Level:   level,
		Source:  source,
		Message: message,
	}

	m.logs = append(m.logs, entry)

	// 限制日志条目数量
	if len(m.logs) > m.maxEntries {
		m.logs = m.logs[1:]
	}

	// 异步保存到文件
	go m.saveToFile(entry)
}

func (m *Manager) GetLogs() []LogEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// 返回副本
	logs := make([]LogEntry, len(m.logs))
	copy(logs, m.logs)

	return logs
}

// GetLastLogs 仅返回末尾最多 limit 条日志（不复制全量再切片）
func (m *Manager) GetLastLogs(limit int) []LogEntry {
    if limit <= 0 {
        return []LogEntry{}
    }
    m.mu.RLock()
    defer m.mu.RUnlock()
    total := len(m.logs)
    if total == 0 {
        return []LogEntry{}
    }
    start := total - limit
    if start < 0 {
        start = 0
    }
    out := make([]LogEntry, total-start)
    copy(out, m.logs[start:])
    return out
}

func (m *Manager) GetLogsByLevel(level string) []LogEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var filtered []LogEntry
	for _, log := range m.logs {
		if strings.ToLower(log.Level) == strings.ToLower(level) {
			filtered = append(filtered, log)
		}
	}

	return filtered
}

// GetLastLogsByLevel 从末尾向前筛选，至多返回 limit 条
func (m *Manager) GetLastLogsByLevel(level string, limit int) []LogEntry {
    if limit <= 0 {
        return []LogEntry{}
    }
    lvl := strings.ToLower(level)
    m.mu.RLock()
    defer m.mu.RUnlock()
    res := make([]LogEntry, 0, limit)
    for i := len(m.logs) - 1; i >= 0 && len(res) < limit; i-- {
        if strings.ToLower(m.logs[i].Level) == lvl {
            res = append(res, m.logs[i])
        }
    }
    // 逆序为时间正序
    for i, j := 0, len(res)-1; i < j; i, j = i+1, j-1 {
        res[i], res[j] = res[j], res[i]
    }
    return res
}

func (m *Manager) GetLogsBySource(source string) []LogEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var filtered []LogEntry
	for _, log := range m.logs {
		if strings.ToLower(log.Source) == strings.ToLower(source) {
			filtered = append(filtered, log)
		}
	}

	return filtered
}

// GetLastLogsBySource 从末尾向前筛选，至多返回 limit 条
func (m *Manager) GetLastLogsBySource(source string, limit int) []LogEntry {
    if limit <= 0 {
        return []LogEntry{}
    }
    src := strings.ToLower(source)
    m.mu.RLock()
    defer m.mu.RUnlock()
    res := make([]LogEntry, 0, limit)
    for i := len(m.logs) - 1; i >= 0 && len(res) < limit; i-- {
        if strings.ToLower(m.logs[i].Source) == src {
            res = append(res, m.logs[i])
        }
    }
    for i, j := 0, len(res)-1; i < j; i, j = i+1, j-1 {
        res[i], res[j] = res[j], res[i]
    }
    return res
}

func (m *Manager) SearchLogs(keyword string) []LogEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var filtered []LogEntry
	keyword = strings.ToLower(keyword)

	for _, log := range m.logs {
		if strings.Contains(strings.ToLower(log.Message), keyword) ||
			strings.Contains(strings.ToLower(log.Source), keyword) ||
			strings.Contains(strings.ToLower(log.Level), keyword) {
			filtered = append(filtered, log)
		}
	}

	return filtered
}

// SearchLogsLimited 从末尾向前扫描关键词，至多返回 limit 条（按时间正序返回）
func (m *Manager) SearchLogsLimited(keyword string, limit int) []LogEntry {
    if limit <= 0 {
        return []LogEntry{}
    }
    kw := strings.ToLower(keyword)
    m.mu.RLock()
    defer m.mu.RUnlock()
    res := make([]LogEntry, 0, limit)
    for i := len(m.logs) - 1; i >= 0 && len(res) < limit; i-- {
        log := m.logs[i]
        if strings.Contains(strings.ToLower(log.Message), kw) ||
            strings.Contains(strings.ToLower(log.Source), kw) ||
            strings.Contains(strings.ToLower(log.Level), kw) {
            res = append(res, log)
        }
    }
    for i, j := 0, len(res)-1; i < j; i, j = i+1, j-1 {
        res[i], res[j] = res[j], res[i]
    }
    return res
}

func (m *Manager) ClearLogs() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.logs = []LogEntry{}

	// 清空文件
	os.Remove(m.logFile)
}

func (m *Manager) ExportLogs(filePath string) error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	file, err := os.Create(filePath)
	if err != nil {
		return fmt.Errorf("failed to create export file: %w", err)
	}
	defer file.Close()

	writer := bufio.NewWriter(file)
	defer writer.Flush()

	for _, log := range m.logs {
		line, err := json.Marshal(log)
		if err != nil {
			continue
		}

		if _, err := writer.WriteString(string(line) + "\n"); err != nil {
			return fmt.Errorf("failed to write log: %w", err)
		}
	}

	return nil
}

func (m *Manager) saveToFile(entry LogEntry) {
	file, err := os.OpenFile(m.logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer file.Close()

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	file.WriteString(string(line) + "\n")
}

func (m *Manager) GetLogStats() map[string]int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	stats := make(map[string]int)

	for _, log := range m.logs {
		stats[log.Level]++
	}

	return stats
}
