package httpapi

import (
	"context"

	"starter/internal/asset"
)

// Store is what this package needs, declared here rather than in the package that implements
// it: the consumer decides the shape, and any implementation satisfies it structurally.
type Store interface {
	Create(ctx context.Context, filename string, content []byte) (asset.Asset, error)
	Get(ctx context.Context, id string) (asset.Asset, error)
	List(ctx context.Context) ([]asset.Asset, error)
}
