# web

React 19 + TypeScript + TanStack Router (code-based routes), Vite, Tailwind 4.
Boilerplate, not a product: two routes, one fetch client, one formatter, three test files.

## Run

```bash
npm install      # only if node_modules is missing
npm run dev      # http://localhost:5173, proxies /api -> :8080 (or $PORT)
npm test         # vitest run
npm run lint     # eslint + prettier
npm run format   # prettier --write
npm run build    # tsc -b && vite build
```

Point the UI at another backend with `VITE_API_URL` (defaults to `/api`).

## API contract

```
GET /api/assets        -> { assets: Asset[] }
GET /api/assets/:id    -> Asset
Asset = { id, filename, sha256, size, createdAt }
```

## Layout

```
src/
  api/client.ts               typed fetch wrapper + Asset type
  lib/format.ts               formatBytes(), shortHash()
  components/asset-list.tsx   presentational list, rows link via <Link>
  routes/root.tsx             createRootRoute: header + <Outlet />
  routes/assets.tsx           "/"                loader: listAssets()
  routes/asset-detail.tsx     "/assets/$assetId" loader: getAsset(id)
  router.tsx                  createRouter + routeTree, Register augmentation
  main.tsx                    RouterProvider
  test/setup.ts               jest-dom matchers
```

Data always enters through route `loader` functions. `useEffect` in `src/routes`, `src/api` or
`src/loaders` is a lint error; in components it is only for syncing with the DOM, with cleanup.
