<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button size="icon" variant="ghost" class="rounded-full" :title="label">
        <component :is="icon" class="w-4 h-4" />
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-36">
      <DropdownMenuItem @click="change('light')">
        亮色
      </DropdownMenuItem>
      <DropdownMenuItem @click="change('dark')">
        暗色
      </DropdownMenuItem>
      <DropdownMenuItem @click="change('system')">
        跟随系统
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from '@/components/ui/dropdown-menu'
import { Sun, Moon, Monitor } from 'lucide-vue-next'
import { getInitialTheme, setTheme, type ThemeMode } from '@/lib/theme'

const mode = ref<ThemeMode>('system')

onMounted(() => {
  mode.value = getInitialTheme()
})

function change(m: ThemeMode) {
  mode.value = m
  setTheme(m)
}

const icon = computed(() => mode.value === 'dark' ? Moon : (mode.value === 'light' ? Sun : Monitor))
const label = computed(() => mode.value === 'dark' ? '暗色主题' : (mode.value === 'light' ? '亮色主题' : '跟随系统'))
</script>


