import { defineStore } from 'pinia'
import { ref } from 'vue'
import { api } from '@/lib/api'
import type { AppSettings } from '@/types'

export const useSettingsStore = defineStore('settings', () => {
  const settings = ref<AppSettings>({
    autoConnect: false,
    showInDock: true,
    startAtLogin: false,
    logLevel: 'info',
    httpPort: 1087,
    socksPort: 1088,
    httpHost: '127.0.0.1',
    socksHost: '127.0.0.1',
    routingMode: 'bypass',
    customRules: [],
    udpEnabled: true,
    muxEnabled: false,
    muxConcurrency: 8,
    logMaxMB: 6,
    domainStrategy: 'AsIs',
    proxyRules: [],
    directRules: [],
    blockRules: []
  })
  const loading = ref(false)

  const fetchSettings = async () => {
    try {
      const response = await api.get('/settings')
      settings.value = response.data
    } catch (error) {
      console.error('Failed to fetch settings:', error)
    }
  }

  const updateSettings = async (newSettings: Partial<AppSettings>) => {
    loading.value = true
    try {
      const response = await api.post('/settings', { ...settings.value, ...newSettings })
      settings.value = response.data
    } catch (error) {
      console.error('Failed to update settings:', error)
      throw error
    } finally {
      loading.value = false
    }
  }
  const updateLogMaxMB = async (logMaxMB: number) => {
    await updateSettings({ logMaxMB })
  }

  const updateAutoConnect = async (autoConnect: boolean) => {
    await updateSettings({ autoConnect })
  }

  const updateShowInDock = async (showInDock: boolean) => {
    await updateSettings({ showInDock })
  }

  const updateStartAtLogin = async (startAtLogin: boolean) => {
    await updateSettings({ startAtLogin })
  }

  const updateLogLevel = async (logLevel: string) => {
    await updateSettings({ logLevel })
  }

  const updateProxyPorts = async (httpPort: number, socksPort: number) => {
    await updateSettings({ httpPort, socksPort })
  }

  const updateRoutingMode = async (routingMode: AppSettings['routingMode']) => {
    await updateSettings({ routingMode })
  }

  const updateCustomRules = async (customRules: string[]) => {
    await updateSettings({ customRules })
  }

  const updateUDPEnabled = async (udpEnabled: boolean) => {
    await updateSettings({ udpEnabled })
  }

  const updateMuxEnabled = async (muxEnabled: boolean) => {
    await updateSettings({ muxEnabled })
  }

  const updateMuxConcurrency = async (muxConcurrency: number) => {
    await updateSettings({ muxConcurrency })
  }

  return {
    settings,
    loading,
    fetchSettings,
    updateSettings,
    updateAutoConnect,
    updateShowInDock,
    updateStartAtLogin,
    updateLogLevel,
    updateProxyPorts,
    updateRoutingMode,
    updateCustomRules,
    updateUDPEnabled,
    updateMuxEnabled,
    updateMuxConcurrency,
    updateLogMaxMB
  }
})
