import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api } from '@/lib/api'
import type { ServerConfig } from '@/types'

export const useStatusStore = defineStore('status', () => {
  const status = ref({
    connected: false,
    status: 'disconnected'
  })
  const selectedServer = ref<ServerConfig | null>(null)
  const loading = ref(false)

  const fetchStatus = async () => {
    try {
      const response = await api.get('/status')
      status.value = response.data
      selectedServer.value = response.data.selected
    } catch (error) {
      console.error('Failed to fetch status:', error)
    }
  }

  const connect = async () => {
    loading.value = true
    try {
      await api.post('/connect')
      await fetchStatus()
    } catch (error) {
      console.error('Failed to connect:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  const disconnect = async () => {
    loading.value = true
    try {
      await api.post('/disconnect')
      await fetchStatus()
    } catch (error) {
      console.error('Failed to disconnect:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  return {
    status,
    selectedServer,
    loading,
    fetchStatus,
    connect,
    disconnect
  }
})
