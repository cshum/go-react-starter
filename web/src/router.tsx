import { createRouter } from '@tanstack/react-router'

import { assetDetailRoute } from '@/routes/asset-detail'
import { assetsRoute } from '@/routes/assets'
import { rootRoute } from '@/routes/root'

const routeTree = rootRoute.addChildren([assetsRoute, assetDetailRoute])

export const router = createRouter({ routeTree })

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
