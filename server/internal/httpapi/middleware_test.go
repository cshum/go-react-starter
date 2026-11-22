package httpapi

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

func TestRecoverAnswers500(t *testing.T) {
	log := newLogger()
	h := withLogging(log, withRecover(log, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	})))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusInternalServerError)
	}
}

func TestRecoverRepanicsAbortHandler(t *testing.T) {
	log := newLogger()
	h := withRecover(log, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic(http.ErrAbortHandler)
	}))

	defer func() {
		if v := recover(); v != http.ErrAbortHandler {
			t.Fatalf("recovered %v, want http.ErrAbortHandler", v)
		}
	}()
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/", nil))
	t.Fatal("panic did not propagate")
}
