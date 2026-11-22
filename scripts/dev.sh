#!/usr/bin/env bash
# Runs the Go service and the Vite dev server together, logs to .run/, and stops both on Ctrl-C.
# Refuses to start if either port is already serving: a stale server answering /healthz makes
# broken code look healthy.
set -uo pipefail

# resolve symlinks so this works when linked into PATH
SELF="$0"
while [ -L "$SELF" ]; do
  HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
  SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$HERE/$SELF" ;; esac
done
ROOT="$(cd -P "$(dirname "$SELF")/.." && pwd)"
PORT="${PORT:-8080}"
GO_DIR="server"
[ -d "$ROOT/server" ] || GO_DIR=""
LOGS="$ROOT/.run"
mkdir -p "$LOGS"

for p in "$PORT" 5173; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'port %s already in use: %s\n' "$p" \
      "$(lsof -nP -iTCP:"$p" -sTCP:LISTEN | awk 'NR==2{print $1" pid "$2}')" >&2
    printf 'stop it first (kill <pid>) — a stale server would answer the health check\n' >&2
    exit 1
  fi
done

cleanup() {
  trap - INT TERM EXIT
  [ -n "${GO_PID:-}" ] && kill "$GO_PID" 2>/dev/null
  [ -n "${WEB_PID:-}" ] && kill "$WEB_PID" 2>/dev/null
  wait 2>/dev/null
  printf '\nstopped\n'
}
trap cleanup INT TERM EXIT

# Build first: the PID we kill is then the server itself, not a `go run` wrapper that leaves its
# child holding the port.
( cd "$ROOT/${GO_DIR:-.}" && mise exec -- go build -o "$LOGS/app" ./cmd/app ) || exit 1
( cd "$ROOT/${GO_DIR:-.}" && exec "$LOGS/app" serve -addr ":$PORT" ) >"$LOGS/go.log" 2>&1 &
GO_PID=$!

( cd "$ROOT/web" && exec npm run dev -- --port 5173 --strictPort ) >"$LOGS/web.log" 2>&1 &
WEB_PID=$!

for _ in $(seq 1 40); do
  if curl -fsS --max-time 1 "http://localhost:$PORT/healthz" >/dev/null 2>&1; then break; fi
  sleep 0.25
done

printf 'api  http://localhost:%s   (log: %s)\n' "$PORT" "$LOGS/go.log"
printf 'web  http://localhost:5173  (log: %s)\n' "$LOGS/web.log"
printf 'health: %s\n' "$(curl -fsS --max-time 2 "http://localhost:$PORT/healthz" || echo 'not up yet — check .run/go.log')"

wait
