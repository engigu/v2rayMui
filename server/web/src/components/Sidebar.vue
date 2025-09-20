<template>
  <aside class="w-64 bg-muted/30 border-r border-border flex flex-col">
    <div class="p-4 border-b border-border">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-lg font-bold text-foreground">V2Ray MUI</h1>
          <p class="text-xs text-muted-foreground mt-1">基于 Golang 和 Vue 的 V2Ray 图形客户端</p>
        </div>
        <ThemeSwitcher />
      </div>
    </div>
    <nav class="flex-1 p-3">
      <ul class="space-y-1">
        <li v-for="r in navRoutes" :key="r.path">
          <router-link
            :to="r.path"
            class="flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors hover:bg-accent hover:text-accent-foreground"
            :class="{ 'bg-accent text-accent-foreground': $route.path === r.path }"
          >
            <component :is="r.icon" class="w-4 h-4 mr-3" />
            {{ r.meta?.title }}
          </router-link>
        </li>
      </ul>
    </nav>
  </aside>
</template>

<script setup lang="ts">
import ThemeSwitcher from '@/components/ThemeSwitcher.vue'
import { routes } from '@/router'
import { Home, Server, Settings, FileText } from 'lucide-vue-next'

const iconMap: Record<string, any> = {
  '/': Home,
  '/servers': Server,
  '/settings': Settings,
  '/logs': FileText
}

const navRoutes = routes.map(r => ({ ...r, icon: iconMap[r.path as string] || Home }))
</script>
