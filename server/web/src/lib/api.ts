import axios from 'axios'
import { toast } from '@/components/ui/toast'

const api = axios.create({
  baseURL: '/api/v1',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response
  },
  (error) => {
    console.error('API Error:', error)
    const status = error?.response?.status
    const message = error?.response?.data?.error || error?.message || '请求失败'

    // 全局错误提示
    toast({
      title: `操作出错${status ? ` (${status})` : ''}`,
      description: message,
      variant: 'destructive'
    })
    return Promise.reject(error)
  }
)

export { api }
