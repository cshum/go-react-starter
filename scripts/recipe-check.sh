#!/usr/bin/env bash
# Executes exactly the steps in README "The demo resource is disposable" on a fresh scaffold.
# Template-only: scaffold.sh deletes this file from generated repos.
set -euo pipefail

TARGET="${1:-$(mktemp -d)/recipe-check}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "refusing to delete a non-empty target: $TARGET" >&2
  exit 1
fi

rm -rf "$TARGET"
"$HERE/scaffold.sh" "$TARGET" >/dev/null
cd "$TARGET"

CI_FLAG=""
if [ -n "${CI:-}" ]; then CI_FLAG="--ci"; fi

fail() { echo "recipe: $1" >&2; exit 1; }

# --- Delete
rm -rf server/internal/asset
rm -f server/internal/httpapi/store.go server/internal/httpapi/handlers.go \
      server/internal/httpapi/handlers_test.go
rm -f testdata/asset.json
rmdir testdata
rm -f web/src/api/client.ts web/src/api/client.test.ts
rm -f web/src/components/asset-list.tsx web/src/components/asset-list.test.tsx
rm -f web/src/routes/assets.tsx web/src/routes/asset-detail.tsx

# --- Edit 1: router.go, replace New with the block printed in the README
python3 - <<'PY'
import pathlib, sys

p = pathlib.Path("server/internal/httpapi/router.go")
src = p.read_text()
i = src.index("// New returns")
j = src.index("\n}\n", i) + 3  # end of New only; anything added below it survives
body = '''// New returns a ready handler: routes, logging, panic recovery.
func New(log *zap.Logger, ui http.Handler) http.Handler {
	a := &api{log: log}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", a.health)
	mux.HandleFunc("/api/", a.notFound)
	if ui != nil {
		mux.Handle("/", ui)
	} else {
		mux.HandleFunc("/", a.notFound)
	}

	return withLogging(log, withRecover(log, mux))
}
'''
if src[i:j] == body:
    sys.exit("router.go already has the demo-free New")
p.write_text(src[:i] + body + src[j:])
PY

# --- Edit 2: main.go, drop the asset import and the store argument
perl -ni -e 'print unless m{internal/asset}' server/cmd/app/main.go
perl -pi -e 's/httpapi\.New\(asset\.NewMemStore\(\), log, server\.UI\(\)\)/httpapi.New(log, server.UI())/' server/cmd/app/main.go
grep -q 'httpapi.New(log, server.UI())' server/cmd/app/main.go || fail "main.go was not edited"

# --- Edit 3: Dockerfile, drop the demo fixture copy
perl -ni -e 'print unless m{COPY testdata /app/testdata}' Dockerfile
grep -q 'COPY testdata' Dockerfile && fail "Dockerfile was not edited"

# --- Edit 4: web/src/router.tsx, drop the two routes
python3 - <<'PY'
import pathlib, sys

p = pathlib.Path("web/src/router.tsx")
s = p.read_text()
before = s
s = s.replace("import { assetDetailRoute } from '@/routes/asset-detail'\n", "")
s = s.replace("import { assetsRoute } from '@/routes/assets'\n", "")
s = s.replace("rootRoute.addChildren([assetsRoute, assetDetailRoute])", "rootRoute.addChildren([])")
if s == before:
    sys.exit("router.tsx was not edited — has the route tree changed shape?")
p.write_text(s)
PY

# --- Edit 5: root.tsx, the header link no longer type-checks with no child routes
python3 - <<'PY'
import pathlib, sys

p = pathlib.Path("web/src/routes/root.tsx")
s = p.read_text()
before = s
s = s.replace("import { createRootRoute, Link, Outlet } from '@tanstack/react-router'",
              "import { createRootRoute, Outlet } from '@tanstack/react-router'")
s = s.replace("""        <Link to='/' className='text-lg font-semibold text-slate-900'>
          Assets
        </Link>""",
              """        <span className='text-lg font-semibold text-slate-900'>Assets</span>""")
if s == before:
    sys.exit("root.tsx was not edited")
p.write_text(s)
PY

gofmt -w server >/dev/null

echo "== recipe applied to $TARGET"
./scripts/preflight.sh $CI_FLAG