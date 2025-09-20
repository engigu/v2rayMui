export interface ServerConfig {
  id: string
  name: string
  type: 'vmess' | 'vless' | 'trojan' | 'shadowsocks'
  address: string
  port: number
  uuid?: string
  password?: string
  encryption?: string
  network?: 'tcp' | 'ws' | 'grpc' | 'quic' | 'xhttp'
  path?: string
  host?: string
  tls?: boolean
  insecure?: boolean
  sni?: string
  // Reality (for VLESS)
  reality?: boolean
  realityPbk?: string
  realitySid?: string
  realitySpx?: string
  realityFp?: string
  flow?: string
  alpn?: string[]
  created_at: string
  updated_at: string
  is_selected?: boolean
}

export interface AppSettings {
  autoConnect: boolean
  showInDock: boolean
  startAtLogin: boolean
  logLevel: string
  httpPort: number
  socksPort: number
  httpHost: string
  socksHost: string
  routingMode: 'global' | 'bypass' | 'direct'
  customRules: string[]
  udpEnabled: boolean
  muxEnabled: boolean
  muxConcurrency: number
  logMaxMB: number
  domainStrategy?: 'AsIs' | 'IPIfNonMatch' | 'IPOnDemand'
  proxyRules?: string[]
  directRules?: string[]
  blockRules?: string[]
}

export interface LogEntry {
  time: string
  level: string
  source: string
  message: string
}

export interface ConnectionStatus {
  connected: boolean
  status: string
  selected?: ServerConfig
}

export interface ProxyStatus {
  http_proxy?: string
  socks_proxy?: string
}
