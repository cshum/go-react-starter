# interview-kit

A small Go API (`server/`) and React front end (`web/`) used as a starting point for a
time-boxed exercise. Toolchain pinned, tests and lint behind one script, no installs needed
during a session.

## Run it

```sh
mise install                  # go, node, golangci-lint from .mise.toml
npm --prefix web install      # only when web/node_modules is missing
scripts/dev.sh                # api on :8080, web on :5173
```

## Check it

```sh
scripts/preflight.sh          # toolchain, vet, tests, lint, build, conventions, ports
scripts/preflight.sh --ci     # same gate as CI: installs deps, skips port checks
```

CI runs exactly that (`--ci`) on every push and pull request, so a green local run and a green
build mean the same thing.

## Layout

```
server/     Go: cmd/app (serve, version), internal/{asset,config,httpapi}, vendored ff
web/        React 19 + TypeScript + TanStack Router, code-based routes, data via loaders
scripts/    preflight.sh (the gate), dev.sh (both servers), scaffold.sh (new repo from this one)
```

Rules live next to the code: `server/AGENTS.md` and `web/AGENTS.md`.
