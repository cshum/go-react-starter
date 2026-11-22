package config

import (
	"flag"
	"testing"
)

func TestParsePrecedence(t *testing.T) {
	t.Setenv("APP_ADDR", ":9090")

	tests := []struct {
		name string
		args []string
		want string
	}{
		{name: "env beats default", args: nil, want: ":9090"},
		{name: "flag beats env", args: []string{"-addr", ":1234"}, want: ":1234"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			fs := flag.NewFlagSet("test", flag.ContinueOnError)
			addr := fs.String("addr", ":8080", "listen address")
			if err := Parse(fs, tc.args, "APP"); err != nil {
				t.Fatalf("parse: %v", err)
			}
			if *addr != tc.want {
				t.Errorf("addr = %q, want %q", *addr, tc.want)
			}
		})
	}
}
