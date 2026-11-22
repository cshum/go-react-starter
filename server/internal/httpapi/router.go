// Package httpapi exposes the asset API over net/http.
package httpapi

import (
	"net/http"

	"go.uber.org/zap"
)

// api carries only what every endpoint needs. Resource handlers take their dependencies in their
// own type (assetHandlers in handlers.go), so removing the demo leaves this struct intact.
type api struct {
	log *zap.Logger
}

// health and notFound belong to the router, not to a resource: deleting the demo leaves them here.
func (a *api) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *api) notFound(w http.ResponseWriter, r *http.Request) {
	writeError(w, http.StatusNotFound, "no such route")
}

// New returns a ready handler for store: routes, logging, panic recovery.
func New(store Store, log *zap.Logger, ui http.Handler) http.Handler {
	a := &api{log: log}
	assets := &assetHandlers{store: store, log: log}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/assets", assets.create)
	mux.HandleFunc("GET /api/assets", assets.list)
	mux.HandleFunc("GET /api/assets/{id}", assets.get)
	mux.HandleFunc("GET /healthz", a.health)
	mux.HandleFunc("/api/", a.notFound)
	if ui != nil {
		mux.Handle("/", ui)
	} else {
		mux.HandleFunc("/", a.notFound)
	}

	return withLogging(log, withRecover(log, mux))
}
