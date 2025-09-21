<template>
  <div class="p-4">
    <div class="mb-3">
      <h2 class="text-xl font-bold text-foreground">仪表板</h2>
      <p class="text-sm text-muted-foreground">V2Ray 连接状态和快速操作</p>
    </div>

    <!-- 连接状态卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 mb-4">
      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle class="flex items-center">
            <Wifi class="w-5 h-5 mr-2" :class="status.connected ? 'text-emerald-600 animate-pulse' : 'text-red-600'" />
            连接状态
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="relative">
            <div v-if="loading" class="absolute -top-2 left-0 right-0 h-0.5 bg-accent/30">
              <div class="h-full w-1/3 bg-accent/60 animate-pulse"></div>
            </div>
          </div>
          <div class="flex items-center justify-between">
            <div>
              <div class="flex items-center">
                <span class="relative inline-flex h-8 w-8 items-center justify-center mr-2">
                  <!-- 进度环动画（连接时从空到满） -->
                  <svg viewBox="0 0 36 36" class="h-8 w-8 -rotate-90">
                    <circle cx="18" cy="18" r="15" class="text-muted stroke-current" stroke-width="3" fill="none" opacity="0.25" />
                    <circle v-if="status.connected" cx="18" cy="18" r="15" class="text-emerald-500 animate-dash" stroke-width="3" fill="none" stroke-linecap="round" :style="{ strokeDasharray: '94', strokeDashoffset: '94', willChange: 'stroke-dashoffset' }" />
                    <circle v-else cx="18" cy="18" r="15" class="text-red-500" stroke-width="3" fill="none" stroke-linecap="round" :style="{ strokeDasharray: '94', strokeDashoffset: '94' }" />
                  </svg>
                  <!-- 内部状态点：连接=绿点+脉冲，未连接=红点 -->
                  <span v-if="status.connected" class="absolute h-2 w-2 rounded-full bg-emerald-500"></span>
                  <span v-else class="absolute h-2 w-2 rounded-full bg-red-500"></span>
                  <span v-if="status.connected" class="absolute h-2 w-2 rounded-full bg-emerald-400 opacity-70 animate-ping"></span>
                </span>
                <p class="ml-2 text-2xl font-bold" :class="status.connected ? 'text-emerald-700' : 'text-red-600'">
                  <span v-if="loading" class="inline-flex items-center gap-1 text-muted-foreground text-base">
                    <RefreshCw class="w-4 h-4 animate-spin" /> 处理中...
                  </span>
                  <span v-else>
                    {{ status.connected ? '已连接' : '未连接' }}
                  </span>
                </p>
              </div>
              <!-- <p class="mt-1 text-sm text-muted-foreground">
                <span v-if="loading" class="inline-block h-3 w-28 bg-muted rounded animate-pulse"></span>
                <span v-else>{{ status.status }}</span>
              </p> -->
            </div>
            <Button
              @click="toggleConnection"
              :disabled="loading"
              :variant="status.connected ? 'destructive' : 'default'"
              class="transition-transform hover:scale-105"
            >
              <span v-if="loading" class="inline-flex items-center gap-1">
                <RefreshCw class="w-4 h-4 animate-spin" />
                处理中
              </span>
              <span v-else>
                {{ status.connected ? '断开' : '连接' }}
              </span>
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle class="flex items-center">
            <Server class="w-5 h-5 mr-2" />
            当前服务器
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div v-if="selectedServer">
            <p class="font-medium">{{ selectedServer.name }}</p>
            <p class="text-sm text-muted-foreground">{{ selectedServer.address }}:{{ selectedServer.port }}</p>
            <p class="text-sm text-muted-foreground">{{ selectedServer.type }}</p>
          </div>
          <div v-else class="text-muted-foreground">
            未选择服务器
          </div>
        </CardContent>
      </Card>

      <Card class="aurora hover:shadow-lg transition-all">
        <CardHeader>
          <CardTitle class="flex items-center">
            <Activity class="w-5 h-5 mr-2" />
            代理状态
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm">HTTP 代理</span>
              <span class="text-sm font-mono">
                <template v-if="loading">
                  <span class="inline-block h-3 w-32 bg-muted rounded animate-pulse"></span>
                </template>
                <template v-else>
                  {{ settings.httpHost }}:{{ displayedHttpPort }}
                </template>
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm">SOCKS 代理</span>
              <span class="text-sm font-mono">
                <template v-if="loading">
                  <span class="inline-block h-3 w-32 bg-muted rounded animate-pulse"></span>
                </template>
                <template v-else>
                  {{ settings.socksHost }}:{{ displayedSocksPort }}
                </template>
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm">UDP</span>
              <span class="text-sm">
                <template v-if="loading">
                  <span class="inline-block h-3 w-16 bg-muted rounded animate-pulse"></span>
                </template>
                <template v-else>
                  {{ settings.udpEnabled ? '已启用' : '未启用' }}
                </template>
              </span>
            </div>
            <div class="pt-2 flex gap-2">
              <Button size="sm" variant="outline" @click="copyEnableProxy" :disabled="loading">
                复制启用命令
              </Button>
              <Button size="sm" variant="outline" @click="copyDisableProxy" :disabled="loading">
                复制关闭命令
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- 快速操作 -->
    <Card class="aurora hover:shadow-lg transition-all">
      <CardHeader>
        <CardTitle>快速操作</CardTitle>
      </CardHeader>
      <CardContent>
        <div class="grid grid-cols-5 gap-2">
          <Button @click="$router.push('/servers')" variant="outline" class="h-20 w-full flex flex-col transition-transform hover:scale-[1.02] hover:shadow-sm">
            <Server class="w-6 h-6 mb-2" />
            管理服务器
          </Button>
          <Button @click="$router.push('/settings')" variant="outline" class="h-20 w-full flex flex-col transition-transform hover:scale-[1.02] hover:shadow-sm">
            <Settings class="w-6 h-6 mb-2" />
            应用设置
          </Button>
          <Button @click="$router.push('/logs')" variant="outline" class="h-20 w-full flex flex-col transition-transform hover:scale-[1.02] hover:shadow-sm">
            <ScrollText class="w-6 h-6 mb-2" />
            查看日志
          </Button>
          <Button @click="openCoreConfig" variant="outline" class="h-20 w-full flex flex-col transition-transform hover:scale-[1.02] hover:shadow-sm">
            <FileText class="w-6 h-6 mb-2" />
            Xray配置
          </Button>
          <Button @click="refreshStatus" variant="outline" class="h-20 w-full flex flex-col transition-transform hover:scale-[1.02] hover:shadow-sm" :disabled="loading">
            <RefreshCw class="w-6 h-6 mb-2" :class="{ 'animate-spin': loading }" />
            刷新状态
          </Button>
        </div>
      </CardContent>
    </Card>

    <!-- 最近事件 -->
    <Card class="mt-4 aurora hover:shadow-lg transition-all">
      <CardHeader>
        <CardTitle>最近事件</CardTitle>
      </CardHeader>
      <CardContent class="p-0">
        <transition-group
          tag="div"
          class="divide-y"
          enter-active-class="transition duration-300"
          enter-from-class="opacity-0 translate-y-1"
          enter-to-class="opacity-100 translate-y-0"
        >
          <div v-for="(log, i) in recentLogs" :key="log.time + i" class="px-3 py-2 text-xs">
            <span class="text-muted-foreground">{{ formatTime(log.time) }}</span>
            <span class="mx-2 rounded border px-1 py-0.5 align-middle">{{ log.level.toUpperCase() }}</span>
            <span class="mx-1 text-muted-foreground">{{ log.source }}</span>
            <span class="ml-2 font-mono break-words">{{ log.message }}</span>
          </div>
        </transition-group>
        <div v-if="recentLogs.length === 0" class="p-3 text-xs text-muted-foreground">暂无事件</div>
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Wifi, Server, Activity, Settings, FileText, RefreshCw, ScrollText } from 'lucide-vue-next'
import { useStatusStore } from '@/stores/status'
import { useSettingsStore } from '@/stores/settings'
import { useToast } from '@/components/ui/toast/use-toast'

