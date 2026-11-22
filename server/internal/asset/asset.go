package asset

import (
	"errors"
	"time"
)

var (
	ErrNotFound  = errors.New("asset not found")
	ErrDuplicate = errors.New("asset already exists")
)

// Asset is one stored upload; SHA256 is the dedupe key.
type Asset struct {
	ID        string    `json:"id"`
	Filename  string    `json:"filename"`
	SHA256    string    `json:"sha256"`
	Size      int64     `json:"size"`
	CreatedAt time.Time `json:"createdAt"`
}
