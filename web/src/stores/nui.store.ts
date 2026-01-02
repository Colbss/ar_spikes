import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useNuiEvent } from '../composables/useNuiEvent'

export const useNUI = defineStore('nui', () => {
    const spikeDeployVisible = ref<boolean>(false)
    const spikeLength = ref<number>(1)

    const locales = ref<Record<string, string>>({})
    const getLocale = (key: string): string => {
        return locales.value[key] || 'UNDEFINED'
    }
    
    useNuiEvent<{ locales: Record<string, string>; initialLength: number }>('showUI', (payload) => {
        spikeDeployVisible.value = true
        locales.value = payload.locales || {}
        spikeLength.value = payload.initialLength || 1
    })

    useNuiEvent<{ length: number }>('setLength', (payload) => {
        spikeLength.value = payload.length
    })

    useNuiEvent('hideUI', () => {
        spikeDeployVisible.value = false
    })

    return {
        spikeDeployVisible,
        locales,
        spikeLength,
        getLocale,
    }
})