const { toast } = useToast()

const statusStore = useStatusStore()
const settingsStore = useSettingsStore()

const loading = ref(false)

const status = computed(() => statusStore.status)
const selectedServer = computed(() => statusStore.selectedServer)
const settings = computed(() => settingsStore.settings)

// 最近事件（取日志 store 或者拼接简单事件）
const recentLogs = ref<Array<{time:string, level:string, source:string, message:string}>>([])

// 数字滚动动画：显示端口
const displayedHttpPort = ref(0)
const displayedSocksPort = ref(0)

function animateNumber(from: number, to: number, setter: (v:number)=>void, duration = 600) {
  const start = performance.now()
  const diff = to - from
  function step(now: number) {
    const t = Math.min(1, (now - start) / duration)
    const eased = 1 - Math.pow(1 - t, 3) // easeOutCubic
    setter(Math.round(from + diff * eased))
    if (t < 1) requestAnimationFrame(step)
  }
  requestAnimationFrame(step)
}

watch(() => settings.value.httpPort, (val, old) => {
  animateNumber(typeof old==='number'?old:0, val, v => displayedHttpPort.value = v)
}, { immediate: true })

watch(() => settings.value.socksPort, (val, old) => {
  animateNumber(typeof old==='number'?old:0, val, v => displayedSocksPort.value = v)
}, { immediate: true })

const toggleConnection = async () => {
  loading.value = true
  try {
    if (status.value.connected) {
      await statusStore.disconnect()
    } else {
      await statusStore.connect()
    }
  } finally {
    loading.value = false
  }
}

const refreshStatus = async (silent = false) => {
  if (!silent) loading.value = true
  try {
    await statusStore.fetchStatus()
    await settingsStore.fetchSettings()
  } finally {
    if (!silent) loading.value = false
  }
}

const openCoreConfig = () => {
  window.open('/api/v1/core/config', '_blank')
}

function formatTime(iso: string) {
  try { return new Date(iso).toLocaleString() } catch { return iso }
}

const copyText = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text)
    toast({ title: '已复制', description: '已复制到剪贴板' })
  } catch (e) {
    console.error('复制失败', e)
  }
}

const copyEnableProxy = () => {
  const http = `${settings.value.httpHost}:${settings.value.httpPort}`
  const socks = `${settings.value.socksHost}:${settings.value.socksPort}`
  const cmd = `export http_proxy=http://${http}; export https_proxy=http://${http}; export all_proxy=socks5://${socks}`
  copyText(cmd)
}

const copyDisableProxy = () => {
  const cmd = 'unset http_proxy https_proxy all_proxy'
  copyText(cmd)
}

onMounted(() => {
  refreshStatus()
  // demo: 将状态变化推入最近事件（实际可接入日志 store 或 WebSocket）
  recentLogs.value.unshift({ time: new Date().toISOString(), level: 'info', source: 'system', message: '应用已加载' })
  // 3s 轮询状态
  timer = window.setInterval(() => {
    refreshStatus(true)
  }, 3000)
})

let timer: number | null = null
onUnmounted(() => {
  if (timer) {
    window.clearInterval(timer)
    timer = null
  }
})
</script>
