#!/usr/bin/env bash
# newrepo — create a fresh working repo from the kit in seconds, with green tests.
#
#   newrepo rate-limiter            -> ~/Developer/rate-limiter with server/ + web/
#   newrepo ~/some/where/thing      -> exactly there
#   newrepo rate-limiter --go-only  -> Go module at the repo root, no web/ tree
#   newrepo rate-limiter --blank    -> same, minus the demo resource
#
# The generated repo includes the demo resource from this template, by design: delete it in the new
# repo and nothing in scripts/ breaks.
#
# Copies with APFS clones (cp -c), so node_modules costs no time and no extra disk.
set -uo pipefail

# resolve symlinks so the template is found when this is linked into PATH
SELF="$0"
while [ -L "$SELF" ]; do
  HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
  SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$HERE/$SELF" ;; esac
done
KIT="$(cd -P "$(dirname "$SELF")/.." && pwd)"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,8p' "$SELF" | sed 's/^# \{0,1\}//' >&2
  exit 0
fi

TARGET="${1:-}"
shift || true
GO_ONLY=0
BLANK=0
for a in "$@"; do
  [ "$a" = "--go-only" ] && GO_ONLY=1
  [ "$a" = "--blank" ] && BLANK=1
done

if [ -z "$TARGET" ]; then
  sed -n '2,8p' "$SELF" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

