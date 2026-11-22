# Working in this repo

Go API + React front end for a live coding session. Both are deliberately tiny: read every file
before adding to it, and prefer extending what is here over introducing a pattern.

## Commands

```sh
mise install                  # go + node pinned in .mise.toml; already installed on this machine
mise run test                 # both halves, offline
scripts/preflight.sh          # proves the whole thing works with no network
scripts/dev.sh                # api :8080 + web :5173 together
scripts/preflight.sh --ci     # the same gate CI runs: installs deps, skips port checks
cd server && make test        # or: go test ./...
cd server && make lint        # golangci-lint, standard set
cd web && npx vitest run      # or: npm run dev / npm run build
cd web && npm run lint        # eslint + prettier (formatting is a lint error here)
```

Language rules live next to the code: `server/AGENTS.md` and `web/AGENTS.md`.

## Boundaries

- **Always**: run `mise run test` before saying a change is done; run `scripts/preflight.sh` before
  declaring the exercise finished; quote the command output rather than summarising it.
- **Ask first**: adding any dependency, changing the JSON shape of an endpoint, deleting the
  `assets` demo resource.
- **Never**: run `npm ci` or delete `node_modules` (offline install fails), commit secrets, or edit
  the versions in `.mise.toml`.

## Working with an agent in the room

- Propose the interface (types, signatures, error cases) before writing bodies, and wait.
- Generate boilerplate; write the interesting function yourself and be able to defend every line
  that was generated.
- Ask before adding a dependency, a library or a layer.
- Claim a result only after running the command that proves it, and quote the output.
