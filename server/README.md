# server

Asset API in Go. Standard library plus `ff` (flags/env) and `zap` (logging), vendored — `go test ./...`
runs with `GOPROXY=off` and an empty module cache.

## Commands

```sh
make run     # go run ./cmd/app serve   (-addr, else APP_ADDR, else PORT, else :8080)
make build   # go build -o bin/app ./cmd/app
make test    # go test -race ./...
make lint    # golangci-lint run ./...
make vet
```

CLI: `go run ./cmd/app version [-json]`.

## API

```sh
curl -F file=@notes.txt localhost:8080/api/assets
curl localhost:8080/api/assets
curl localhost:8080/api/assets/asset-1
curl localhost:8080/healthz
```

| Method | Path               | Result                             |
|--------|--------------------|------------------------------------|
| POST   | `/api/assets`      | 201 new, 200 when the bytes repeat |
| GET    | `/api/assets`      | `{"assets":[...]}`                 |
| GET    | `/api/assets/{id}` | 200 asset, 404 `{"error":"..."}`   |
| GET    | `/healthz`         | `{"status":"ok"}`                  |

Uploads are `multipart/form-data` with a `file` field, capped at 8 MiB (`413` beyond that).
Content is addressed by SHA-256, so re-uploading identical bytes returns the stored asset and
POST is idempotent on content.
