<template>
  <div class="min-h-screen bg-background flex items-center justify-center p-6 smooth-in">
    <!-- 主应用卡片 -->
    <div class="w-full max-w-6xl h-[650px] glass frame-glow rounded-xl shadow-lg overflow-hidden flex">
      <!-- 侧边栏 -->
      <aside class="w-64 bg-muted/30 border-r border-border flex flex-col sidebar-aurora">
        <div class="p-4 border-b border-border">
          <div class="flex items-center justify-between">
            <div>
              <div class="flex items-center justify-between">
                <h1 class="text-lg font-bold text-foreground">V2RayMUI-GO</h1>
                <ThemeSwitcher />
              </div>
              <p class="text-[11px] text-muted-foreground mt-1">基于Golang和Vue的V2ray图形配置客户端</p>
            </div>
          </div>
        </div>
        <nav class="flex-1 p-3">
          <ul class="space-y-1">
            <li>
              <router-link
                to="/"
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
                :class="{ 'bg-accent text-accent-foreground': $route.path === '/' }"
              >
                <Home class="w-4 h-4 mr-3" />
                仪表板
              </router-link>
            </li>
            <li>
              <router-link
                to="/servers"
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
                :class="{ 'bg-accent text-accent-foreground': $route.path === '/servers' }"
              >
                <Server class="w-4 h-4 mr-3" />
                连接配置
              </router-link>
            </li>
            <li>

            <li>
              <router-link
                to="/routing"
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
                :class="{ 'bg-accent text-accent-foreground': $route.path === '/routing' }"
              >
                <Settings class="w-4 h-4 mr-3" />
                路由规则
              </router-link>
            </li>
            <li>
              <router-link
                to="/logs"
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
                :class="{ 'bg-accent text-accent-foreground': $route.path === '/logs' }"
              >
                <FileText class="w-4 h-4 mr-3" />
                运行日志
              </router-link>
            </li>
            <router-link
                to="/settings"
                class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
                :class="{ 'bg-accent text-accent-foreground': $route.path === '/settings' }"
              >
                <Settings class="w-4 h-4 mr-3" />
                设置偏好
              </router-link>
            </li>
          </ul>
        </nav>
      </aside>

      <!-- 主内容区 -->
      <main class="flex-1 flex flex-col overflow-hidden">
        <div class="flex-1 overflow-auto">
          <router-view />
        </div>
      </main>
    </div>
  </div>
  <Toaster />
</template>

<script setup lang="ts">
import { Home, Server, Settings, FileText } from 'lucide-vue-next'
import { onErrorCaptured } from 'vue'
import { Toaster } from '@/components/ui/toast'
import ThemeSwitcher from '@/components/ThemeSwitcher.vue'
 

// 捕获组件错误
onErrorCaptured((error, instance, info) => {
  console.error('Component error:', error, info)
  return false
})
</script>
