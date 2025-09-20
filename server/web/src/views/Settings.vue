<template>
  <div class="p-4">
    <div class="mb-3">
      <h2 class="text-xl font-bold text-foreground">设置</h2>
      <p class="text-sm text-muted-foreground">配置应用程序设置</p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3">
      <!-- 基本设置 -->
      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle>基本设置</CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="flex items-center justify-between">
            <div>
              <Label for="auto-connect">自动连接</Label>
              <p class="text-sm text-muted-foreground">启动时自动连接到选中的服务器</p>
            </div>
            <Checkbox
              id="auto-connect"
              :checked="settings.autoConnect"
              @update:checked="updateAutoConnect"
            />
          </div>

          <!-- <div class="flex items-center justify-between">
            <div>
              <Label for="show-in-dock">显示在 Dock</Label>
              <p class="text-sm text-muted-foreground">在 Dock 中显示应用程序图标</p>
            </div>
            <Checkbox
              id="show-in-dock"
              :checked="settings.showInDock"
              @update:checked="updateShowInDock"
            />
          </div> -->

          <div class="flex items-center justify-between">
            <div>
              <Label for="start-at-login">开机自启</Label>
              <p class="text-sm text-muted-foreground">系统启动时自动启动应用程序</p>
            </div>
            <Checkbox
              id="start-at-login"
              :checked="settings.startAtLogin"
              @update:checked="updateStartAtLogin"
            />
          </div>
        </CardContent>
      </Card>

      <!-- 代理设置 -->
      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle>代理设置</CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <Label for="http-host">HTTP 代理地址</Label>
              <Input
                id="http-host"
                v-model="settings.httpHost"
                @blur="updateSettings"
              />
            </div>
            <div>
              <Label for="http-port">HTTP 代理端口</Label>
              <Input
                id="http-port"
                v-model.number="settings.httpPort"
                type="number"
                @blur="updateSettings"
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <Label for="socks-host">SOCKS 代理地址</Label>
              <Input
                id="socks-host"
                v-model="settings.socksHost"
                @blur="updateSettings"
              />
            </div>
            <div>
              <Label for="socks-port">SOCKS 代理端口</Label>
              <Input
                id="socks-port"
                v-model.number="settings.socksPort"
                type="number"
                @blur="updateSettings"
              />
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- 路由设置已拆分至“路由”页面 -->

      <!-- 高级设置 -->
      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle>高级设置</CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-end">
            <div>
              <Label for="log-level">日志级别</Label>
              <Select v-model="settings.logLevel" @update:model-value="updateLogLevel">
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="debug">Debug</SelectItem>
                  <SelectItem value="info">Info</SelectItem>
                  <SelectItem value="warn">Warn</SelectItem>
                  <SelectItem value="error">Error</SelectItem>
                </SelectContent>
              </Select>
            </div>
            
            <div>
              <Label for="log-max-mb">日志最大大小（MB）</Label>
              <Input
                id="log-max-mb"
                v-model.number="settings.logMaxMB"
                type="number"
                min="1"
                max="1024"
                @blur="updateLogMaxMB(settings.logMaxMB)"
              />
              <!-- <p class="text-xs text-muted-foreground mt-1">达到上限时可用于触发轮转（由后端实现）。</p> -->
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <Label for="udp-enabled">启用 UDP</Label>
              <p class="text-sm text-muted-foreground">启用 UDP 转发</p>
            </div>
            <Checkbox
              id="udp-enabled"
              :checked="settings.udpEnabled"
              @update:checked="updateUDPEnabled"
            />
          </div>

          <div class="flex items-center justify-between">
            <div>
              <Label for="mux-enabled">启用 Mux</Label>
              <p class="text-sm text-muted-foreground">启用多路复用</p>
            </div>
            <Checkbox
              id="mux-enabled"
              :checked="settings.muxEnabled"
              @update:checked="updateMuxEnabled"
            />
          </div>

          <div v-if="settings.muxEnabled">
            <Label for="mux-concurrency">Mux 并发数</Label>
            <Input
              id="mux-concurrency"
              v-model.number="settings.muxConcurrency"
              type="number"
              min="1"
              max="32"
              @blur="updateSettings"
            />
          </div>

         
        </CardContent>
      </Card>

      <!-- 核心信息 -->
      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle>Xray 核心信息</CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-2 text-sm">
            <div class="flex items-center gap-2">
              <span class="relative inline-flex h-3 w-3">
                <span
                  class="absolute inline-flex h-full w-full rounded-full opacity-60"
                  :class="core.running ? 'animate-ping bg-emerald-400' : 'animate-pulse bg-red-400'"
                ></span>
                <span
                  class="relative inline-flex rounded-full h-3 w-3"
                  :class="core.running ? 'bg-emerald-600' : 'bg-red-600'"
                ></span>
              </span>
              <span class="font-medium" :class="core.running ? 'text-emerald-600' : 'text-red-600'">
                {{ core.running ? '运行中' : '未运行' }}
              </span>
            </div>
            <div>
              <div class="text-muted-foreground mb-1">版本</div>
              <div v-if="coreLoading" class="h-4 w-48 bg-muted rounded animate-pulse"></div>
              <pre v-else class="p-2 rounded bg-muted/40 text-xs whitespace-pre-wrap break-words transition-opacity duration-300">{{ core.version || '未知' }}</pre>
            </div>
            <div class="pt-1 flex justify-end">
              <Button
                size="icon"
                variant="ghost"
                class="rounded-full hover:bg-accent/60"
                @click="refreshCoreInfo"
                :disabled="coreLoading"
                title="刷新"
                aria-label="刷新"
              >
                <RefreshCw class="w-4 h-4" :class="{ 'animate-spin': coreLoading }"/>
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  </div>
  <div class="p-4 pt-0">
    <div class="mt-4 text-xs text-muted-foreground flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
      <div>
        <span class="mr-2">版本</span>
        <span class="font-mono">v1.0.0</span>
      </div>
      <div class="flex items-center gap-4">
        <a href="https://github.com/engigu/v2rayMui" target="_blank" class="inline-flex items-center gap-1 underline underline-offset-4 hover:text-foreground">
          <Github class="w-4 h-4" />
          GitHub
        </a>
        <span>本工具仅用于技术研究与学习，使用风险自负。</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Checkbox } from '@/components/ui/checkbox'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Button } from '@/components/ui/button'
