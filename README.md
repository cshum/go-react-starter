# go-react-starter

A small Go API and a React front end to start from: one binary for the server, one Vite app for
the UI, one script that proves both work. Nothing here is a framework, and every choice below is
reversible in an afternoon.

## Quick start

```sh
mise install                  # go, node, golangci-lint from .mise.toml
npm --prefix web install      # only when web/node_modules is missing
scripts/dev.sh                # api on :8080, web on :5173   (or: make dev)
make build                    # one binary in server/bin/app with the UI embedded

make                          # lists the targets
scripts/preflight.sh          # the gate: vet, tests -race, lint, build, deps, embedded-binary smoke, ports
scripts/preflight.sh --ci     # same gate as CI: installs deps, skips port checks
```

CI runs exactly that (`--ci`) on push and pull request. This repo also has a second workflow,
`template.yml`, that scaffolds both repo shapes and gates them; generated repos get `ci.yml` only.

## Layout

```
server/     Go: cmd/app (serve, version), internal/{asset,config,httpapi}, vendored ff + zap
web/        React 19 + TypeScript + TanStack Router, code-based routes, data via loaders
scripts/    preflight.sh (the gate), dev.sh (both servers), scaffold.sh (new repo from this one)
```

Rules live next to the code: `server/AGENTS.md` and `web/AGENTS.md`.

## Decisions

Each row is a choice, the reason, and what it costs.

| Choice | Why | Cost |
|---|---|---|
| **Go stdlib `net/http`**, no router library | Go 1.22 method+path patterns (`POST /api/assets`, `GET /api/assets/{id}`) cover what this needs; one less dependency to explain and vendor | No middleware chain or param binding sugar — you write it |
| **`ff/v3` for flags and env**, vendored | One declaration per option; flag beats env beats default | Three vendored modules (ff, zap, zap's multierr), 540 KB; a `go.sum` exists |
| **Domain logic behind an interface** | `internal/asset` is plain Go, so it tests without a server or a database | You write the storage layer when `MemStore` stops being enough |
| **In-memory store by default** | Swapping in Postgres means one new implementation, not a handler rewrite | No persistence, no migrations — deliberate for a starting point |
| **SHA-256 content addressing** | Re-uploading identical bytes returns the stored asset, so `POST` is idempotent on content with no extra key | Storing one file under two names is impossible by design |
| **`zap` plus two middlewares** | Structured fields rather than printf; request logging and panic recovery are the only cross-cutting concerns that earn their place | One more vendored dependency, and `zap.ReplaceGlobals` so fatal errors actually print; `-debug` selects the development config |
| **React 19 + TypeScript `strict`** | Strict mode catches the bug this template exists to prevent: shape drift between API and UI | More annotations at the boundary |
| **TanStack Router, code-based routes** | Typed routes and `loader` functions mean data never enters through `useEffect`; routes are plain objects you can read | Smaller ecosystem than react-router; the loader pattern maps onto react-router v7's data routes |
| **Data via loaders; `useEffect` only for DOM sync** | Effects synchronise with things outside React — observers, listeners, timers — never with the API | One concept to unlearn if you have only fetched in effects |
| **Vite + Tailwind 4** | Fast dev server, one plugin line, no config file to maintain | Utility classes in JSX |
| **Vitest + Testing Library** | Same runner as Vite, so tests need no separate build config | Not Jest; some ecosystem answers assume Jest |
| **ESLint 9 flat config + Prettier** | Formatting is a lint error, so CI cannot pass on unformatted code | The two tools must agree — `eslint-plugin-prettier` makes them one gate |
| **TypeScript held to 6.x** | `typescript-eslint@8` supports `<6.1.0`; TS 7 is released but the lint toolchain is not there yet. `package.json` carries `^6.0.3`, the lockfile the exact version | Revisit when `typescript-eslint` ships TS 7 support |
| **`mise` for the toolchain** | Go, Node and golangci-lint versions live in the repo, so local and CI cannot drift | One tool to install on a new machine |
| **`golangci-lint` standard set** | Defaults (errcheck, govet, staticcheck, unused, ineffassign) catch real defects without a config debate | Style opinions beyond that are yours to add |
| **`vendor/` committed** | `go test` runs with `GOPROXY=off` and an empty module cache: no install step, in CI or on a plane | Vendor diffs show up in pull requests |
| **One gate script, used by CI** | A green local run and a green build mean the same thing; there is no second definition of "passing" | The gate has to stay fast enough to run on every change |
| **No codegen** (no gqlgen, no OpenAPI) | At this size, hand-written types are faster to read and change than a generator pair | Add the generator when the surface justifies it |
| **One binary serves the API and the UI** | Vite builds into `server/dist`, which `go:embed` reads behind `-tags embedui`, so a deploy is a single file; `make build` builds the UI first | Rebuild the binary when only the UI changes |
| **Dockerfile, but no compose** | Every starter in this class ships a deploy contract: multi-stage build, distroless runtime, non-root | You maintain an image you may not deploy |
| **`renovate.json`** | Actions tags, npm carets and the TypeScript pin all drift; a bot keeps them current | One more config file, and PRs to review |

## The demo resource is disposable

`internal/asset`, `testdata/asset.json` and the three `/api/assets` routes are a worked example of
the seam, not the point of the repo. Delete them and the gate still passes: the smoke step asserts
`/healthz`, the SPA fallback and a JSON 404 under `/api/`, so nothing in `scripts/` names a
resource. `newrepo` will always generate the demo, because it copies this template — that is what a
generator does, not a resurrection of code you removed from an existing repo.

## What this deliberately leaves out

Authentication, persistence and migrations, background jobs, tracing, deploy configuration and a
release flow (tags, changelog, image publish). On the API: no update/delete endpoints, no
pagination, no CORS, request IDs, rate limiting or readiness check beyond `/healthz`. In the UI: no
mutation to demonstrate `router.invalidate()`, no loading or error routes, and no end-to-end test
across both halves — the shared fixture pins field names, not behaviour.

Each depends on where the service runs, and each is cheaper to add to a small codebase than to
remove from a large one.

## Scaffolding a new repo from this one

```sh
scripts/scaffold.sh ~/Developer/my-service              # server/ + web/
scripts/scaffold.sh ~/Developer/my-service --go-only    # Go module at the repo root
```

It copies with APFS clones where available, renames the Go module and npm package, runs the gate,
and only then makes the first commit — a red tree is never handed over.

Optionally, put the generator on your `PATH` so it works from any directory:

```sh
ln -sf "$(pwd)/scripts/scaffold.sh" ~/.local/bin/newrepo
newrepo my-service          # server/ + web/
newrepo my-service --go-only  # Go module at the repo root, single-stage Dockerfile, its own README
```
