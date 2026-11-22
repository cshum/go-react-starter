const BASE_URL = import.meta.env.VITE_API_URL ?? '/api'

export type Asset = {
  id: string
  filename: string
  sha256: string
  size: number
  createdAt: string
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = init.method ?? 'GET'
  const res = await fetch(`${BASE_URL}${path}`, init)
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null
    const detail = body?.error ?? res.statusText
    throw new Error(`${method} ${path} failed: ${res.status} ${detail}`)
  }
  return (await res.json()) as T
}

export function listAssets(): Promise<Asset[]> {
  return request<{ assets: Asset[] }>('/assets').then((r) => r.assets)
}

export function getAsset(id: string): Promise<Asset> {
  return request<Asset>(`/assets/${encodeURIComponent(id)}`)
}
