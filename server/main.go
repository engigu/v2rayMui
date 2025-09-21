package main

import (
	"embed"
	"flag"
	"log"
	"os"
	"strconv"
	"v2ray-mui/internal/api"
	"v2ray-mui/internal/config"
	"v2ray-mui/internal/logging"
	"v2ray-mui/internal/manager"
)

// Embed bin directory next to main.go

//go:embed dist/* dist/**
var embeddedDist embed.FS

func main() {
	// 命令行参数：-datapath 覆盖 settings.data_path
	dataPathFlag := flag.String("datapath", "", "override settings.data_path directory")
	binPathFlag := flag.String("binpath", "", "override v2ray.binary_path")
	portFlag := flag.Int("port", 0, "override server.port")
	flag.Parse()

	// 加载配置
	cfg, err := config.Load()
	if err != nil {
		log.Printf("Failed to load config: %v", err)
	}

	// 接收命令行指定运行数据路径
	if dataPathFlag != nil && *dataPathFlag != "" {
		cfg.Settings.DataPath = *dataPathFlag
		if err := os.MkdirAll(cfg.Settings.DataPath, 0755); err != nil {
			log.Fatalf("Failed to create data path %s: %v", cfg.Settings.DataPath, err)
		}
		log.Printf("Using data path from flag: %s", cfg.Settings.DataPath)
	}

	// 环境变量 SERVER_PORT 或命令行 -port 优先覆盖 server.port
	if envPort := os.Getenv("SERVER_PORT"); envPort != "" {
		if p, err := strconv.Atoi(envPort); err == nil {
			cfg.Server.Port = p
		} else {
			log.Printf("Invalid SERVER_PORT value %q, ignoring", envPort)
		}
	}
	if portFlag != nil && *portFlag != 0 {
		cfg.Server.Port = *portFlag
	}

	// Initialize logging (Gin + std log) to rolling file under dataPath/logs/ginserver.log
	if err := logging.InitGinLogging(cfg.Settings.DataPath); err != nil {
		log.Fatalf("Failed to init logging: %v", err)
	}

	// 覆盖 v2ray.binary_path
	if binPathFlag != nil && *binPathFlag != "" {
		cfg.V2Ray.BinaryPath = *binPathFlag
		log.Printf("Using v2ray binary path from flag: %s", cfg.V2Ray.BinaryPath)
	}

	// 初始化管理器
	managers := manager.NewManagers(cfg)

	// 启动 API 服务器
	server := api.NewServer(cfg, managers, embeddedDist)

	log.Printf("Starting server on %s:%d", cfg.Server.Address, cfg.Server.Port)
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
