<template>
  <div class="p-4 space-y-3">
    <Card class="aurora hover:shadow-lg transition-all">
      <CardContent class="p-4 space-y-3">
        <div>
          <Label>路由模式</Label>
          <Select v-model="settings.routingMode" @update:model-value="(v:any)=>updateRoutingMode(String(v))">
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="global">全局代理</SelectItem>
              <SelectItem value="bypass">绕过大陆</SelectItem>
              <SelectItem value="direct">直连</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div>
          <Label>域名策略</Label>
          <Select v-model="(settings as any).domainStrategy" @update:model-value="(v:any)=>updateDomainStrategy(String(v))">
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="AsIs">AsIs</SelectItem>
              <SelectItem value="IPIfNonMatch">IPIfNonMatch</SelectItem>
              <SelectItem value="IPOnDemand">IPOnDemand</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div>
            <Label for="proxy-rules">代理（域名/IP/CIDR，每行一条）</Label>
            <textarea id="proxy-rules" v-model="proxyRulesText" @blur="saveRules" class="w-full h-40 px-3 py-2 text-sm border border-input rounded-md bg-background" placeholder="example.com\n1.2.3.0/24" />
          </div>
          <div>
            <Label for="direct-rules">直连（域名/IP/CIDR，每行一条）</Label>
            <textarea id="direct-rules" v-model="directRulesText" @blur="saveRules" class="w-full h-40 px-3 py-2 text-sm border border-input rounded-md bg-background" placeholder="internal.example\n192.168.0.0/16" />
          </div>
          <div>
            <Label for="block-rules">阻止（域名/IP/CIDR，每行一条）</Label>
            <textarea id="block-rules" v-model="blockRulesText" @blur="saveRules" class="w-full h-40 px-3 py-2 text-sm border border-input rounded-md bg-background" placeholder="ads.example\n8.8.8.8" />
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useSettingsStore } from '@/stores/settings'

const settingsStore = useSettingsStore()
const settings = computed(() => settingsStore.settings)

const updateRoutingMode = (value: string | null) => {
  if (value) settingsStore.updateRoutingMode(value as any)
}
const updateDomainStrategy = (value: string | null) => {
  if (value) settingsStore.updateSettings({ domainStrategy: value as any })
}

const proxyRulesText = ref('')
const directRulesText = ref('')
const blockRulesText = ref('')

const saveRules = () => {
  settingsStore.updateSettings({
    proxyRules: proxyRulesText.value.split('\n').map(s => s.trim()).filter(Boolean),
    directRules: directRulesText.value.split('\n').map(s => s.trim()).filter(Boolean),
    blockRules: blockRulesText.value.split('\n').map(s => s.trim()).filter(Boolean),
  })
}

onMounted(() => {
  settingsStore.fetchSettings()
  proxyRulesText.value = (settings.value as any).proxyRules?.join('\n') || ''
  directRulesText.value = (settings.value as any).directRules?.join('\n') || ''
  blockRulesText.value = (settings.value as any).blockRules?.join('\n') || ''
})
</script>
