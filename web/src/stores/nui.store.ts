import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useNuiEvent } from '../composables/useNuiEvent'

export interface SpikeKeysData {
    increaseLabel: string
    decreaseLabel: string
    confirmLabel: string
    cancelLabel: string
}

export const useNUI = defineStore('nui', () => {

    const spikeDeployVisible = ref<boolean>(false)
    const spikeKeysData = ref<SpikeKeysData>({
        increaseLabel: 'UP ARROW',
        decreaseLabel: 'DOWN ARROW',
        confirmLabel: 'ENTER',
        cancelLabel: 'ESC'
    })
    const spikeLength = ref<number>(1)

    useNuiEvent<{ keys: SpikeKeysData, initialLength: number }>('showUI', (payload) => {
        spikeDeployVisible.value = true
        if (payload.keys) {
            spikeKeysData.value = {
                increaseLabel: payload.keys.increaseLabel || 'UP ARROW',
                decreaseLabel: payload.keys.decreaseLabel || 'DOWN ARROW',
                confirmLabel: payload.keys.confirmLabel || 'ENTER',
                cancelLabel: payload.keys.cancelLabel || 'ESC'
            }
        }
        spikeLength.value = payload.initialLength || 1
    })

    useNuiEvent<{ length: number }>('setLength', (payload) => {
        spikeLength.value = payload.length
    })

    useNuiEvent<{ type: string }>('hideUI', (payload) => {
        spikeDeployVisible.value = false
    })

    return {
        spikeDeployVisible,
        spikeKeysData,
        spikeLength,
    }
})
