import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import App from './App.vue'
import './style.css'

// 导入组件
import Home from './views/Home.vue'
import Servers from './views/Servers.vue'
import Settings from './views/Settings.vue'
import Logs from './views/Logs.vue'
import RoutingSettings from './views/RoutingSettings.vue'

// 路由配置
const routes = [
  { path: '/', component: Home },
  { path: '/servers', component: Servers },
  { path: '/settings', component: Settings },
  { path: '/logs', component: Logs },
  { path: '/routing', component: RoutingSettings }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 添加路由错误处理
router.onError((error) => {
  console.error('Router error:', error)
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
