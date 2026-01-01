<script setup lang="ts">
import { defineAsyncComponent, onMounted } from 'vue'
import { useNUI } from './stores/nui.store'
import { useDevelopment } from './stores/development.store'

const DevelopmentToolbar = defineAsyncComponent(() => import('./devComponents/DevelopmentToolbar.vue'))
const SpikeDeploy = defineAsyncComponent(() => import('./components/SpikeDeploy.vue'))

const dev = useDevelopment()
const nuiStore = useNUI()

onMounted(() => {
  if (dev.isDevEnv) {
    dev.applyDevelopmentStyles()
  }
})
</script>

<template>
 <Transition name="fade">
   <SpikeDeploy v-if="nuiStore.spikeDeployVisible" />
 </Transition>
 <DevelopmentToolbar v-if="dev.isDevEnv" />
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>