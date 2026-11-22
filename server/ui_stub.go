//go:build !embedui

package server

import "net/http"

// UI is nil unless the binary is built with -tags embedui and a web/dist to embed.
func UI() http.Handler { return nil }
