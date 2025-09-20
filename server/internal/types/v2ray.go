package types

import "time"

// V2RayConfig 表示 V2Ray 配置
type V2RayConfig struct {
	Log       *LogConfig       `json:"log,omitempty"`
	Inbounds  []Inbound        `json:"inbounds"`
	Outbounds []Outbound       `json:"outbounds"`
	Routing   *RoutingConfig   `json:"routing,omitempty"`
	DNS       *DNSConfig       `json:"dns,omitempty"`
	Policy    *PolicyConfig    `json:"policy,omitempty"`
	Reverse   *ReverseConfig   `json:"reverse,omitempty"`
	Transport *TransportConfig `json:"transport,omitempty"`
}

type LogConfig struct {
	Access   string `json:"access,omitempty"`
	Error    string `json:"error,omitempty"`
	Loglevel string `json:"loglevel,omitempty"`
}

type Inbound struct {
	Port           int                    `json:"port"`
	Protocol       string                 `json:"protocol"`
	Settings       map[string]interface{} `json:"settings,omitempty"`
	StreamSettings *StreamSettings        `json:"streamSettings,omitempty"`
	Sniffing       *SniffingConfig        `json:"sniffing,omitempty"`
	Tag            string                 `json:"tag,omitempty"`
}

type Outbound struct {
	Protocol       string                 `json:"protocol"`
	Settings       map[string]interface{} `json:"settings,omitempty"`
	StreamSettings *StreamSettings        `json:"streamSettings,omitempty"`
	Tag            string                 `json:"tag,omitempty"`
	ProxySettings  *ProxySettings         `json:"proxySettings,omitempty"`
}

type StreamSettings struct {
	Network         string                 `json:"network,omitempty"`
	Security        string                 `json:"security,omitempty"`
	TLSSettings     map[string]interface{} `json:"tlsSettings,omitempty"`
	RealitySettings map[string]interface{} `json:"realitySettings,omitempty"`
	TCPSettings     map[string]interface{} `json:"tcpSettings,omitempty"`
	WSSettings      map[string]interface{} `json:"wsSettings,omitempty"`
	HTTPSettings    map[string]interface{} `json:"xhttpSettings,omitempty"`
	KCPSSettings    map[string]interface{} `json:"kcpSettings,omitempty"`
	QUICSettings    map[string]interface{} `json:"quicSettings,omitempty"`
	GRPCSettings    map[string]interface{} `json:"grpcSettings,omitempty"`
}

type SniffingConfig struct {
	Enabled      bool     `json:"enabled"`
	DestOverride []string `json:"destOverride,omitempty"`
}

type ProxySettings struct {
	Tag string `json:"tag,omitempty"`
}

type RoutingConfig struct {
	DomainStrategy string     `json:"domainStrategy,omitempty"`
	Rules          []Rule     `json:"rules,omitempty"`
	Balancers      []Balancer `json:"balancers,omitempty"`
}

type Rule struct {
	Type        string                 `json:"type,omitempty"`
	IP          []string               `json:"ip,omitempty"`
	Domain      []string               `json:"domain,omitempty"`
	Network     string                 `json:"network,omitempty"`
	Source      []string               `json:"source,omitempty"`
	User        []string               `json:"user,omitempty"`
	InboundTag  []string               `json:"inboundTag,omitempty"`
	Protocol    []string               `json:"protocol,omitempty"`
	Attrs       map[string]interface{} `json:"attrs,omitempty"`
	OutboundTag string                 `json:"outboundTag,omitempty"`
	BalancerTag string                 `json:"balancerTag,omitempty"`
}

type Balancer struct {
	Tag      string   `json:"tag,omitempty"`
	Selector []string `json:"selector,omitempty"`
}

type DNSConfig struct {
	Servers  []DNSServer `json:"servers,omitempty"`
	ClientIP string      `json:"clientIp,omitempty"`
	Tag      string      `json:"tag,omitempty"`
}

type DNSServer struct {
	Address string   `json:"address,omitempty"`
	Port    int      `json:"port,omitempty"`
	Domains []string `json:"domains,omitempty"`
}

type PolicyConfig struct {
	Levels map[string]LevelPolicy `json:"levels,omitempty"`
	System *SystemPolicy          `json:"system,omitempty"`
}

type LevelPolicy struct {
	Handshake         int  `json:"handshake,omitempty"`
	ConnIdle          int  `json:"connIdle,omitempty"`
	UplinkOnly        int  `json:"uplinkOnly,omitempty"`
	DownlinkOnly      int  `json:"downlinkOnly,omitempty"`
	StatsUserUplink   bool `json:"statsUserUplink,omitempty"`
	StatsUserDownlink bool `json:"statsUserDownlink,omitempty"`
	BufferSize        int  `json:"bufferSize,omitempty"`
}

type SystemPolicy struct {
	StatsInboundUplink   bool `json:"statsInboundUplink,omitempty"`
	StatsInboundDownlink bool `json:"statsInboundDownlink,omitempty"`
}

type ReverseConfig struct {
	Bridges []Bridge `json:"bridges,omitempty"`
	Portals []Portal `json:"portals,omitempty"`
}

type Bridge struct {
	Tag    string `json:"tag,omitempty"`
	Domain string `json:"domain,omitempty"`
}

