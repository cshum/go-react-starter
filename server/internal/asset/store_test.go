package asset

import (
	"context"
	"errors"
	"sync"
	"testing"
)

func TestMemStoreCreate(t *testing.T) {
	ctx := context.Background()

	tests := []struct {
		name     string
		filename string
		content  string
		seed     []string
		wantSize int64
		wantErr  error
		wantSame bool
	}{
		{name: "empty file", filename: "empty.txt", content: "", wantSize: 0},
		{name: "text file", filename: "notes.txt", content: "hello", wantSize: 5},
		{name: "binary content", filename: "blob.bin", content: "\x00\x01\x02", wantSize: 3},
		{
			name:     "duplicate content returns existing asset",
			filename: "copy.txt",
			content:  "hello",
			seed:     []string{"hello"},
			wantSize: 5,
			wantErr:  ErrDuplicate,
			wantSame: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := NewMemStore()
			var seeded Asset
			for _, s := range tt.seed {
				d, err := store.Create(ctx, "seed.txt", []byte(s))
				if err != nil {
					t.Fatalf("seed: %v", err)
				}
				seeded = d
			}

			got, err := store.Create(ctx, tt.filename, []byte(tt.content))
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if got.Size != tt.wantSize {
				t.Errorf("size = %d, want %d", got.Size, tt.wantSize)
			}
			if got.SHA256 == "" {
				t.Error("sha256 is empty")
			}
			if got.CreatedAt.IsZero() {
				t.Error("created_at is zero")
			}
			if tt.wantSame {
				if got.ID != seeded.ID {
					t.Errorf("id = %q, want seeded %q", got.ID, seeded.ID)
				}
				if got.Filename != seeded.Filename {
					t.Errorf("filename = %q, want seeded %q", got.Filename, seeded.Filename)
				}
				return
			}
			if got.ID == "" {
				t.Error("id is empty")
			}
			if got.Filename != tt.filename {
				t.Errorf("filename = %q, want %q", got.Filename, tt.filename)
			}
		})
	}
}

func TestMemStoreGetNotFound(t *testing.T) {
	_, err := NewMemStore().Get(context.Background(), "doc-404")
	if !errors.Is(err, ErrNotFound) {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestMemStoreList(t *testing.T) {
	ctx := context.Background()
	store := NewMemStore()
	for _, name := range []string{"a.txt", "b.txt", "c.txt"} {
		if _, err := store.Create(ctx, name, []byte(name)); err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
	}

	docs, err := store.List(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(docs) != 3 {
		t.Fatalf("len = %d, want 3", len(docs))
	}
	for i, d := range docs {
		if want := []string{"a.txt", "b.txt", "c.txt"}[i]; d.Filename != want {
			t.Errorf("docs[%d] = %q, want %q", i, d.Filename, want)
		}
	}
}

func TestMemStoreConcurrent(t *testing.T) {
	const n = 50

	t.Run("distinct content", func(t *testing.T) {
		store := NewMemStore()
		var wg sync.WaitGroup
		for i := 0; i < n; i++ {
			wg.Add(1)
			go func(i int) {
				defer wg.Done()
				if _, err := store.Create(context.Background(), "f.txt", []byte{byte(i)}); err != nil {
					t.Errorf("create %d: %v", i, err)
				}
			}(i)
		}
		wg.Wait()

		docs, err := store.List(context.Background())
		if err != nil {
			t.Fatalf("list: %v", err)
		}
		if len(docs) != n {
			t.Fatalf("len = %d, want %d", len(docs), n)
		}
	})

	t.Run("identical content creates once", func(t *testing.T) {
		store := NewMemStore()
		var (
			wg    sync.WaitGroup
			mu    sync.Mutex
			ids   = make(map[string]struct{}, n)
			dup   int
			other int
		)
		for i := 0; i < n; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				d, err := store.Create(context.Background(), "same.txt", []byte("same"))
				mu.Lock()
				defer mu.Unlock()
				switch {
				case err == nil:
					ids[d.ID] = struct{}{}
				case errors.Is(err, ErrDuplicate):
					dup++
					ids[d.ID] = struct{}{}
				default:
					other++
					t.Errorf("unexpected err: %v", err)
				}
			}()
		}
		wg.Wait()

		if other != 0 {
			t.Fatalf("unexpected errors: %d", other)
		}
		if dup != n-1 {
			t.Errorf("duplicates = %d, want %d", dup, n-1)
		}
		if len(ids) != 1 {
			t.Errorf("distinct ids = %d, want 1", len(ids))
		}
	})
}

func TestCreateIsIdempotentOnContent(t *testing.T) {
	store := NewMemStore()
	ctx := context.Background()

	first, err := store.Create(ctx, "a.txt", []byte("same bytes"))
	if err != nil {
		t.Fatalf("first create: %v", err)
	}
	second, err := store.Create(ctx, "b.txt", []byte("same bytes"))
	if !errors.Is(err, ErrDuplicate) {
		t.Fatalf("second create err = %v, want ErrDuplicate", err)
	}
	if second.ID != first.ID {
		t.Errorf("duplicate returned id %q, want %q", second.ID, first.ID)
	}

	list, err := store.List(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("store holds %d assets, want 1 — a duplicate must not add a record", len(list))
	}
}
