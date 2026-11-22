import { createRoute } from '@tanstack/react-router'

import { listAssets } from '@/api/client'
import { AssetList } from '@/components/asset-list'
import { rootRoute } from '@/routes/root'

export const assetsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  // The loader is the only data-entry point; components stay declarative.
  loader: () => listAssets(),
  component: AssetsPage,
})

function AssetsPage() {
  const assets = assetsRoute.useLoaderData()

  return (
    <section>
      <h1 className='mb-4 text-2xl font-semibold text-slate-900'>Assets</h1>
      <AssetList assets={assets} />
    </section>
  )
}
