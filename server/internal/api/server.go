package api

import (
	"bytes"
	"context"
	"crypto/sha1"
	"embed"
	"fmt"
	"io"
	"mime"
	"net/http"
	"path/filepath"
	"strconv"
	"sync"
	"time"
    "os"

	"v2ray-mui/internal/config"
	"v2ray-mui/internal/manager"
	"v2ray-mui/internal/types"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type Server struct {
	config    *config.Config
	managers  *manager.Managers
	router    *gin.Engine
	server    *http.Server
	upgrader  websocket.Upgrader
	startTime time.Time
	cacheMu   sync.RWMutex
	fileCache map[string]*cachedFile
}

func NewServer(cfg *config.Config, managers *manager.Managers, distFs embed.FS) *Server {
	switch cfg.Server.GinMode {
	case gin.DebugMode:
		gin.SetMode(gin.DebugMode)
	case gin.TestMode:
		gin.SetMode(gin.TestMode)
	default:
		gin.SetMode(gin.ReleaseMode)
	}
	router := gin.New()
	if cfg.Server.AccessLog {
		router.Use(gin.Logger())
	}
	router.Use(gin.Recovery())

	server := &Server{
		config:   cfg,
		managers: managers,
		router:   router,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
		startTime: time.Now(),
		fileCache: make(map[string]*cachedFile),
	}

	server.setupRoutes(distFs)
	return server
}

func (s *Server) setupRoutes(embeddedDist embed.FS) {
	// CORS 中间件
	s.router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// API 路由组
	api := s.router.Group("/api/v1")
	{
		// 状态相关
		api.GET("/status", s.getStatus)
		api.POST("/connect", s.connect)
		api.POST("/disconnect", s.disconnect)

		// 服务器配置相关
		api.GET("/servers", s.getServers)
		api.POST("/servers", s.addServer)
		api.POST("/servers/:id", s.updateServer)
		api.DELETE("/servers/:id", s.deleteServer)
		api.POST("/servers/:id/select", s.selectServer)
		api.GET("/servers/selected", s.getSelectedServer)

		// 设置相关
		api.GET("/settings", s.getSettings)
		api.POST("/settings", s.updateSettings)

		// 日志相关
		api.GET("/logs", s.getLogs)
		api.DELETE("/logs", s.clearLogs)
		api.GET("/logs/export", s.exportLogs)

		// 代理相关
		api.GET("/proxy/status", s.getProxyStatus)
		api.POST("/proxy/set", s.setProxy)
		api.POST("/proxy/clear", s.clearProxy)

		// 核心信息
		api.GET("/core/info", s.getCoreInfo)
		api.GET("/core/config", s.getCoreConfig)

		// WebSocket 连接
		api.GET("/ws", s.handleWebSocket)

		// 退出整个进程（优雅关闭后退出）
		api.POST("/exit", s.exit)
	}

	//if s.config.Web.Mode == "dev" && s.config.Web.DevURL != "" {
	if s.config.Web.Mode == "dev" {
		// 开发模式：反向代理到 Vite dev server
		//s.router.NoRoute(func(c *gin.Context) {
		//	if len(c.Request.URL.Path) >= 4 && c.Request.URL.Path[:4] == "/api" {
		//		c.JSON(404, gin.H{"error": "API endpoint not found"})
		//		return
		//	}
		//	target := fmt.Sprintf("%s%s", s.config.Web.DevURL, c.Request.URL.Path)
		//	http.Redirect(c.Writer, c.Request, target, http.StatusTemporaryRedirect)
		//})
	} else {
		// 生产模式：嵌入并服务 web/dist
		// Assets
		s.router.GET("/assets/*filepath", func(c *gin.Context) {
			f := "dist/assets" + c.Param("filepath")
			s.serveEmbedded(c, embeddedDist, f, "public, max-age=31536000, immutable")
		})
		// favicon
		s.router.GET("/icon.png", func(c *gin.Context) {
			s.serveEmbedded(c, embeddedDist, "dist/icon.png", "public, max-age=31536000, immutable")
		})
		// index.html for SPA fallback
		s.router.NoRoute(func(c *gin.Context) {
			if len(c.Request.URL.Path) >= 4 && c.Request.URL.Path[:4] == "/api" {
				c.JSON(404, gin.H{"error": "API endpoint not found"})
				return
			}
			s.serveEmbedded(c, embeddedDist, "dist/index.html", "no-cache")
		})
	}
}

type cachedFile struct {
	data     []byte
	etag     string
	modTime  time.Time
	mimeType string
	name     string
}

func (s *Server) getCached(path string) (*cachedFile, bool) {
	s.cacheMu.RLock()
	cf, ok := s.fileCache[path]
	s.cacheMu.RUnlock()
	return cf, ok
}

func (s *Server) putCached(path string, cf *cachedFile) {
	s.cacheMu.Lock()
	s.fileCache[path] = cf
	s.cacheMu.Unlock()
}

func (s *Server) serveEmbedded(c *gin.Context, fsys embed.FS, path string, cacheControl string) {
	// Try cache first
	if cf, ok := s.getCached(path); ok {
		s.serveCached(c, cf, cacheControl)
		return
	}
	// Load from embed once
	data, err := fsys.ReadFile(path)
	if err != nil {
		c.Status(404)
		return
	}
	sum := sha1.Sum(data)
	etag := fmt.Sprintf("\"%x\"", sum)
	mt := mime.TypeByExtension(filepath.Ext(path))
	if mt == "" {
		mt = http.DetectContentType(data)
	}
	cf := &cachedFile{
		data:     data,
		etag:     etag,
		modTime:  s.startTime,
		mimeType: mt,
		name:     filepath.Base(path),
	}
	s.putCached(path, cf)
	s.serveCached(c, cf, cacheControl)
}

func (s *Server) serveCached(c *gin.Context, cf *cachedFile, cacheControl string) {
	// ETag/If-None-Match
	if inm := c.Request.Header.Get("If-None-Match"); inm != "" && inm == cf.etag {
		c.Header("ETag", cf.etag)
		c.Header("Cache-Control", cacheControl)
		c.Header("Last-Modified", cf.modTime.UTC().Format(http.TimeFormat))
		c.Status(http.StatusNotModified)
		return
	}
	// Last-Modified/If-Modified-Since
	if ims := c.Request.Header.Get("If-Modified-Since"); ims != "" {
		if t, err := time.Parse(http.TimeFormat, ims); err == nil {
			if !cf.modTime.After(t) {
				c.Header("ETag", cf.etag)
				c.Header("Cache-Control", cacheControl)
				c.Header("Last-Modified", cf.modTime.UTC().Format(http.TimeFormat))
				c.Status(http.StatusNotModified)
				return
			}
		}
	}
	// Serve with headers
	c.Header("Content-Type", cf.mimeType)
	c.Header("ETag", cf.etag)
	c.Header("Cache-Control", cacheControl)
	c.Header("Last-Modified", cf.modTime.UTC().Format(http.TimeFormat))
	http.ServeContent(c.Writer, c.Request, cf.name, cf.modTime, bytes.NewReader(cf.data))
}

func (s *Server) Start() error {
	address := fmt.Sprintf("%s:%d", s.config.Server.Address, s.config.Server.Port)

	s.server = &http.Server{
		Addr:    address,
		Handler: s.router,
	}

	// 加载管理器数据
	if err := s.managers.Settings.Load(); err != nil {
		return fmt.Errorf("failed to load settings: %w", err)
	}

	if err := s.managers.Config.Load(); err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	if err := s.managers.Log.Load(); err != nil {
		return fmt.Errorf("failed to load logs: %w", err)
	}

	// 根据自动连接自动连接xray服务
	go func() {
		// small delay to ensure HTTP server is listening
		time.Sleep(500 * time.Millisecond)
		settings := s.managers.Settings.GetSettings()
		if !settings.AutoConnect {
			return
		}
		if s.managers.Config.GetSelectedServer() == nil {
			return
		}
		if s.managers.V2Ray.IsRunning() {
			return
		}
		s.managers.Log.AddLog("info", "system", "statupAutoConnect: calling /api/v1/connect")
		url := fmt.Sprintf("http://%s:%d/api/v1/connect", s.config.Server.Address, s.config.Server.Port)
		resp, err := http.Post(url, "application/json", nil)
		if err != nil {
			s.managers.Log.AddLog("error", "system", fmt.Sprintf("statup AutoConnect request failed: %v", err))
			return
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
		if resp.StatusCode >= 400 {
			s.managers.Log.AddLog("error", "system", fmt.Sprintf("statup AutoConnect response status: %d", resp.StatusCode))
			return
		}
		s.managers.Log.AddLog("info", "system", "statup AutoConnect: connect request sent")
	}()

	return s.server.ListenAndServe()
}

func (s *Server) Stop(ctx context.Context) error {
	if s.server != nil {
		return s.server.Shutdown(ctx)
	}
	return nil
}

// API 处理函数

func (s *Server) getStatus(c *gin.Context) {
	status := map[string]interface{}{
		"connected": s.managers.V2Ray.IsRunning(),
		"status":    s.managers.V2Ray.GetStatus(),
		"selected":  s.managers.Config.GetSelectedServer(),
	}

	c.JSON(200, status)
}

func (s *Server) connect(c *gin.Context) {
	selectedServer := s.managers.Config.GetSelectedServer()
	if selectedServer == nil {
		c.JSON(400, gin.H{"error": "no server selected"})
		return
	}

	// 生成 V2Ray 配置
	v2rayConfig := s.generateV2RayConfig(selectedServer)

	// 启动 V2Ray
	if err := s.managers.V2Ray.Start(v2rayConfig); err != nil {
		s.managers.Log.AddLog("error", "v2ray", fmt.Sprintf("Failed to start V2Ray: %v", err))
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	// 设置系统代理
	// 已迁移到 Swift 侧设置系统代理，此处不再调用

	s.managers.Log.AddLog("info", "system", "Connected to server")
	c.JSON(200, gin.H{"message": "connected"})
}

func (s *Server) disconnect(c *gin.Context) {
	// 停止 V2Ray
	if err := s.managers.V2Ray.Stop(); err != nil {
		s.managers.Log.AddLog("error", "v2ray", fmt.Sprintf("Failed to stop V2Ray: %v", err))
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	// 清除系统代理
	// 已迁移到 Swift 侧清除系统代理，此处不再调用

	s.managers.Log.AddLog("info", "system", "Disconnected from server")
	c.JSON(200, gin.H{"message": "disconnected"})
}

func (s *Server) getServers(c *gin.Context) {
	servers := s.managers.Config.GetServers()
	c.JSON(200, servers)
}

func (s *Server) addServer(c *gin.Context) {
	var server types.ServerConfig
	if err := c.ShouldBindJSON(&server); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	if err := s.managers.Config.AddServer(&server); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	s.managers.Log.AddLog("info", "config", fmt.Sprintf("Added server: %s", server.Name))
	c.JSON(201, server)
}

func (s *Server) updateServer(c *gin.Context) {
	id := c.Param("id")

	var server types.ServerConfig
	if err := c.ShouldBindJSON(&server); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	server.ID = id
	if err := s.managers.Config.UpdateServer(&server); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	s.managers.Log.AddLog("info", "config", fmt.Sprintf("Updated server: %s", server.Name))
	c.JSON(200, server)
}

func (s *Server) deleteServer(c *gin.Context) {
	id := c.Param("id")

	if err := s.managers.Config.DeleteServer(id); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	s.managers.Log.AddLog("info", "config", fmt.Sprintf("Deleted server: %s", id))
	c.JSON(200, gin.H{"message": "deleted"})
}

func (s *Server) selectServer(c *gin.Context) {
	id := c.Param("id")

	if err := s.managers.Config.SetSelectedServer(id); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	s.managers.Log.AddLog("info", "config", fmt.Sprintf("Selected server: %s", id))
	c.JSON(200, gin.H{"message": "selected"})
}

func (s *Server) getSelectedServer(c *gin.Context) {
	server := s.managers.Config.GetSelectedServer()
	c.JSON(200, server)
}

func (s *Server) getSettings(c *gin.Context) {
	settings := s.managers.Settings.GetSettings()
	c.JSON(200, settings)
}

func (s *Server) updateSettings(c *gin.Context) {
	var settings types.AppSettings
	if err := c.ShouldBindJSON(&settings); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	if err := s.managers.Settings.UpdateSettings(&settings); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	s.managers.Log.AddLog("info", "settings", "Settings updated")
	c.JSON(200, settings)
}

func (s *Server) getLogs(c *gin.Context) {
	level := c.Query("level")
	source := c.Query("source")
	search := c.Query("search")
	limit := 50
	if l := c.Query("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 {
			limit = n
		}
	}

	var logs interface{}

	if level != "" {
		logs = s.managers.Log.GetLastLogsByLevel(level, limit)
	} else if source != "" {
		logs = s.managers.Log.GetLastLogsBySource(source, limit)
	} else if search != "" {
		logs = s.managers.Log.SearchLogsLimited(search, limit)
	} else {
		logs = s.managers.Log.GetLastLogs(limit)
	}

	c.JSON(200, logs)
}

func (s *Server) clearLogs(c *gin.Context) {
	s.managers.Log.ClearLogs()
	s.managers.Log.AddLog("info", "system", "Logs cleared")
	c.JSON(200, gin.H{"message": "cleared"})
}

func (s *Server) exportLogs(c *gin.Context) {
	filePath := c.Query("file")
	if filePath == "" {
		filePath = fmt.Sprintf("logs_%d.json", time.Now().Unix())
	}

	if err := s.managers.Log.ExportLogs(filePath); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "exported", "file": filePath})
}

func (s *Server) getProxyStatus(c *gin.Context) {
	status, err := s.managers.Proxy.GetProxyStatus()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, status)
}

