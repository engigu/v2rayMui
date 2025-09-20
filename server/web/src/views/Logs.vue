<template>
  <div class="p-4 h-full flex flex-col">
    <div class="mb-3 flex justify-between items-center">
      <div>
        <h2 class="text-xl font-bold text-foreground">日志</h2>
        <p class="text-sm text-muted-foreground">显示最近 50 条，自动滚动到底部</p>
      </div>
      <div class="flex space-x-2">
        <Button @click="refreshLogs" :disabled="loading">
          <RefreshCw class="w-4 h-4 mr-2" :class="{ 'animate-spin': loading }" />
          刷新
        </Button>
        <Button @click="clearLogs" variant="outline">
          <Trash2 class="w-4 h-4 mr-2" />
          清空
        </Button>
        <Button @click="exportLogs" variant="outline">
          <Download class="w-4 h-4 mr-2" />
          导出
        </Button>
      </div>
    </div>
    <!-- 日志列表（单块区域，近 50 条，自动滚动到底部） -->
    <Card class="flex-1 flex min-h-0 aurora hover:shadow-lg transition-all">
      <CardContent class="p-0 flex-1 min-h-0">
        <div class="h-full overflow-auto font-mono text-xs leading-4 whitespace-pre-wrap" ref="containerRef">
          <div v-if="displayLogs.length === 0" class="p-6 text-center text-muted-foreground text-sm">
            暂无日志
          </div>
          <template v-else>
            <div v-for="(log, index) in displayLogs" :key="index" class="px-2 py-0.5">
              {{ lineText(log) }}
            </div>
          </template>
        </div>
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { RefreshCw, Trash2, Download } from 'lucide-vue-next'
import { useLogsStore } from '@/stores/logs'
import type { LogEntry } from '@/stores/logs'

const logsStore = useLogsStore()

const logs = computed(() => logsStore.logs)
const loading = computed(() => logsStore.loading)
const displayLogs = computed(() => logs.value.slice(-50))
const containerRef = ref<HTMLElement | null>(null)

const formatTime = (time: string) => new Date(time).toLocaleString()
const lineText = (log: LogEntry) => `[${formatTime(log.time)}] ${log.level.toUpperCase()} ${log.source}: ${log.message}`

const refreshLogs = () => {
  logsStore.fetchLogs()
}

const clearLogs = async () => {
  if (confirm('确定要清空所有日志吗？')) {
    await logsStore.clearLogs()
  }
}

const exportLogs = async () => {
  const fileName = `logs_${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`
  await logsStore.exportLogs(fileName)
}

watch(logs, async () => {
  await nextTick()
  const el = containerRef.value
  if (el) el.scrollTop = el.scrollHeight
})

onMounted(() => {
  logsStore.fetchLogs()
  logsStore.startPolling()
})

onUnmounted(() => {
  logsStore.stopPolling()
})
</script>
