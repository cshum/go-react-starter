// Package httpapi exposes the asset API over net/http.
package httpapi

import (
	"log/slog"
	"net/http"

	"starter/internal/asset"
)

// New returns a ready handler for store: routes, logging, panic recovery.
func New(store asset.Store, log *slog.Logger, ui http.Handler) http.Handler {
	a := &api{store: store, log: log}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/assets", a.create)
	mux.HandleFunc("GET /api/assets", a.list)
	mux.HandleFunc("GET /api/assets/{id}", a.get)
	mux.HandleFunc("GET /healthz", a.health)
	mux.HandleFunc("/api/", a.notFound)
	if ui != nil {
		mux.Handle("/", ui)
	} else {
		mux.HandleFunc("/", a.notFound)
	}

	return withLogging(log, withRecover(log, mux))
}