func (s *Server) setProxy(c *gin.Context) {
	if err := s.managers.Proxy.SetSystemProxy(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "proxy set"})
}

func (s *Server) clearProxy(c *gin.Context) {
	if err := s.managers.Proxy.ClearSystemProxy(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "proxy cleared"})
}

// 退出整个 Go 进程：
// 1) 停止 xray (忽略错误)
// 2) 清理系统代理 (忽略错误)
// 3) 优雅关闭 HTTP 服务器
// 4) 立即退出进程
func (s *Server) exit(c *gin.Context) {
    // 先返回响应，避免客户端因连接被断开而报错
    go func() {
        // 给响应发送一点点时间
        time.Sleep(100 * time.Millisecond)

        // 停止 V2Ray
        _ = s.managers.V2Ray.Stop()
        // 清理系统代理
        _ = s.managers.Proxy.ClearSystemProxy()

        // 优雅关闭 HTTP 服务器
        ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
        defer cancel()
        _ = s.Stop(ctx)

        // 退出进程
        os.Exit(0)
    }()

    c.JSON(200, gin.H{"message": "exiting"})
}

type CoreInfo struct {
	Version string `json:"version"`
	Running bool   `json:"running"`
	Config  any    `json:"config"`
	BinPath string `json:"binPath"`
}

