// Package config parses flags with environment fallbacks.
package config

import (
	"flag"
	"strings"

	"github.com/peterbourgon/ff/v3"
)

// Parse reads flags, then environment variables named PREFIX_FLAG (ASSET_ADDR and so on).
// An explicit flag wins over the environment, which wins over the default.
func Parse(fs *flag.FlagSet, args []string, prefix string) error {
	return ff.Parse(fs, args, ff.WithEnvVarPrefix(prefix))
}

// ListenAddr turns a bare port into a ":port" address and passes host:port through.
func ListenAddr(v string) string {
	if v == "" || strings.Contains(v, ":") {
		return v
	}
	return ":" + v
}
