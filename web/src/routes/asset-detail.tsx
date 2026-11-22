import { createRoute, Link } from '@tanstack/react-router'
import type { ErrorComponentProps } from '@tanstack/react-router'

import { getAsset } from '@/api/client'
import { formatBytes, shortHash } from '@/lib/format'
import { rootRoute } from '@/routes/root'

export const assetDetailRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/assets/$assetId',
  loader: ({ params }) => getAsset(params.assetId),
  component: AssetDetailPage,
  errorComponent: AssetError,
})

function AssetDetailPage() {
  const asset = assetDetailRoute.useLoaderData()

  return (
    <section>
      <Link to='/' className='text-sm text-blue-700 hover:underline'>
        ← All assets
      </Link>
      <h1 className='mt-3 mb-4 text-2xl font-semibold text-slate-900'>{asset.filename}</h1>
      <dl className='grid grid-cols-[8rem_1fr] gap-y-2 text-sm'>
        <dt className='text-slate-500'>ID</dt>
        <dd className='font-mono'>{asset.id}</dd>
        <dt className='text-slate-500'>Size</dt>
        <dd>{formatBytes(asset.size)}</dd>
        <dt className='text-slate-500'>SHA-256</dt>
        <dd className='font-mono' title={asset.sha256}>
          {shortHash(asset.sha256)}
        </dd>
        <dt className='text-slate-500'>Created</dt>
        <dd>{new Date(asset.createdAt).toLocaleString()}</dd>
      </dl>
    </section>
  )
}

function AssetError({ error }: ErrorComponentProps) {
  return (
    <section>
      <Link to='/' className='text-sm text-blue-700 hover:underline'>
        ← All assets
      </Link>
      <p className='mt-3 text-red-600'>{error instanceof Error ? error.message : String(error)}</p>
    </section>
  )
}
