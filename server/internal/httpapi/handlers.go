package httpapi

import (
	"errors"
	"io"
	"net/http"
	"path/filepath"

	"go.uber.org/zap"

	"starter/internal/asset"
)

const maxUpload = 8 << 20

type api struct {
	store Store
	log   *zap.Logger
}

type listResponse struct {
	Assets []asset.Asset `json:"assets"`
}

func (a *api) create(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxUpload)
	if err := r.ParseMultipartForm(1 << 20); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			writeError(w, http.StatusRequestEntityTooLarge, "upload exceeds 8MiB")
			return
		}
		writeError(w, http.StatusBadRequest, "expected multipart/form-data with a file field")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, `missing "file" part`)
		return
	}
	defer func() { _ = file.Close() }()
	if header.Filename == "" {
		writeError(w, http.StatusBadRequest, "filename is required")
		return
	}
	content, err := io.ReadAll(file)
	if err != nil {
		writeError(w, http.StatusBadRequest, "unreadable file")
		return
	}

	d, err := a.store.Create(r.Context(), filepath.Base(header.Filename), content)
	switch {
	case errors.Is(err, asset.ErrDuplicate):
		writeJSON(w, http.StatusOK, d)
	case err != nil:
		a.log.Error("create", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "create failed")
	default:
		writeJSON(w, http.StatusCreated, d)
	}
}

func (a *api) list(w http.ResponseWriter, r *http.Request) {
	docs, err := a.store.List(r.Context())
	if err != nil {
		a.log.Error("list", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "list failed")
		return
	}
	if docs == nil {
		docs = []asset.Asset{}
	}
	writeJSON(w, http.StatusOK, listResponse{Assets: docs})
}

func (a *api) get(w http.ResponseWriter, r *http.Request) {
	d, err := a.store.Get(r.Context(), r.PathValue("id"))
	switch {
	case errors.Is(err, asset.ErrNotFound):
		writeError(w, http.StatusNotFound, "asset not found")
	case err != nil:
		a.log.Error("get", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "get failed")
	default:
		writeJSON(w, http.StatusOK, d)
	}
}

func (a *api) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *api) notFound(w http.ResponseWriter, r *http.Request) {
	writeError(w, http.StatusNotFound, "no such route")
}
