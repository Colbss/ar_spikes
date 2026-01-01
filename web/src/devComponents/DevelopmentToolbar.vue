<script setup lang="ts">
import { useNUI } from '../stores/nui.store'
import { useDevelopment } from '../stores/development.store'
import SplitButton from 'primevue/splitbutton'

const dev = useDevelopment()
const nuiStore = useNUI()

const debugData = (data: any) => {
  window.postMessage(data, '*')
}

const debugItems = [
  {
    label: 'Show Spike Deploy UI',
    command: () =>
      debugData({
        action: 'showUI',
        data: {
          keys: {
            increaseLabel: 'UP ARROW',
            decreaseLabel: 'DOWN ARROW',
            confirmLabel: 'ENTER',
            cancelLabel: 'ESC'
          }
        }
      })
  },
  {
    label: 'Hide Spike Deploy UI',
    command: () =>
      debugData({
        action: 'hideUI',
      })
  },
]
</script>
<template>
  <div class="fixed left-5 top-5 flex gap-5" style="z-index: var(--z-plus);">
    <SplitButton
      label="Command Mode"
      dropdownIcon="pi pi-chevron-down"
      @click.prevent="nuiStore.spikeDeployVisible = !nuiStore.spikeDeployVisible"
      :model="debugItems"
      size="small"
    />
  </div>
</template>