// Command app serves the asset API and reports the build version.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"interviewkit/internal/asset"
	"interviewkit/internal/config"
	"interviewkit/internal/httpapi"
)

const version = "0.1.0"

// defaultAddr lets PORT alone work, so a shell export is enough to move the port.
func defaultAddr() string {
	if p := os.Getenv("PORT"); p != "" {
		return config.ListenAddr(p)
	}
	return ":8080"
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch cmd := os.Args[1]; cmd {
	case "serve":
		err = serve(os.Args[2:])
	case "version":
		err = printVersion(os.Args[2:])
	case "help", "-h", "--help":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n\n", cmd)
		usage()
		os.Exit(2)
	}
	if err != nil {
		slog.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `usage: app <command> [flags]

commands:
  serve     run the HTTP API
  version   print the version
`)
}

func serve(args []string) error {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	addr := fs.String("addr", defaultAddr(), "listen address (env: ASSET_ADDR, or PORT)")
	if err := config.Parse(fs, args, "ASSET"); err != nil {
		return err
	}

	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo}))
	srv := &http.Server{
		Addr:              config.ListenAddr(*addr),
		Handler:           httpapi.New(asset.NewMemStore(), log),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	errs := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errs <- err
		}
	}()

	select {
	case err := <-errs:
		return err
	case <-ctx.Done():
	}

	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}

func printVersion(args []string) error {
	fs := flag.NewFlagSet("version", flag.ExitOnError)
	asJSON := fs.Bool("json", false, "print as JSON")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *asJSON {
		return json.NewEncoder(os.Stdout).Encode(map[string]string{"version": version})
	}
	fmt.Println(version)
	return nil
}