# a bare name lands in ~/Developer
case "$TARGET" in
  */*) ;;
  *) TARGET="$HOME/Developer/$TARGET" ;;
esac

if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "refusing: $TARGET exists and is not empty" >&2
  exit 1
fi
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
NAME="$(basename "$TARGET" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-$//')"

# APFS clones when available, plain copy otherwise
clone_tree() { cp -Rc "$1" "$2" 2>/dev/null || cp -R "$1" "$2"; }

printf 'scaffolding %s -> %s\n' "$NAME" "$TARGET"
if [ "$GO_ONLY" -eq 1 ]; then
  # module at the repo root: cmd/, internal/, go.mod at the top level
  clone_tree "$KIT/server/." "$TARGET/"
  mv "$TARGET/AGENTS.md" "$TARGET/.go-rules.md"
  GO_PATH="$TARGET"
else
  clone_tree "$KIT/server" "$TARGET/server"
  clone_tree "$KIT/web" "$TARGET/web"
  cp "$KIT/Makefile" "$TARGET/Makefile"
  GO_PATH="$TARGET/server"
fi
rm -rf "$TARGET/dist" "$TARGET/server/dist"   # build output, not source
clone_tree "$KIT/scripts" "$TARGET/scripts"
cp "$KIT/README.md" "$TARGET/README.md"
cp "$KIT/LICENSE" "$KIT/.editorconfig" "$KIT/.gitignore" "$TARGET/"
cp "$KIT/Dockerfile" "$KIT/.dockerignore" "$KIT/.env.example" "$KIT/renovate.json" "$TARGET/"
clone_tree "$KIT/testdata" "$TARGET/testdata"
cp "$KIT/AGENTS.md" "$TARGET/AGENTS.md"
cp "$KIT/.mise.toml" "$TARGET/.mise.toml"
mkdir -p "$TARGET/.vscode" && cp "$KIT/.vscode/settings.json" "$TARGET/.vscode/settings.json"
mkdir -p "$TARGET/.github/workflows" && cp "$KIT/.github/workflows/ci.yml" "$TARGET/.github/workflows/ci.yml"

# the checker builds a repo from this one; it means nothing once copied, so remove it and every
# line of README that mentions it
rm -f "$TARGET/scripts/recipe-check.sh"
perl -ni -e 'print unless m{recipe-check}' "$TARGET/README.md"

trim_for_go_only() {
  python3 - "$TARGET/AGENTS.md" "$TARGET/.go-rules.md" <<'PY' || exit 1
import sys
agents, rules = sys.argv[1], sys.argv[2]
s = open(agents).read()

def swap(old, new):
    global s
    if old not in s:
        sys.exit("scaffold: AGENTS.md no longer contains: " + old.strip()[:60])
    s = s.replace(old, new)

swap("cd server && make test        # or: go test ./...", "make test                     # or: go test ./...")
swap("mise run test                 # both halves, offline", "mise run test                 # go tests, offline")
swap("cd web && npx vitest run      # or: npm run dev / npm run build\n", "")
swap("cd server && make lint        # golangci-lint, standard set", "make lint                     # golangci-lint, standard set")
swap("cd web && npm run lint        # eslint + prettier (formatting is a lint error here)\n", "")
swap("scripts/dev.sh                # api :8080 + web :5173 together", "make run                      # api on :8080")
swap("Language rules live next to the code: `server/AGENTS.md` and `web/AGENTS.md`.",
     open(rules).read().split("\n", 1)[1].strip())
open(agents, "w").write(s)
PY
  rm -f "$TARGET/scripts/dev.sh" "$TARGET/.go-rules.md"
}
write_go_only_docs() {
  cat > "$TARGET/Dockerfile" <<'EOF'
FROM golang:1.27-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=docker" -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app", "serve"]
EOF

  cat > "$TARGET/README.md" <<'EOF'
# __NAME__

A small Go HTTP service: one binary, stdlib routing, vendored dependencies, tests and lint behind
one script.

## Quick start

```sh
mise install                  # go, node and golangci-lint from .mise.toml
make run                      # serve on :8080 (flag, APP_ADDR, or PORT)
make test                     # go test -race ./...
make lint                     # golangci-lint
scripts/preflight.sh          # the gate: vet, tests -race, lint, build, ports (CI passes --ci)
```

## Layout

```
cmd/app          flags and lifecycle
internal/asset   the domain type, its store and the errors it returns
internal/httpapi HTTP translation: routes, handlers, middleware, JSON helpers
internal/config  flag and env parsing
```

Rules live next to the code in `AGENTS.md`.

## Decisions

- stdlib `net/http` with method+path patterns, no router
- `ff` for flags and env, `zap` for logging, both vendored so `GOPROXY=off` builds
- interfaces declared by the consumer: `httpapi` owns the `Store` it needs
- in-memory store by default; a new implementation is a subpackage
- tests run under `-race`; the same gate runs in CI

## Deliberately absent

Authentication, persistence and migrations, background jobs, tracing, deploy configuration,
pagination, CORS and rate limiting. Each depends on where the service runs.
EOF

  perl -pi -e "s|__NAME__|$NAME|g" "$TARGET/README.md"
}
[ "$GO_ONLY" -eq 1 ] && trim_for_go_only
[ "$GO_ONLY" -eq 1 ] && write_go_only_docs

# name the project in the generated guidance, so a blank session knows what it is looking at
perl -0pi -e "s|# Working in this repo\n|# Working in this repo\n\nProject: \`$NAME\`. Keep it small; extend what is here.\n|" "$TARGET/AGENTS.md"
perl -pi -e "if ($. == 1) { s|^# .*|# $NAME| }" "$TARGET/README.md"

# module path and package name follow the directory, so imports read naturally in the round
perl -pi -e "s|^module starter|module $NAME|" "$GO_PATH/go.mod"
grep -rl '"starter' "$GO_PATH" 2>/dev/null | while read -r f; do
  perl -pi -e "s|\"starter/|\"$NAME/|g; s|\"starter\"|\"$NAME\"|g" "$f"
done
# renaming the module changes import sort order, so let gofmt settle the tree
if command -v gofmt >/dev/null 2>&1; then gofmt -w "$GO_PATH" >/dev/null 2>&1 || true; fi

if [ "$GO_ONLY" -eq 0 ] && [ -f "$TARGET/web/package.json" ]; then
  perl -pi -e "s|\"name\": \"[^\"]+\"|\"name\": \"$NAME-web\"|" "$TARGET/web/package.json"
  [ -f "$TARGET/web/package-lock.json" ] && perl -pi -e "s|\"name\": \"web\"|\"name\": \"$NAME-web\"|g" "$TARGET/web/package-lock.json"
fi

cd "$TARGET" || exit 1

printf 'verifying green before handing over\n'
if [ -d "$TARGET/web/node_modules" ]; then
  ./scripts/preflight.sh --fast || { echo "gate failed — not committing" >&2; exit 1; }
else
  ./scripts/preflight.sh --ci || { echo "gate failed — not committing" >&2; exit 1; }
fi

if [ "$BLANK" -eq 1 ]; then
  ./scripts/strip-demo.sh || { echo "strip failed" >&2; exit 1; }
  ./scripts/preflight.sh --ci >/dev/null 2>&1 || ./scripts/preflight.sh --fast >/dev/null 2>&1 \
    || { echo "gate failed after strip — not committing" >&2; exit 1; }
  printf 'blank: no demo resource\n'
fi

git init -q
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-scaffold}" -c user.email="${GIT_AUTHOR_EMAIL:-scaffold@localhost}" \
  commit -qm "scaffold: $NAME from go-react-starter" || { echo "git commit failed" >&2; exit 1; }

printf '\nready: %s\n' "$TARGET"
if [ "$GO_ONLY" -eq 0 ]; then
  printf '  cd %s && scripts/dev.sh\n' "$TARGET"
  printf '  go:  cd server && make run | make test      (module %s)\n' "$NAME"
  printf '  web: cd web && npm run dev | npx vitest run\n'
else
  printf '  cd %s && make run\n' "$TARGET"
  printf '  go:  make run | make test      (module %s, at the repo root)\n' "$NAME"
fi
printf '\nfirst commit is in place, so `git diff` shows only your work from here.\n'
