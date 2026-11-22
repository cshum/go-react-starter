#!/usr/bin/env bash
# Proves the interview kit builds and tests with no network.
# Run: scripts/preflight.sh          (full)
#      scripts/preflight.sh --fast   (skip the web build, keep tests)
set -uo pipefail

# resolve symlinks so this works when linked into PATH
SELF="$0"
while [ -L "$SELF" ]; do
  HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
  SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$HERE/$SELF" ;; esac
done
ROOT="$(cd -P "$(dirname "$SELF")/.." && pwd)"
FAST=0
CI=0
for a in "$@"; do
  case "$a" in
    --fast) FAST=1 ;;
    --ci) CI=1 ;;
  esac
done
fail=0

# Toolchain comes from .mise.toml when mise is present, so the versions match what the repo pins.
GO_DIR="server"
[ -d "$ROOT/server" ] || GO_DIR=""

MISE_CMD=""
if command -v mise >/dev/null 2>&1 && [ -f "$ROOT/.mise.toml" ]; then
  MISE_CMD="mise exec --"
fi

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()   { printf '   ok    %s\n' "$*"; }
bad()  { printf '   FAIL  %s\n' "$*"; fail=1; }
time_it() { local s; s=$(date +%s); "$@"; local rc=$?; printf '   %ss  %s\n' "$(( $(date +%s) - s ))" "$*"; return $rc; }

step "toolchain"
for cmd in go node npm git make curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    case "$cmd" in
      go|git) v="$("$cmd" version 2>/dev/null | head -1)" ;;
      *)      v="$("$cmd" --version 2>/dev/null | head -1)" ;;
    esac
    ok "$cmd $v"
  else
    bad "$cmd not found"
  fi
done

step "pinned toolchain (.mise.toml)"
if [ -n "$MISE_CMD" ]; then
  ( cd "$ROOT" && $MISE_CMD go version && $MISE_CMD node -v ) || bad "mise exec"
  ok "resolved through mise"
else
  printf '   note  mise not installed — using system go/node, versions may drift\n'
fi

step "network is optional (recording reachability, not requiring it)"
if curl -fsS --max-time 3 -o /dev/null https://proxy.golang.org 2>/dev/null; then
  ok "internet reachable"
else
  ok "no internet — expected at the venue, kit must still pass below"
fi

step "go: vet + build + test with GOPROXY=off"
if [ -f "$ROOT/${GO_DIR:+$GO_DIR/}go.mod" ]; then
  (
    cd "$ROOT/${GO_DIR:-.}" || exit 1
    export GOPROXY=off GOTOOLCHAIN=local
    time_it $MISE_CMD go vet ./...    || bad "go vet"
    time_it $MISE_CMD go build ./...  || bad "go build"
    time_it $MISE_CMD go test -race ./... || bad "go test"
    time_it $MISE_CMD golangci-lint run ./... || bad "golangci-lint"
    exit $fail
  ) || fail=1
  [ $fail -eq 0 ] && ok "go module is offline-clean"
else
  bad "missing $ROOT/go"
fi

step "web: node_modules present, tests pass"
if [ ! -d "$ROOT/web" ]; then
  ok "no web tree (go-only repo)"
elif [ -d "$ROOT/web" ]; then
  (
    cd "$ROOT/web" || exit 1
    if [ -d node_modules ]; then
      ok "node_modules present ($(du -sh node_modules | cut -f1))"
    elif [ "$CI" -eq 1 ]; then
      time_it $MISE_CMD npm ci || bad "npm ci"
    else
      bad "node_modules missing — run: npm --prefix web install (offline reinstall fails with ENOTCACHED)"
    fi
    export npm_config_offline=true npm_config_audit=false npm_config_fund=false
    time_it $MISE_CMD npx vitest run || bad "vitest"
    time_it $MISE_CMD npm run lint --silent || bad "eslint"
    if [ "$FAST" -eq 0 ]; then
      time_it $MISE_CMD npm run build || bad "vite build"
    else
      ok "skipped build (--fast)"
    fi
    exit $fail
  ) || fail=1
else
  bad "missing $ROOT/web"
fi

step "conventions the kit encodes (checked, not just documented)"
if [ -d "$ROOT/web/src" ]; then
  # the data path must not fetch through useEffect; components may still sync with the DOM
  hits=$(grep -rn "useEffect" "$ROOT/web/src/routes" "$ROOT/web/src/api" "$ROOT/web/src/loaders" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$hits" -eq 0 ]; then
    ok "no useEffect in the data path (routes/api/loaders) — data enters through loaders"
  else
    bad "$hits useEffect occurrence(s) in the data path — move that to a loader"
    grep -rn "useEffect" "$ROOT/web/src/routes" "$ROOT/web/src/api" "$ROOT/web/src/loaders" 2>/dev/null | head -3 | sed 's/^/         /'
  fi
fi
step "dependency budget"
if [ -f "$ROOT/${GO_DIR:+$GO_DIR/}go.mod" ]; then
  allowed="github.com/peterbourgon/ff/v3"
  direct=$( cd "$ROOT/${GO_DIR:-.}" && $MISE_CMD go list -deps -f '{{if .Module}}{{.Module.Path}}{{end}}' ./... 2>/dev/null \
    | grep -v '^$' | grep -v "^$(cd "$ROOT/${GO_DIR:-.}" && sed -n 's/^module //p' go.mod)$" | sort -u )
  unexpected=$(printf '%s\n' "$direct" | grep -v "^$allowed$" | grep -v '^$' || true)
  if [ -z "$unexpected" ]; then
    ok "Go direct deps: ff only"
  else
    bad "unexpected Go deps: $(printf '%s' "$unexpected" | tr '\n' ' ')— say why before adding one"
  fi
fi

step "ports the demo uses"
if [ "$CI" -eq 1 ]; then
  ok "skipped in CI"
else
PORTS="8080"; [ -d "$ROOT/web" ] && PORTS="8080 5173"
for p in $PORTS; do
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    printf '   note  :%s already in use: %s\n' "$p" "$(lsof -nP -iTCP:"$p" -sTCP:LISTEN | awk 'NR==2{print $1" pid "$2}')"
  else
    ok ":$p free"
  fi
  done
fi

printf '\n'
if [ $fail -eq 0 ]; then
  if [ -d "$ROOT/web" ]; then
    printf '\033[32mPASS\033[0m  ready. Next: scripts/dev.sh\n'
  else
    printf '\033[32mPASS\033[0m  ready. Next: make run (api on :8080)\n'
  fi
else
  printf '\033[31mFAIL\033[0m  fix the lines above before the interview — do not debug this live.\n'
fi
exit $fail
