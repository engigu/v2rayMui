package config

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	V2Ray    V2RayConfig    `mapstructure:"v2ray"`
	Proxy    ProxyConfig    `mapstructure:"proxy"`
	Log      LogConfig      `mapstructure:"log"`
	Settings SettingsConfig `mapstructure:"settings"`
}

type ServerConfig struct {
	Address string `mapstructure:"address"`
	Port    int    `mapstructure:"port"`
}

type V2RayConfig struct {
	BinaryPath string `mapstructure:"binary_path"`
	ConfigPath string `mapstructure:"config_path"`
	LogPath    string `mapstructure:"log_path"`
}

type ProxyConfig struct {
	HTTP  ProxyEndpoint `mapstructure:"http"`
	SOCKS ProxyEndpoint `mapstructure:"socks"`
}

type ProxyEndpoint struct {
	Host string `mapstructure:"host"`
	Port int    `mapstructure:"port"`
}

type LogConfig struct {
	Level  string `mapstructure:"level"`
	MaxAge int    `mapstructure:"max_age"`
}

type SettingsConfig struct {
	DataPath string `mapstructure:"data_path"`
}

func Load() (*Config, error) {
	// 设置默认值
	viper.SetDefault("server.address", "127.0.0.1")
	viper.SetDefault("server.port", 58080)
	viper.SetDefault("v2ray.binary_path", "./bin/xray")
	viper.SetDefault("v2ray.config_path", "./config.json")
	viper.SetDefault("v2ray.log_path", "./logs/v2ray.log")
	viper.SetDefault("proxy.http.host", "127.0.0.1")
	viper.SetDefault("proxy.http.port", 1087)
	viper.SetDefault("proxy.socks.host", "127.0.0.1")
	viper.SetDefault("proxy.socks.port", 1088)
	viper.SetDefault("log.level", "info")
	viper.SetDefault("log.max_age", 7)
	viper.SetDefault("settings.data_path", "./data")

	// 设置配置文件
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("$HOME/.v2ray-mui")

	// 优先使用 config.yaml，避免同目录下的 config.json 被优先匹配
	{
		searchPaths := []string{".", "./config", os.ExpandEnv("$HOME/.v2ray-mui")}
		for _, p := range searchPaths {
			path := filepath.Join(p, "config.yaml")
			if _, err := os.Stat(path); err == nil {
				viper.SetConfigFile(path)
				break
			}
		}
	}

	// 读取配置文件
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// 配置文件不存在，使用默认值
	}

	// 环境变量覆盖
	viper.AutomaticEnv()

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// 确保目录存在
	if err := ensureDirectories(&config); err != nil {
		return nil, fmt.Errorf("failed to create directories: %w", err)
	}
	log.Println("Using config file:", viper.ConfigFileUsed())
	return &config, nil
}

func ensureDirectories(config *Config) error {
	dirs := []string{
		filepath.Dir(config.V2Ray.ConfigPath),
		filepath.Dir(config.V2Ray.LogPath),
		config.Settings.DataPath,
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}

	return nil
}
