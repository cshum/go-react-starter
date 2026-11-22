package httpapi_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap"

	"starter/internal/asset"
	"starter/internal/httpapi"
)

func newServer(t *testing.T) string {
	t.Helper()
	log := zap.NewNop()
	srv := httptest.NewServer(httpapi.New(asset.NewMemStore(), log, nil))
	t.Cleanup(srv.Close)
	return srv.URL
}

// upload posts content as multipart form data and decodes the JSON reply.
func upload(t *testing.T, base, field, filename, content string) (*http.Response, asset.Asset) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	part, err := mw.CreateFormFile(field, filename)
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := io.WriteString(part, content); err != nil {
		t.Fatalf("write part: %v", err)
	}
	if err := mw.Close(); err != nil {
		t.Fatalf("close writer: %v", err)
	}

	resp, err := http.Post(base+"/api/assets", mw.FormDataContentType(), &buf)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	t.Cleanup(func() { _ = resp.Body.Close() })

	var d asset.Asset
	if resp.StatusCode != http.StatusBadRequest {
		if err := json.NewDecoder(resp.Body).Decode(&d); err != nil {
			t.Fatalf("decode body: %v", err)
		}
	}
	return resp, d
}

func TestCreateAsset(t *testing.T) {
	base := newServer(t)

	resp, got := upload(t, base, "file", "notes.txt", "hello world")
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want 201", resp.StatusCode)
	}
	if ct := resp.Header.Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		t.Errorf("content-type = %q, want application/json", ct)
	}
	sum := sha256.Sum256([]byte("hello world"))
	if want := hex.EncodeToString(sum[:]); got.SHA256 != want {
		t.Errorf("sha256 = %q, want %q", got.SHA256, want)
	}
	if got.ID == "" {
		t.Error("id is empty")
	}
	if got.Filename != "notes.txt" {
		t.Errorf("filename = %q, want notes.txt", got.Filename)
	}
	if got.Size != int64(len("hello world")) {
		t.Errorf("size = %d, want %d", got.Size, len("hello world"))
	}
	if got.CreatedAt.IsZero() {
		t.Error("created_at is zero")
	}
}

func TestCreateDuplicate(t *testing.T) {
	base := newServer(t)

	_, first := upload(t, base, "file", "a.txt", "same bytes")
	second, dup := upload(t, base, "file", "b.txt", "same bytes")

	if second.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200", second.StatusCode)
	}
	if dup.ID != first.ID {
		t.Errorf("id = %q, want first %q", dup.ID, first.ID)
	}
	if dup.Filename != first.Filename {
		t.Errorf("filename = %q, want first %q", dup.Filename, first.Filename)
	}
}

func TestListAssets(t *testing.T) {
	base := newServer(t)
	for _, name := range []string{"a.txt", "b.txt"} {
		if resp, _ := upload(t, base, "file", name, name); resp.StatusCode != http.StatusCreated {
			t.Fatalf("seed %s: status = %d", name, resp.StatusCode)
		}
	}

	resp, err := http.Get(base + "/api/assets")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	var body struct {
		Assets []asset.Asset `json:"assets"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(body.Assets) != 2 {
		t.Fatalf("len = %d, want 2", len(body.Assets))
	}
	if body.Assets[0].Filename != "a.txt" || body.Assets[1].Filename != "b.txt" {
		t.Errorf("order = %q, %q; want a.txt, b.txt",
			body.Assets[0].Filename, body.Assets[1].Filename)
	}
}

func TestListAssetsEmpty(t *testing.T) {
	base := newServer(t)

	resp, err := http.Get(base + "/api/assets")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if got, want := strings.TrimSpace(string(raw)), `{"assets":[]}`; got != want {
		t.Errorf("body = %s, want %s", got, want)
	}
}

func TestGetAsset(t *testing.T) {
	base := newServer(t)
	_, created := upload(t, base, "file", "notes.txt", "hello")

	resp, err := http.Get(base + "/api/assets/" + created.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}

	var got asset.Asset
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got != created {
		t.Errorf("asset = %+v, want %+v", got, created)
	}
}

func TestErrors(t *testing.T) {
	base := newServer(t)

	tests := []struct {
		name   string
		do     func(t *testing.T) *http.Response
		status int
	}{
		{
			name: "unknown id",
			do: func(t *testing.T) *http.Response {
				return mustGet(t, base+"/api/assets/doc-404")
			},
			status: http.StatusNotFound,
		},
		{
			name: "unknown route",
			do: func(t *testing.T) *http.Response {
				return mustGet(t, base+"/nope")
			},
			status: http.StatusNotFound,
		},
		{
			name: "missing file part",
			do: func(t *testing.T) *http.Response {
				resp, _ := upload(t, base, "wrong", "x.txt", "data")
				return resp
			},
			status: http.StatusBadRequest,
		},
		{
			name: "not multipart",
			do: func(t *testing.T) *http.Response {
				resp, err := http.Post(base+"/api/assets", "application/json", strings.NewReader(`{}`))
				if err != nil {
					t.Fatalf("post: %v", err)
				}
				t.Cleanup(func() { _ = resp.Body.Close() })
				return resp
			},
			status: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := tt.do(t)
			if resp.StatusCode != tt.status {
				t.Fatalf("status = %d, want %d", resp.StatusCode, tt.status)
			}

			var body struct {
				Error string `json:"error"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
				t.Fatalf("decode: %v", err)
			}
			if body.Error == "" {
				t.Error("error message is empty")
			}
		})
	}
}

func mustGet(t *testing.T, url string) *http.Response {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("get %s: %v", url, err)
	}
	t.Cleanup(func() { _ = resp.Body.Close() })
	return resp
}

func TestUploadTooLarge(t *testing.T) {
	base := newServer(t)
	resp, _ := upload(t, base, "file", "big.bin", strings.Repeat("x", 9<<20))
	if resp.StatusCode != http.StatusRequestEntityTooLarge {
		t.Fatalf("status = %d, want %d", resp.StatusCode, http.StatusRequestEntityTooLarge)
	}
}

// failingStore proves the seam: httpapi depends on its own interface, not on asset.MemStore.
type failingStore struct{}

func (failingStore) Create(context.Context, string, []byte) (asset.Asset, error) {
	return asset.Asset{}, errors.New("create failed")
}

func (failingStore) Get(context.Context, string) (asset.Asset, error) {
	return asset.Asset{}, errors.New("get failed")
}

func (failingStore) List(context.Context) ([]asset.Asset, error) {
	return nil, errors.New("list failed")
}

func TestStoreFailureMapsTo500(t *testing.T) {
	log := zap.NewNop()
	srv := httptest.NewServer(httpapi.New(failingStore{}, log, nil))
	t.Cleanup(srv.Close)

	resp, err := http.Get(srv.URL + "/api/assets")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	t.Cleanup(func() { _ = resp.Body.Close() })

	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", resp.StatusCode)
	}
}

func TestFilenameIsBaseName(t *testing.T) {
	base := newServer(t)
	resp, got := upload(t, base, "file", "../../etc/passwd", "payload")
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("status = %d, want 201", resp.StatusCode)
	}
	if got.Filename != "passwd" {
		t.Errorf("filename = %q, want %q", got.Filename, "passwd")
	}
}

// A multipart part without a filename attribute arrives as a form field, not a file, so this
// exercises the missing-part branch rather than the (defensive) empty-filename check.
func TestMissingFilePartRejected(t *testing.T) {
	base := newServer(t)
	resp, _ := upload(t, base, "file", "", "payload")
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", resp.StatusCode)
	}
}
