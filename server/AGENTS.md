# Go side

Layout: `cmd/app` wires flags and lifecycle; `internal/<domain>` owns data and behaviour;
`internal/httpapi` translates HTTP to calls and errors to status codes; `internal/config` parses
flags and env.

- **Packages are named for what they provide, not the layer.** `internal/asset` holds `Asset` and
  the operations on it: singular, lowercase, no plurals (`assets`), no drawers (`models`, `util`),
  and no `store`/`db`/`datastore` — those describe a role and stutter against their own types. A
  new implementation is a subpackage (`internal/asset/postgres`), not a renamed package.
- **Interfaces belong to the consumer.** `httpapi` declares the `Store` it needs; the domain
  package exports a concrete `MemStore` and no interface. Accept interfaces, return structs.
- Dependencies stay few and are **vendored**: `go mod vendor` after any `go get`, so `vendor/`
  builds with no network. `ff` (flags and env) and `zap` (logging) are the two today.
- Offline check: `env GOPROXY=off go test ./...` must pass with an empty module cache.
- Tests: `go test -race ./...`; table-driven with `t.Run` subtests for logic, `httptest.NewServer`
  for handlers, one test file per area. A test carries its case in its name, not in a comment.
- Errors: sentinels in the domain package, `errors.Is` at the boundary, log once in the handler,
  and handle every error return: `defer func() { _ = f.Close() }()` rather than `defer f.Close()`.
- Handlers: `http.MaxBytesReader` on uploads (answer `413`), `X-Content-Type-Options: nosniff` on
  JSON, a `{"error":…}` body for every failure, and panic recovery that re-panics on
  `http.ErrAbortHandler` and refuses to write a 500 once headers are out.
- `make lint` runs golangci-lint's standard set; `make build` embeds the UI with `-tags embedui`
  and takes the version from `git describe`.
- Comments: one line where the code cannot say it. Never restate the function name.
