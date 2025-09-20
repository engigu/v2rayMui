package manager

import (
	"v2ray-mui/internal/config"
	"v2ray-mui/internal/manager/configmgr"
	"v2ray-mui/internal/manager/log"
	"v2ray-mui/internal/manager/proxy"
	"v2ray-mui/internal/manager/settings"
	"v2ray-mui/internal/manager/v2ray"
)

type Managers struct {
	V2Ray    *v2ray.Manager
	Proxy    *proxy.Manager
	Settings *settings.Manager
	Config   *configmgr.Manager
	Log      *log.Manager
}

func NewManagers(cfg *config.Config) *Managers {
    m := &Managers{
        Proxy:    proxy.New(cfg),
        Settings: settings.New(cfg),
        Config:   configmgr.New(cfg),
        Log:      log.New(cfg),
    }
    m.V2Ray = v2ray.New(cfg, m.Log)
    return m
}
