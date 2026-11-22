import { Link } from '@tanstack/react-router'

import type { Asset } from '@/api/client'
import { formatBytes, shortHash } from '@/lib/format'

type AssetListProps = {
  assets: Asset[]
}

export function AssetList({ assets }: AssetListProps) {
  if (assets.length === 0) {
    return <p className='text-sm text-slate-500'>No assets yet.</p>
  }

  return (
    <ul className='divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white'>
      {assets.map((asset) => (
        <li key={asset.id} className='flex items-center justify-between gap-4 px-3 py-2'>
          <Link
            to='/assets/$assetId'
            params={{ assetId: asset.id }}
            className='truncate font-medium text-blue-700 hover:underline'
          >
            {asset.filename}
          </Link>
          <span className='shrink-0 text-sm text-slate-500 tabular-nums'>
            {formatBytes(asset.size)} · {shortHash(asset.sha256)}
          </span>
        </li>
      ))}
    </ul>
  )
}
