import { afterEach, describe, expect, it, vi } from 'vitest'

import fixture from '../../../testdata/asset.json'
import { listAssets } from './client'

const ok = (body: unknown) =>
  vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => body })

const fail = (status: number, statusText: string, body: unknown) =>
  vi.fn().mockResolvedValue({ ok: false, status, statusText, json: async () => body })

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('listAssets', () => {
  // The bug this catches: the handler returns {"assets": …} and the client reads another key, so
  // the list renders empty while every component test still passes on props.
  it('unwraps the envelope the server actually sends', async () => {
    vi.stubGlobal('fetch', ok({ assets: [fixture] }))

    const assets = await listAssets()

    expect(assets).toHaveLength(1)
    expect(assets[0].id).toBe(fixture.id)
    expect(assets[0].createdAt).toBe(fixture.createdAt)
  })

  it('surfaces the message the server sent, not just the status', async () => {
    vi.stubGlobal('fetch', fail(500, 'Internal Server Error', { error: 'list failed' }))

    await expect(listAssets()).rejects.toThrow('GET /assets failed: 500 list failed')
  })
})