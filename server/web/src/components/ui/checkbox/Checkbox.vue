<script setup lang="ts">
import type { CheckboxRootEmits, CheckboxRootProps } from "reka-ui"
import type { HTMLAttributes } from "vue"
import { reactiveOmit } from "@vueuse/core"
import { Check } from "lucide-vue-next"
import { CheckboxIndicator, CheckboxRoot, useForwardPropsEmits } from "reka-ui"
import { cn } from "@/lib/utils"

type WrapperEmits = CheckboxRootEmits & {
  'update:checked': [value: boolean | 'indeterminate']
}

type WrapperProps = CheckboxRootProps & {
  /** 兼容 v-model:checked 用法 */
  checked?: boolean | 'indeterminate'
  class?: HTMLAttributes['class']
}

const props = defineProps<WrapperProps>()
const emits = defineEmits<WrapperEmits>()

// 不直接把 checked/modelValue 透传，改为手动映射
const delegatedProps = reactiveOmit(props, "class", "checked", "modelValue")

const forwarded = useForwardPropsEmits(delegatedProps as CheckboxRootProps, emits)

function onUpdateModelValue(v: boolean | 'indeterminate') {
  emits('update:modelValue', v)
  emits('update:checked', v)
}
</script>

<template>
  <CheckboxRoot
    v-bind="forwarded"
    :model-value="props.checked ?? (props as any).modelValue"
    @update:modelValue="onUpdateModelValue"
    :class="
      cn('peer h-4 w-4 shrink-0 rounded-sm border border-primary shadow focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground',
         props.class)"
  >
    <CheckboxIndicator class="flex h-full w-full items-center justify-center text-current">
      <slot>
        <Check class="h-4 w-4" />
      </slot>
    </CheckboxIndicator>
  </CheckboxRoot>
</template>
