package main

import (
	"log"
	"v2ray-mui/internal/api"
	"v2ray-mui/internal/config"
	"v2ray-mui/internal/manager"
)

func main() {
	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// 初始化管理器
	managers := manager.NewManagers(cfg)

	// 启动 API 服务器
	server := api.NewServer(cfg, managers)

	log.Printf("Starting server on %s:%d", cfg.Server.Address, cfg.Server.Port)
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
