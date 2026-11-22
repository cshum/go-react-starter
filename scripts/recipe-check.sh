#!/usr/bin/env bash
# Executes exactly the steps in README "The demo resource is disposable" on a fresh scaffold.
set -euo pipefail

TARGET="${1:-$HOME/Developer/recipe-check}"
rm -rf "$TARGET"
newrepo "$(basename "$TARGET")" >/dev/null
cd "$TARGET"

# --- Delete
rm -rf server/internal/asset
rm -f server/internal/httpapi/store.go server/internal/httpapi/handlers.go server/internal/httpapi/handlers_test.go
rm -f testdata/asset.json
rmdir testdata
rm -f web/src/api/client.ts web/src/api/client.test.ts
rm -f web/src/components/asset-list.tsx web/src/components/asset-list.test.tsx
rm -f web/src/routes/assets.tsx web/src/routes/asset-detail.tsx

# --- Edit 1: router.go, replace New with the block printed in the README
python3 - <<'PY'
import pathlib, re
p = pathlib.Path("server/internal/httpapi/router.go")
s = p.read_text()
i = s.index("// New returns")
s = s[:i] + '''// New returns a ready handler: routes, logging, panic recovery.
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
p.write_text(s)
PY

# --- Edit 2: main.go, drop the asset import and the store argument
sed -i '' '/internal\/asset/d' server/cmd/app/main.go
sed -i '' 's|httpapi.New(asset.NewMemStore(), log, server.UI())|httpapi.New(log, server.UI())|' server/cmd/app/main.go

# --- Edit 3: Dockerfile, drop the demo fixture copy
sed -i '' '/COPY testdata \/app\/testdata/d' Dockerfile

# --- Edit 4: web/src/router.tsx, drop the two routes
python3 - <<'PY'
import pathlib
p = pathlib.Path("web/src/router.tsx")
s = p.read_text()
s = s.replace("import { assetDetailRoute } from '@/routes/asset-detail'\n", "")
s = s.replace("import { assetsRoute } from '@/routes/assets'\n", "")
s = s.replace("rootRoute.addChildren([assetsRoute, assetDetailRoute])", "rootRoute.addChildren([])")
p.write_text(s)
PY

# --- Edit 5: root.tsx, the header link no longer type-checks with no child routes
python3 - <<'PY'
import pathlib
p = pathlib.Path("web/src/routes/root.tsx")
s = p.read_text()
s = s.replace("import { createRootRoute, Link, Outlet } from '@tanstack/react-router'",
              "import { createRootRoute, Outlet } from '@tanstack/react-router'")
s = s.replace("""        <Link to='/' className='text-lg font-semibold text-slate-900'>
          Assets
        </Link>""",
              """        <span className='text-lg font-semibold text-slate-900'>Assets</span>""")
p.write_text(s)
PY

gofmt -w server >/dev/null
echo "=== gate after following the README, nothing else"
./scripts/preflight.sh