func (s *Server) getCoreInfo(c *gin.Context) {
	info := CoreInfo{
		Version: s.managers.V2Ray.GetVersion(),
		Running: s.managers.V2Ray.IsRunning(),
		Config:  s.managers.V2Ray.GetConfig(),
		BinPath: s.managers.V2Ray.GetBinaryPath(),
	}
	c.JSON(200, info)
}

// 返回当前生成用于 xray 的 JSON 配置
func (s *Server) getCoreConfig(c *gin.Context) {
	cfg := s.managers.V2Ray.GetConfig()
	if cfg == nil {
		c.JSON(404, gin.H{"error": "no config available"})
		return
	}
	c.IndentedJSON(200, cfg)
}

func (s *Server) handleWebSocket(c *gin.Context) {
	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	// 这里可以实现 WebSocket 实时日志推送等功能
	for {
		// 保持连接活跃
		time.Sleep(30 * time.Second)
		if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
			break
		}
	}
}

// 辅助函数

func (s *Server) generateV2RayConfig(server *types.ServerConfig) *types.V2RayConfig {
	// 这里根据服务器配置生成 V2Ray 配置
	// 这是一个简化的实现，实际需要根据不同的协议类型生成不同的配置

	settings := s.managers.Settings.GetSettings()

	config := &types.V2RayConfig{
		Log: &types.LogConfig{
			Loglevel: settings.LogLevel,
		},
		Inbounds: []types.Inbound{
			{
				Port:     settings.HTTPPort,
				Protocol: "http",
				Tag:      "http",
			},
			{
				Port:     settings.SOCKSPort,
				Protocol: "socks",
				Tag:      "socks",
				Settings: map[string]interface{}{
					"udp": settings.UDPEnabled,
				},
			},
		},
		Outbounds: []types.Outbound{
			{
				Protocol: server.Type,
				Tag:      "proxy",
				Settings: map[string]interface{}{
					"vnext": []map[string]interface{}{
						{
							"address": server.Address,
							"port":    server.Port,
							"users": []map[string]interface{}{
								{
									"id":       server.UUID,
									"security": server.Encryption,
								},
							},
						},
					},
				},
				StreamSettings: &types.StreamSettings{
					Security: func() string {
						if server.Reality {
							return "reality"
						}
						if server.TLS {
							return "tls"
						}
						return ""
					}(),
					Network: server.Network,
					TLSSettings: func() map[string]interface{} {
						if server.Reality { // skip TLS when Reality is enabled
							return nil
						}
						if !server.TLS {
							return nil
						}
						m := map[string]interface{}{}
						if server.SNI != "" {
							m["serverName"] = server.SNI
						}
						if server.Insecure {
							m["allowInsecure"] = true
						}
						return m
					}(),
					RealitySettings: func() map[string]interface{} {
						if !server.Reality {
							return nil
						}
						m := map[string]interface{}{}
						if server.RealityPBK != "" {
							m["publicKey"] = server.RealityPBK
						}
						if server.RealitySID != "" {
							m["shortId"] = server.RealitySID
						}
						if server.RealitySPX != "" {
							m["serverName"] = server.RealitySPX
						}
						if server.RealityFP != "" {
							m["fingerprint"] = server.RealityFP
						}
						return m
					}(),
					HTTPSettings: func() map[string]interface{} {
						if server.Network != "xhttp" {
							return nil
						}
						m := map[string]interface{}{}
						if server.Host != "" {
							m["host"] = []string{server.Host}
						}
						if server.Path != "" {
							m["path"] = server.Path
						}
						return m
					}(),
					WSSettings: func() map[string]interface{} {
						if server.Network != "ws" {
							return nil
						}
						m := map[string]interface{}{}
						if server.Host != "" {
							m["headers"] = map[string]string{"Host": server.Host}
						}
						if server.Path != "" {
							m["path"] = server.Path
						}
						return m
					}(),
				},
				Mux: func() map[string]interface{} {
					if !settings.MuxEnabled {
						return nil
					}
					m := map[string]interface{}{
						"enabled": true,
					}
					if settings.MuxConcurrency > 0 {
						m["concurrency"] = settings.MuxConcurrency
					}
					return m
				}(),
			},
			{
				Protocol: "freedom",
				Tag:      "direct",
			},
			{
				Protocol: "blackhole",
				Tag:      "block",
			},
		},
	}

    // 路由规则
    rules := []types.Rule{}
    // 基础：根据界面自定义规则
    if settings.DomainStrategy != "" || len(settings.ProxyRules)+len(settings.DirectRules)+len(settings.BlockRules) > 0 || settings.RoutingMode != "" {
        // 如果没有配置 DomainStrategy，且开启了绕过大陆，给一个更合理的默认
        domainStrategy := settings.DomainStrategy
        if domainStrategy == "" && settings.RoutingMode == "bypass" {
            domainStrategy = "IPIfNonMatch"
        }
        config.Routing = &types.RoutingConfig{DomainStrategy: domainStrategy}

        // 界面自定义规则优先加入（更靠前）
        toDomains := func(items []string) []string { return items }
        if len(settings.DirectRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.DirectRules), OutboundTag: "direct"})
        }
        if len(settings.BlockRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.BlockRules), OutboundTag: "block"})
        }
        if len(settings.ProxyRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.ProxyRules), OutboundTag: "proxy"})
        }

        // 模式：绕过大陆（国内直连，国外代理）
        if settings.RoutingMode == "bypass" {
            // 国内域名直连
            rules = append(rules, types.Rule{Type: "field", Domain: []string{"geosite:cn", "domain:localhost"}, OutboundTag: "direct"})
            // 国内与私网 IP 直连
            rules = append(rules, types.Rule{Type: "field", IP: []string{"geoip:cn", "geoip:private"}, OutboundTag: "direct"})
            // 其余域名走代理
            rules = append(rules, types.Rule{Type: "field", Domain: []string{"geosite:geolocation-!cn"}, OutboundTag: "proxy"})
            // 兜底不再添加无条件规则，避免 “this rule has no effective fields” 错误；
            // 无匹配流量将按 outbounds 顺序走第一个（本配置为 proxy）。
        }

        config.Routing.Rules = rules
    }

	return config
}
