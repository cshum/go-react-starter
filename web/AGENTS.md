# Web side

- Data enters through TanStack Router `loader`s, never through `useEffect`. The guard enforces zero
  `useEffect` in `src/routes`, `src/api` and `src/loaders`; mutations call the API then
  `router.invalidate()`. The demo has no mutation yet; that is where it goes.
- `useEffect` is for syncing with things outside React — DOM measurement, listeners, timers,
  observers, third-party widgets — and every one needs a cleanup. It is never for fetching,
  derived state, or resetting state on a prop change.
- Routes are code-based in `src/router.tsx` (`createRootRoute`/`createRoute`); no file-based plugin,
  no generated route tree.
- All HTTP lives in `src/api/client.ts`. Types are hand-written; no codegen in a live session.
- Components are presentational and take props, so most tests render them without a router. One
  that renders `<Link>` needs a memory-history router in its test.
- `strict` TypeScript is on; import from `@/…`, never `../../`.
- `npm run lint` is the gate: eslint + prettier, and importing `useEffect` in `src/routes`,
  `src/api` or `src/loaders` is a hard error. `npm run format` before you commit.
- Tests: pure functions in `src/lib/*.test.ts`, components with Testing Library. One test file per
  area, named for the behaviour, not the module.
