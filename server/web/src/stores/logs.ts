import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api } from '@/lib/api'

export interface LogEntry {
  time: string
  level: string
  source: string
  message: string
}

export const useLogsStore = defineStore('logs', () => {
  const logs = ref<LogEntry[]>([])
  const loading = ref(false)
  let timer: number | null = null
  const filters = ref({
    level: '',
    source: '',
    search: ''
  })

  const fetchLogs = async (opts?: { silent?: boolean }) => {
    const silent = Boolean(opts?.silent)
    if (!silent) loading.value = true
    try {
      const params = new URLSearchParams()
      if (filters.value.level) params.append('level', filters.value.level)
      if (filters.value.source) params.append('source', filters.value.source)
      if (filters.value.search) params.append('search', filters.value.search)
      params.append('limit', '50')

      const response = await api.get(`/logs?${params.toString()}`)
      logs.value = response.data
    } catch (error) {
      console.error('Failed to fetch logs:', error)
    } finally {
      if (!silent) loading.value = false
    }
  }

  const startPolling = () => {
    stopPolling()
    timer = window.setInterval(() => {
      fetchLogs({ silent: true })
    }, 1500)
  }

  const stopPolling = () => {
    if (timer) {
      window.clearInterval(timer)
      timer = null
    }
  }

  const clearLogs = async () => {
    try {
      await api.delete('/logs')
      logs.value = []
    } catch (error) {
      console.error('Failed to clear logs:', error)
      throw error
    }
  }

  const exportLogs = async (filePath?: string) => {
    try {
      const params = filePath ? `?file=${encodeURIComponent(filePath)}` : ''
      await api.get(`/logs/export${params}`)
    } catch (error) {
      console.error('Failed to export logs:', error)
      throw error
    }
  }

  const setFilter = (key: keyof typeof filters.value, value: string) => {
    filters.value[key] = value
    fetchLogs()
  }

  const clearFilters = () => {
    filters.value = {
      level: '',
      source: '',
      search: ''
    }
    fetchLogs()
  }

  const getLogStats = () => {
    const stats: Record<string, number> = {}
    logs.value.forEach(log => {
      stats[log.level] = (stats[log.level] || 0) + 1
    })
    return stats
  }

  return {
    logs,
    loading,
    filters,
    fetchLogs,
    startPolling,
    stopPolling,
    clearLogs,
    exportLogs,
    setFilter,
    clearFilters,
    getLogStats
  }
})
