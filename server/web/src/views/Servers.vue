<template>
  <div class="p-4">
    <div class="mb-3 flex justify-between items-center">
      <div>
        <h2 class="text-xl font-bold text-foreground">服务器管理</h2>
        <p class="text-sm text-muted-foreground">管理您的V2Ray服务器配置</p>
      </div>
      <div class="flex gap-2">
        <Button variant="outline" @click="importFromClipboard">
          <ClipboardPaste class="w-4 h-4 mr-2" />
          从剪贴板导入
        </Button>
        <Button @click="onAddClick">
          <Plus class="w-4 h-4 mr-2" />
          添加服务器
        </Button>
      </div>
    </div>

    <!-- 服务器列表 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
      <Card
        v-for="server in servers"
        :key="server.id"
        class="cursor-pointer aurora glass hover-lift card-glow smooth-in"
        :class="{ 'ring-2 ring-primary': server.id === selectedServerId }"
        @click="selectServer(server.id)"
      >
        <CardHeader>
          <div class="flex justify-between items-start">
            <CardTitle class="text-lg">{{ server.name }}</CardTitle>
            <div class="flex space-x-2">
              <Button
                size="sm"
                variant="outline"
                @click.stop="editServer(server)"
              >
                <Edit class="w-4 h-4" />
              </Button>
              <Button
                size="sm"
                variant="destructive"
                @click.stop="deleteServer(server.id)"
              >
                <Trash2 class="w-4 h-4" />
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-muted-foreground">地址</span>
              <span class="text-sm font-mono">{{ server.address }}:{{ server.port }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-foreground">协议</span>
              <span class="text-sm">{{ server.type.toUpperCase() }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted-foreground">状态</span>
              <Badge :variant="server.id === selectedServerId ? 'default' : 'secondary'">
                {{ server.id === selectedServerId ? '已选择' : '未选择' }}
              </Badge>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- 添加/编辑服务器对话框 -->
    <Dialog v-model:open="showAddDialog">
      <DialogContent :key="editingServer?.id || 'new'">
        <DialogHeader>
          <DialogTitle>{{ editingServer ? '编辑服务器' : '添加服务器' }}</DialogTitle>
          <DialogDescription>编辑或添加V2Ray服务器配置</DialogDescription>
        </DialogHeader>
        <form @submit.prevent="saveServer" class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <Label for="name">名称</Label>
              <Input
                id="name"
                v-model="serverForm.name"
                placeholder="服务器名称"
                required
              />
            </div>
            <div>
              <Label for="type">协议类型</Label>
              <Select v-model="serverForm.type">
                <SelectTrigger>
                  <SelectValue placeholder="选择协议" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="vmess">VMess</SelectItem>
                  <SelectItem value="vless">VLESS</SelectItem>
                  <SelectItem value="trojan">Trojan</SelectItem>
                  <SelectItem value="shadowsocks">Shadowsocks</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <Label for="address">地址</Label>
              <Input
                id="address"
                v-model="serverForm.address"
                placeholder="服务器地址"
                required
              />
            </div>
            <div>
              <Label for="port">端口</Label>
              <Input
                id="port"
                v-model.number="serverForm.port"
                type="number"
                placeholder="端口号"
                required
              />
            </div>
          </div>

          <div v-if="serverForm.type === 'vmess' || serverForm.type === 'vless'">
            <Label for="uuid">UUID</Label>
            <Input
              id="uuid"
              v-model="serverForm.uuid"
              placeholder="用户 UUID"
            />
          </div>

          <div v-if="serverForm.type === 'trojan' || serverForm.type === 'shadowsocks'">
            <Label for="password">密码</Label>
            <Input
              id="password"
              v-model="serverForm.password"
              type="password"
              placeholder="密码"
            />
          </div>

          <div v-if="serverForm.type === 'vmess'">
            <Label for="encryption">加密方式</Label>
            <Select v-model="serverForm.encryption">
              <SelectTrigger>
                <SelectValue placeholder="选择加密方式" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="auto">auto</SelectItem>
                <SelectItem value="aes-128-gcm">aes-128-gcm</SelectItem>
                <SelectItem value="chacha20-poly1305">chacha20-poly1305</SelectItem>
                <SelectItem value="none">none</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <Label for="network">传输协议</Label>
              <Select v-model="serverForm.network">
                <SelectTrigger>
                  <SelectValue placeholder="选择传输协议" />
                </SelectTrigger>
              <SelectContent>
                <SelectItem value="tcp">TCP</SelectItem>
                <SelectItem value="ws">WebSocket</SelectItem>
                <SelectItem value="grpc">gRPC</SelectItem>
                <SelectItem value="quic">QUIC</SelectItem>
                <SelectItem value="xhttp">xHTTP</SelectItem>
              </SelectContent>
              </Select>
            </div>
            <div v-if="serverForm.network === 'ws' || serverForm.network === 'xhttp'">
              <Label for="path">路径</Label>
              <Input
                id="path"
                v-model="serverForm.path"
                placeholder="/path"
              />
            </div>
          </div>

          <div v-if="serverForm.network === 'ws' || serverForm.network === 'grpc' || serverForm.network === 'xhttp'">
            <Label for="host">Host</Label>
            <Input
              id="host"
              v-model="serverForm.host"
              placeholder="Host 头"
            />
          </div>

          <div class="flex items-center space-x-2">
            <Checkbox id="tls" :disabled="Boolean((serverForm as any).reality)" v-model:checked="(serverForm as any).tls" @update:checked="v => { if (!(serverForm as any).reality) { console.log('tls update', v); (serverForm as any).tls = !!v } }" />
            <Label for="tls" @click.prevent="!((serverForm as any).reality) && ((serverForm as any).tls = !(serverForm as any).tls)">启用TLS</Label>
            <span class="text-xs text-muted-foreground">(tls={{ String(serverForm.tls) }})</span>
          </div>

          <div v-if="serverForm.tls && !((serverForm as any).reality)" class="space-y-3">
            <Label for="sni">SNI</Label>
            <Input
              id="sni"
              v-model="serverForm.sni"
              placeholder="SNI"
            />
            <div class="flex items-center space-x-2">
              <Checkbox id="insecure" v-model:checked="(serverForm as any).insecure" @update:checked="v => { console.log('insecure update', v); (serverForm as any).insecure = !!v }" />
              <Label for="insecure" @click.prevent="(serverForm as any).insecure = !(serverForm as any).insecure">允许不安全连接（跳过证书验证）</Label>
              <span class="text-xs text-muted-foreground">(insecure={{ String(serverForm.insecure) }})</span>
            </div>
          </div>

          <!-- Reality (VLESS) -->
          <div v-if="serverForm.type === 'vless'" class="space-y-3">
            <div class="flex items-center space-x-2">
              <Checkbox id="reality" v-model:checked="(serverForm as any).reality" @update:checked="v => { (serverForm as any).reality = !!v; if (v) { (serverForm as any).tls = false } }" />
              <Label for="reality" @click.prevent="(serverForm as any).reality = !(serverForm as any).reality">启用 Reality</Label>
              <span class="text-xs text-muted-foreground">(reality={{ String((serverForm as any).reality) }})</span>
            </div>

            <div v-if="(serverForm as any).reality" class="grid grid-cols-2 gap-4">
              <div>
                <Label for="pbk">公钥（pbk）</Label>
                <Input id="pbk" v-model="(serverForm as any).realityPbk" placeholder="pbk" />
              </div>
              <div>
                <Label for="sid">短 ID（sid）</Label>
                <Input id="sid" v-model="(serverForm as any).realitySid" placeholder="sid" />
              </div>
              <div>
                <Label for="spx">伪装域名（spx）</Label>
                <Input id="spx" v-model="(serverForm as any).realitySpx" placeholder="spx，例如 www.apple.com:443" />
              </div>
              <div>
                <Label for="fp">指纹（fp）</Label>
                <Input id="fp" v-model="(serverForm as any).realityFp" placeholder="chrome, safari..." />
              </div>
              <div>
                <Label for="flow">流控（flow）</Label>
                <Input id="flow" v-model="(serverForm as any).flow" placeholder="xtls-rprx-vision" />
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" @click="cancelEdit">
              取消
            </Button>
            <Button type="submit" :disabled="loading">
              {{ editingServer ? '更新' : '添加' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import { Plus, Edit, Trash2, ClipboardPaste } from 'lucide-vue-next'
import { useServersStore } from '@/stores/servers'
import { useStatusStore } from '@/stores/status'
import type { ServerConfig } from '@/types'
import { useToast } from '@/components/ui/toast/use-toast'

const { toast } = useToast()

const serversStore = useServersStore()
const statusStore = useStatusStore()

const showAddDialog = ref(false)
const editingServer = ref<ServerConfig | null>(null)
const loading = ref(false)

const servers = computed(() => serversStore.servers)
const selectedServerId = computed(() => serversStore.selectedServerId)

type NetworkKind = 'tcp' | 'ws' | 'grpc' | 'quic' | 'xhttp'

const serverForm = ref<{
  name: string
  type: 'vmess' | 'vless' | 'trojan' | 'shadowsocks'
  address: string
  port: number
  uuid: string
  password: string
  encryption: string
  network: NetworkKind
  path: string
  host: string
  tls: boolean
  insecure: boolean
  sni: string
  // Reality
  reality?: boolean
  realityPbk?: string
  realitySid?: string
  realitySpx?: string
  realityFp?: string
  flow?: string
}>({
  name: '',
  type: 'vmess',
  address: '',
  port: 443,
  uuid: '',
  password: '',
  encryption: 'auto',
  network: 'tcp',
  path: '',
  host: '',
  tls: false,
  insecure: false,
  sni: ''
})

const selectServer = async (id: string) => {
  try {
    await serversStore.selectServer(id)
    toast({ title: '已选择服务器', description: '正在重新连接 Xray...' })
    if (statusStore.status.connected) {
      await statusStore.disconnect()
    }
    await statusStore.connect()
    toast({ title: '连接完成', description: '已切换至所选服务器' })
  } catch (e) {
    toast({ title: '切换失败', description: (e as Error).message || '请稍后再试', variant: 'destructive' })
  }
}

function asNetwork(n?: string): NetworkKind {
  return (n === 'ws' || n === 'grpc' || n === 'quic' || n === 'xhttp') ? n : 'tcp'
}

const editServer = (server: ServerConfig) => {
  editingServer.value = server
  console.log('insecure', server.tls, server.insecure)
  serverForm.value = {
    name: server.name,
    type: server.type,
    address: server.address,
    port: server.port,
    uuid: server.uuid || '',
    password: server.password || '',
    encryption: server.encryption || 'auto',
    network: asNetwork(server.network),
    path: server.path || '',
    host: server.host || '',
    tls: Boolean(server.tls),
    insecure: Boolean((server as any).insecure),
    sni: server.sni || ''
    ,reality: (server as any).reality || false
    ,realityPbk: (server as any).realityPbk || ''
    ,realitySid: (server as any).realitySid || ''
    ,realitySpx: (server as any).realitySpx || ''
    ,realityFp: (server as any).realityFp || ''
    ,flow: (server as any).flow || ''
  }
  console.log('serverForm', serverForm.value)
  showAddDialog.value = true
}

const deleteServer = async (id: string) => {
  if (confirm('确定要删除这个服务器吗？')) {
    await serversStore.deleteServer(id)
  }
}

const saveServer = async () => {
  loading.value = true
  try {
    if (editingServer.value && editingServer.value.id) {
      const updateData: Partial<ServerConfig> & { id: string } = {
        ...serverForm.value,
        insecure: !!serverForm.value.insecure,
        id: editingServer.value.id
      }
      await serversStore.updateServer(updateData)
    } else {
      const createData: Partial<ServerConfig> = {
        ...serverForm.value,
        insecure: !!serverForm.value.insecure,
      }
      await serversStore.addServer(createData)
    }

    cancelEdit()
  } finally {
    loading.value = false
  }
}

// 从剪贴板导入
const importFromClipboard = async () => {
  try {
    const text = await navigator.clipboard.readText()
    if (!text) { toast({ title: '提示', description: '剪贴板为空' }); return }
    const lines = text.split(/\s+/).filter(Boolean)
    let imported = 0, failed = 0
    for (const line of lines) {
      const s = parseLink(line)
      if (!s) { failed++; continue }
      try {
        await serversStore.addServer(s as any)
        imported++
      } catch { failed++ }
    }
    if (imported === 0 && failed === 0) {
      toast({ title: '提示', description: '未发现可识别的链接' })
    } else {
      toast({ title: '导入完成', description: `成功 ${imported}，失败 ${failed}` })
      serversStore.fetchServers()
    }
  } catch (e) {
    toast({ title: '读取剪贴板失败', description: (e as Error).message, variant: 'destructive' })
  }
}

function parseLink(raw: string): Partial<ServerConfig> | null {
  try {
    if (raw.startsWith('vmess://')) return parseVmess(raw)
    if (raw.startsWith('vless://')) return parseVlessTrojan(raw, 'vless')
    if (raw.startsWith('trojan://')) return parseVlessTrojan(raw, 'trojan')
    if (raw.startsWith('ss://')) return parseShadowsocks(raw)
  } catch {}
  return null
}

function mapNetwork(n?: string): NetworkKind | undefined {
  if (!n) return undefined
  if (n === 'http') return 'xhttp'
  return (n === 'tcp' || n === 'ws' || n === 'grpc' || n === 'quic' || n === 'xhttp') ? n : undefined
}

function parseVmess(link: string): Partial<ServerConfig> | null {
  try {
    const b64 = link.replace('vmess://', '').trim()
    const jsonStr = decodeB64(b64)
    const v = JSON.parse(jsonStr)
    const name = v.ps || 'vmess'
    return {
      name,
      type: 'vmess',
      address: v.add,
      port: Number(v.port),
      uuid: v.id,
      encryption: v.scy || 'auto',
      network: mapNetwork(v.net),
      path: v.path || v['grpc-service-name'] || '',
      host: v.host || v.sni || '',
      tls: (v.tls || '').toLowerCase() === 'tls',
      sni: v.sni || ''
    }
  } catch {
    return null
  }
}

function parseVlessTrojan(link: string, kind: 'vless'|'trojan'): Partial<ServerConfig> | null {
  try {
    const u = new URL(link)
    const name = decodeURIComponent(u.hash.replace('#','')) || kind
    const [host, portStr] = (u.host || '').split(':')
    const port = Number(portStr || u.port || '443')
    const q = u.searchParams
    const type = q.get('type') || q.get('transport') || ''
    const path = q.get('path') || q.get('serviceName') || ''
    const hostHeader = q.get('host') || ''
    const security = (q.get('security') || '').toLowerCase()
    const sni = q.get('sni') || ''
    if (kind === 'vless') {
      const uuid = u.username
      const pbk = q.get('pbk') || q.get('publicKey') || ''
      const sid = q.get('sid') || ''
      const spx = q.get('spx') || q.get('serverName') || ''
      const fp = q.get('fp') || ''
      const flow = q.get('flow') || ''
      const reality = security === 'reality'
      return { name, type: 'vless', address: host, port, uuid, network: mapNetwork(type), path: path || undefined, host: hostHeader || undefined, tls: security==='tls', sni: sni || undefined, reality, realityPbk: pbk || undefined, realitySid: sid || undefined, realitySpx: spx || undefined, realityFp: fp || undefined, flow: flow || undefined }
    } else {
      const password = decodeURIComponent(u.username || u.password || '')
      return { name, type: 'trojan', address: host, port, password, network: mapNetwork(type), path: path || undefined, host: hostHeader || undefined, tls: security==='tls', sni: sni || undefined }
    }
  } catch {
    return null
  }
}

function parseShadowsocks(link: string): Partial<ServerConfig> | null {
  try {
    // ss://base64(method:password@host:port)#name 或 ss://method:password@host:port#name
    let rest = link.replace('ss://','')
    let name = ''
    const hashIdx = rest.indexOf('#')
    if (hashIdx >= 0) { name = decodeURIComponent(rest.slice(hashIdx+1)); rest = rest.slice(0, hashIdx) }
    let credsHost = rest
    if (!rest.includes('@')) {
      credsHost = decodeB64(rest)
    }
    const [methodPass, hostPort] = credsHost.split('@')
    const [method, password] = methodPass.split(':')
    const [host, portStr] = hostPort.split(':')
    const port = Number(portStr)
    return { name: name || 'shadowsocks', type: 'shadowsocks', address: host, port, password, encryption: method }
  } catch {
    return null
  }
}

function decodeB64(b64: string): string {
  // add padding
  const pad = b64.length % 4
  if (pad) b64 = b64 + '='.repeat(4 - pad)
  try { return atob(b64) } catch { return Buffer.from(b64, 'base64').toString('utf-8') }
}

const cancelEdit = () => {
  showAddDialog.value = false
  editingServer.value = null
  serverForm.value = {
    name: '',
    type: 'vmess',
    address: '',
    port: 443,
    uuid: '',
    password: '',
    encryption: 'auto',
    network: 'tcp',
    path: '',
    host: '',
    tls: false,
    insecure: false,
    sni: ''
  }
}

function onAddClick() {
  editingServer.value = null
  serverForm.value = {
    name: '',
    type: 'vmess',
    address: '',
    port: 443,
    uuid: '',
    password: '',
    encryption: 'auto',
    network: 'tcp',
    path: '',
    host: '',
    tls: false,
    insecure: false,
    sni: ''
  }
  showAddDialog.value = true
}

onMounted(async () => {
  await Promise.all([
    serversStore.fetchServers(),
    serversStore.fetchSelected(),
  ])
})
</script>
