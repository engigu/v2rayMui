import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api } from '@/lib/api'
import { toast } from '@/components/ui/toast'
import type { ServerConfig } from '@/types'

export const useServersStore = defineStore('servers', () => {
  const servers = ref<ServerConfig[]>([])
  const selectedServerId = ref<string>('')
  const loading = ref(false)

  const fetchServers = async () => {
    try {
      const response = await api.get('/servers')
      servers.value = response.data
    } catch (error) {
      console.error('Failed to fetch servers:', error)
    }
  }

  const fetchSelected = async () => {
    try {
      const response = await api.get('/servers/selected')
      selectedServerId.value = response.data?.id || ''
    } catch (error) {
      console.error('Failed to fetch selected server:', error)
      selectedServerId.value = ''
    }
  }

  const addServer = async (serverData: Partial<ServerConfig>) => {
    loading.value = true
    try {
      const response = await api.post('/servers', serverData)
      servers.value.push(response.data)
    } catch (error) {
      console.error('Failed to add server:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  const updateServer = async (serverData: Partial<ServerConfig> & { id: string }) => {
    loading.value = true
    try {
      const response = await api.post(`/servers/${serverData.id}`, serverData)
      const index = servers.value.findIndex(s => s.id === serverData.id)
      if (index !== -1) {
        servers.value[index] = response.data
      }
      toast({ title: '正在重启 Xray', description: '应用服务器更改…' })
    } catch (error) {
      console.error('Failed to update server:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  const deleteServer = async (id: string) => {
    loading.value = true
    try {
      await api.delete(`/servers/${id}`)
      servers.value = servers.value.filter(s => s.id !== id)
      if (selectedServerId.value === id) {
        selectedServerId.value = ''
      }
    } catch (error) {
      console.error('Failed to delete server:', error)
      throw error
    } finally {
      loading.value = false
    }
  }

  const selectServer = async (id: string) => {
    try {
      await api.post(`/servers/${id}/select`)
      selectedServerId.value = id
      toast({ title: '正在重启 Xray', description: '切换服务器中…' })
    } catch (error) {
      console.error('Failed to select server:', error)
      throw error
    }
  }

  const getSelectedServer = () => {
    return servers.value.find(s => s.id === selectedServerId.value) || null
  }

  return {
    servers,
    selectedServerId,
    loading,
    fetchServers,
    fetchSelected,
    addServer,
    updateServer,
    deleteServer,
    selectServer,
    getSelectedServer
  }
})
