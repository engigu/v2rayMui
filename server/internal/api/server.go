package api

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"v2ray-mui/internal/config"
	"v2ray-mui/internal/manager"
	"v2ray-mui/internal/types"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

type Server struct {
	config   *config.Config
	managers *manager.Managers
	router   *gin.Engine
	server   *http.Server
	upgrader websocket.Upgrader
}

func NewServer(cfg *config.Config, managers *manager.Managers) *Server {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	server := &Server{
		config:   cfg,
		managers: managers,
		router:   router,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}

	server.setupRoutes()
	return server
}

func (s *Server) setupRoutes() {
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
	}

	// 静态文件服务 - 只服务静态资源文件
	s.router.Static("/assets", "./web/dist/assets")
	s.router.StaticFile("/favicon.ico", "./web/dist/favicon.ico")

	// 处理前端路由 - 对于非 API 和非静态资源请求返回 index.html
	s.router.NoRoute(func(c *gin.Context) {
		path := c.Request.URL.Path

		// 如果是 API 请求，返回 404
		if len(path) >= 4 && path[:4] == "/api" {
			c.JSON(404, gin.H{"error": "API endpoint not found"})
			return
		}

		// 如果是静态资源请求，返回 404
		if len(path) >= 7 && path[:7] == "/assets" {
			c.JSON(404, gin.H{"error": "Static resource not found"})
			return
		}

		// 其他请求返回前端页面
		c.File("./web/dist/index.html")
	})
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
	if err := s.managers.Proxy.SetSystemProxy(); err != nil {
		s.managers.Log.AddLog("error", "proxy", fmt.Sprintf("Failed to set system proxy: %v", err))
		// 不返回错误，因为 V2Ray 已经启动
	}

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
	if err := s.managers.Proxy.ClearSystemProxy(); err != nil {
		s.managers.Log.AddLog("error", "proxy", fmt.Sprintf("Failed to clear system proxy: %v", err))
		// 不返回错误
	}

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

type CoreInfo struct {
    Version string `json:"version"`
    Running bool   `json:"running"`
    Config  any    `json:"config"`
}

func (s *Server) getCoreInfo(c *gin.Context) {
    info := CoreInfo{
        Version: s.managers.V2Ray.GetVersion(),
        Running: s.managers.V2Ray.IsRunning(),
        Config:  s.managers.V2Ray.GetConfig(),
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
                        if server.RealityPBK != "" { m["publicKey"] = server.RealityPBK }
                        if server.RealitySID != "" { m["shortId"] = server.RealitySID }
                        if server.RealitySPX != "" { m["serverName"] = server.RealitySPX }
                        if server.RealityFP  != "" { m["fingerprint"] = server.RealityFP }
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

    // 根据简单规则生成路由
    rules := []types.Rule{}
    if settings.DomainStrategy != "" || len(settings.ProxyRules)+len(settings.DirectRules)+len(settings.BlockRules) > 0 {
        config.Routing = &types.RoutingConfig{DomainStrategy: settings.DomainStrategy}
        // helper
        toDomains := func(items []string) []string { return items }
        if len(settings.ProxyRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.ProxyRules), OutboundTag: "proxy"})
        }
        if len(settings.DirectRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.DirectRules), OutboundTag: "direct"})
        }
        if len(settings.BlockRules) > 0 {
            rules = append(rules, types.Rule{Type: "field", Domain: toDomains(settings.BlockRules), OutboundTag: "block"})
        }
        config.Routing.Rules = rules
    }

	return config
}
