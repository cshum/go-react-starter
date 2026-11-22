package asset

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

// MemStore keeps assets in memory, indexed by id and by content hash.
type MemStore struct {
	mu    sync.RWMutex
	byID  map[string]Asset
	bySum map[string]string
	order []string
	seq   int
}

func NewMemStore() *MemStore {
	return &MemStore{
		byID:  make(map[string]Asset),
		bySum: make(map[string]string),
	}
}

func (m *MemStore) Create(ctx context.Context, filename string, content []byte) (Asset, error) {
	if err := ctx.Err(); err != nil {
		return Asset{}, err
	}
	sum := sha256.Sum256(content)
	key := hex.EncodeToString(sum[:])

	m.mu.Lock()
	defer m.mu.Unlock()
	if id, ok := m.bySum[key]; ok {
		return m.byID[id], ErrDuplicate
	}
	m.seq++
	d := Asset{
		ID:        fmt.Sprintf("asset-%d", m.seq),
		Filename:  filename,
		SHA256:    key,
		Size:      int64(len(content)),
		CreatedAt: time.Now().UTC(),
	}
	m.byID[d.ID] = d
	m.bySum[key] = d.ID
	m.order = append(m.order, d.ID)
	return d, nil
}

func (m *MemStore) Get(ctx context.Context, id string) (Asset, error) {
	if err := ctx.Err(); err != nil {
		return Asset{}, err
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	d, ok := m.byID[id]
	if !ok {
		return Asset{}, ErrNotFound
	}
	return d, nil
}

func (m *MemStore) List(ctx context.Context) ([]Asset, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	out := make([]Asset, 0, len(m.order))
	for _, id := range m.order {
		out = append(out, m.byID[id])
	}
	return out, nil
}
