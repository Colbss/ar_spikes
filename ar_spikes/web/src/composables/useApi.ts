import { parentResourceName } from '../utils/parentResource.utils'
import { useDevelopment } from '../stores/development.store'
import {
  useFetch,
  type MaybeRefOrGetter,
  type UseFetchOptions,
  type UseFetchReturn
} from '@vueuse/core'
import { ref } from 'vue'

export interface UseApiOptions {
  mockData?: any
  resourceOverride?: string
}

export function useApi<T>(
  url: MaybeRefOrGetter<string>,
  options: RequestInit,
  useFetchOptions?: UseFetchOptions,
  apiOptions?: UseApiOptions
): UseFetchReturn<T> & PromiseLike<UseFetchReturn<T>> {
  const development = useDevelopment()
  const parentResource = apiOptions?.resourceOverride || parentResourceName
  const mockData = apiOptions?.mockData

  if (!parentResource && !mockData) {
    throw new Error('No mock data provided for development environment')
  }

  if (mockData && development.isDevEnv) {
    // @ts-ignore
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          data: ref<T>(mockData)
        })
      }, 0)
    })
  }

  if (!parentResource) {
    throw new Error('Unable to access window object or GetParentResourceName method')
  }

  const resolvedUrl = `https://${parentResource}/${url}` as string

  return useFetch(
    resolvedUrl,
    options,
    useFetchOptions || {
      afterFetch(ctx) {
        if (!ctx.data) {
          return ctx
        }

        if (ctx.data && typeof ctx.data === 'string') {
          ctx.data = JSON.parse(ctx.data)
        }

        return ctx
      }
    }
  )
}
