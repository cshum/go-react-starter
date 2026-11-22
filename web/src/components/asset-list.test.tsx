import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  RouterProvider,
} from '@tanstack/react-router'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import type { Asset } from '@/api/client'
import { AssetList } from '@/components/asset-list'

const assets: Asset[] = [
  {
    id: 'asset-1',
    filename: 'tax-return-2025.pdf',
    sha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
    size: 1536,
    createdAt: '2026-01-02T10:00:00Z',
  },
  {
    id: 'asset-2',
    filename: 'payslip.pdf',
    sha256: 'abc123',
    size: 900,
    createdAt: '2026-01-03T10:00:00Z',
  },
]

function renderInRouter(rows: Asset[]) {
  const rootRoute = createRootRoute()
  const indexRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: '/',
    component: () => <AssetList assets={rows} />,
  })
  const detailRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: '/assets/$assetId',
    component: () => null,
  })
  const router = createRouter({
    routeTree: rootRoute.addChildren([indexRoute, detailRoute]),
    history: createMemoryHistory({ initialEntries: ['/'] }),
  })
  return render(<RouterProvider router={router} />)
}

describe('AssetList', () => {
  it('renders one row per asset with size and hash', async () => {
    renderInRouter(assets)

    const first = await screen.findByRole('link', { name: 'tax-return-2025.pdf' })
    expect(first).toHaveAttribute('href', '/assets/asset-1')
    expect(screen.getByText(/1.5 KB · 9f86d081…/)).toBeInTheDocument()
    expect(await screen.findByRole('link', { name: 'payslip.pdf' })).toHaveAttribute(
      'href',
      '/assets/asset-2',
    )
    expect(screen.getAllByRole('listitem')).toHaveLength(2)
  })

  it('renders an empty state', async () => {
    renderInRouter([])
    expect(await screen.findByText('No assets yet.')).toBeInTheDocument()
  })
})