import { RefreshCw, Github } from 'lucide-vue-next'
import { useSettingsStore } from '@/stores/settings'
import { storeToRefs } from 'pinia'
import { api } from '@/lib/api'

const settingsStore = useSettingsStore()
const { settings } = storeToRefs(settingsStore)

// (removed unused customRulesText)

const updateSettings = () => {
  settingsStore.updateSettings(settings.value)
}

const updateAutoConnect = (value: boolean) => {
  settingsStore.updateAutoConnect(value)
}

// (removed unused updateShowInDock)

const updateStartAtLogin = (value: boolean) => {
  settingsStore.updateStartAtLogin(value)
}

const updateLogLevel = (value: any) => {
  settingsStore.updateLogLevel(String(value ?? settings.value.logLevel))
}

// (removed unused updateRoutingMode)

// (removed unused updateCustomRules)

const updateUDPEnabled = (value: boolean) => {
  settingsStore.updateUDPEnabled(value)
}

const updateMuxEnabled = (value: boolean) => {
  settingsStore.updateMuxEnabled(value)
}

const updateLogMaxMB = (value: number) => {
  settingsStore.updateLogMaxMB(value)
}

onMounted(() => {
  settingsStore.fetchSettings()
})

// 核心信息
const core = ref<{version:string, running:boolean, config:any}>({ version: '', running: false, config: null })
const coreLoading = ref(false)
const refreshCoreInfo = async () => {
  coreLoading.value = true
  try {
    const res = await api.get('/core/info')
    core.value = res.data
  } finally {
    coreLoading.value = false
  }
}
// (removed unused prettyConfig)
onMounted(() => {
  refreshCoreInfo()
})
</script>
