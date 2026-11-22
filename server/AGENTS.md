# Go side

Layout: `cmd/app` wires flags and lifecycle; `internal/<domain>` holds behaviour behind an
interface; `internal/httpapi` translates HTTP to calls and errors to status codes.

- Dependencies stay few and are **vendored**: `go mod vendor` after any `go get`, so `vendor/`
  builds with no network. `ff` (env + flags) is the only one today.
- Offline check: `env GOPROXY=off go test ./...` must pass with an empty module cache.
- Tests: table-driven with `t.Run` subtests for logic; `httptest.NewServer` for handlers; one test
  file per area. A test carries its case in its name, not in a comment above it.
- Errors: sentinels in the domain package, `errors.Is` at the boundary, log once in the handler.
- Handlers take `*http.Request` and write via the `json.go` helpers; no framework, no middleware
  chain beyond logging and recovery.
- Comments: one line where the code cannot say it. Never restate the function name.
- `make lint` runs golangci-lint's standard set (errcheck included), so every error return is
  handled: `defer func() { _ = f.Close() }()` rather than `defer f.Close()`.
