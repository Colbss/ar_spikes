<script setup lang="ts">
import { useNUI } from '../stores/nui.store';

const nuiStore = useNUI();
</script>

<template>
  <div v-if="nuiStore.spikeDeployVisible" class="spike-deploy-container">
    <div class="spike-deploy-content">
      <div class="spike-deploy-length">
        <span class="length-label">Spike Length - {{ nuiStore.spikeLength }}</span>
      </div>
      <div class="spike-deploy-controls">
        <div class="control-item">
          <span class="control-key">{{ nuiStore.spikeKeysData.increaseLabel }}</span>
          <span class="control-label">Increase Length</span>
        </div>
        <div class="control-item">
          <span class="control-key">{{ nuiStore.spikeKeysData.decreaseLabel }}</span>
          <span class="control-label">Decrease Length</span>
        </div>
        <div class="control-item">
          <span class="control-key">{{ nuiStore.spikeKeysData.confirmLabel }}</span>
          <span class="control-label">Confirm</span>
        </div>
        <div class="control-item">
          <span class="control-key">{{ nuiStore.spikeKeysData.cancelLabel }}</span>
          <span class="control-label">Cancel</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.spike-deploy-container {
  position: fixed;
  bottom: 10vh;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
}

.spike-deploy-content {
  background: rgba(10, 10, 14, 0.95);
  border-radius: 0.8vh;
  padding: 1vh 2vh 2vh 2vh;
  box-shadow: 0 0.4vh 0.6vh rgba(0, 0, 0, 0.5);
}

.spike-deploy-length {
  text-align: center;
  color: rgba(255, 255, 255, 0.8);
  font-size: 1.2vh;
  margin-bottom: 1vh;
  font-weight: 500;
}

.length-label {
  color: #ffffff;
  font-size: 1.2vh;
  font-weight: bold;
}

.spike-deploy-controls {
  display: flex;
  gap: 1.6vh;
}

.control-item {
  display: flex;
  align-items: center;
  gap: 1.2vh;
}

.control-key {
  background: rgba(91, 140, 255, 0.2);
  border: 0.1vh solid #5b8cff;
  border-radius: 0.4vh;
  padding: 0.4vh 1vh;
  color: #5b8cff;
  font-size: 0.8vh;
  font-weight: bold;
  text-align: center;
  text-transform: uppercase;
}

.control-label {
  color: rgba(255, 255, 255, 0.9);
  font-size: 1vh;
  font-weight: 500;
}
</style>