type Portal struct {
	Tag    string `json:"tag,omitempty"`
	Domain string `json:"domain,omitempty"`
}

type TransportConfig struct {
	TCPConfig  *TCPConfig  `json:"tcpSettings,omitempty"`
	KCPConfig  *KCPConfig  `json:"kcpSettings,omitempty"`
	WSConfig   *WSConfig   `json:"wsSettings,omitempty"`
	HTTPConfig *HTTPConfig `json:"httpSettings,omitempty"`
	DSConfig   *DSConfig   `json:"dsSettings,omitempty"`
	QUICConfig *QUICConfig `json:"quicSettings,omitempty"`
	GRPCConfig *GRPCConfig `json:"grpcSettings,omitempty"`
}

type TCPConfig struct {
	AcceptProxyProtocol bool                   `json:"acceptProxyProtocol,omitempty"`
	HeaderConfig        map[string]interface{} `json:"header,omitempty"`
}

type KCPConfig struct {
	Mtu              int                    `json:"mtu,omitempty"`
	Tti              int                    `json:"tti,omitempty"`
	UplinkCapacity   int                    `json:"uplinkCapacity,omitempty"`
	DownlinkCapacity int                    `json:"downlinkCapacity,omitempty"`
	Congestion       bool                   `json:"congestion,omitempty"`
	ReadBufferSize   int                    `json:"readBufferSize,omitempty"`
	WriteBufferSize  int                    `json:"writeBufferSize,omitempty"`
	HeaderConfig     map[string]interface{} `json:"header,omitempty"`
	Seed             string                 `json:"seed,omitempty"`
}

type WSConfig struct {
	Path    string            `json:"path,omitempty"`
	Headers map[string]string `json:"headers,omitempty"`
}

type HTTPConfig struct {
	Host []string `json:"host,omitempty"`
	Path string   `json:"path,omitempty"`
}

type DSConfig struct {
	Path string `json:"path,omitempty"`
}

type QUICConfig struct {
	Security string                 `json:"security,omitempty"`
	Key      string                 `json:"key,omitempty"`
	Header   map[string]interface{} `json:"header,omitempty"`
}

type GRPCConfig struct {
	ServiceName         string `json:"serviceName,omitempty"`
	MultiMode           bool   `json:"multiMode,omitempty"`
	IdleTimeout         int    `json:"idleTimeout,omitempty"`
	HealthCheckTimeout  int    `json:"healthCheckTimeout,omitempty"`
	PermitWithoutStream bool   `json:"permitWithoutStream,omitempty"`
	InitialWindowsSize  int    `json:"initialWindowsSize,omitempty"`
}

// ServerConfig 表示服务器配置
type ServerConfig struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Type       string `json:"type"` // vmess, vless, trojan, shadowsocks
	Address    string `json:"address"`
	Port       int    `json:"port"`
	UUID       string `json:"uuid,omitempty"`
	Password   string `json:"password,omitempty"`
	Encryption string `json:"encryption,omitempty"`
	Network    string `json:"network,omitempty"`
	Path       string `json:"path,omitempty"`
	Host       string `json:"host,omitempty"`
	TLS        bool   `json:"tls,omitempty"`
	Insecure   bool   `json:"insecure,omitempty"`
	SNI        string `json:"sni,omitempty"`
	// Reality (for VLESS)
	Reality    bool      `json:"reality,omitempty"`
	RealityPBK string    `json:"realityPbk,omitempty"`
	RealitySID string    `json:"realitySid,omitempty"`
	RealitySPX string    `json:"realitySpx,omitempty"`
	RealityFP  string    `json:"realityFp,omitempty"`
	Flow       string    `json:"flow,omitempty"`
	Alpn       []string  `json:"alpn,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
	IsSelected bool      `json:"is_selected,omitempty"`
}

// AppSettings 表示应用设置
type AppSettings struct {
	AutoConnect    bool     `json:"autoConnect"`
	ShowInDock     bool     `json:"showInDock"`
	StartAtLogin   bool     `json:"startAtLogin"`
	LogLevel       string   `json:"logLevel"`
	HTTPPort       int      `json:"httpPort"`
	SOCKSPort      int      `json:"socksPort"`
	HTTPHost       string   `json:"httpHost"`
	SOCKSHost      string   `json:"socksHost"`
	RoutingMode    string   `json:"routingMode"` // global, bypass, direct
	CustomRules    []string `json:"customRules,omitempty"`
	UDPEnabled     bool     `json:"udpEnabled"`
	MuxEnabled     bool     `json:"muxEnabled"`
	MuxConcurrency int      `json:"muxConcurrency"`
	LogMaxMB       int      `json:"logMaxMB"`
	// 新增：简单路由规则与域名策略
	DomainStrategy string   `json:"domainStrategy,omitempty"` // AsIs, IPIfNonMatch, IPOnDemand
	ProxyRules     []string `json:"proxyRules,omitempty"`     // 走代理的域名/IP/CIDR
	DirectRules    []string `json:"directRules,omitempty"`    // 直连的域名/IP/CIDR
	BlockRules     []string `json:"blockRules,omitempty"`     // 阻止的域名/IP/CIDR
}
