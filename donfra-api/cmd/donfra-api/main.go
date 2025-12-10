package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"donfra-api/internal/config"
	"donfra-api/internal/domain/auth"
	"donfra-api/internal/domain/db"
	"donfra-api/internal/domain/room"
	"donfra-api/internal/domain/study"
	"donfra-api/internal/http/router"
	"donfra-api/internal/pkg/tracing"
)

func main() {
	cfg := config.Load()

	// Initialize Jaeger tracing
	shutdown, err := tracing.InitTracer("donfra-api", cfg.JaegerEndpoint)
	if err != nil {
		log.Fatalf("failed to initialize tracer: %v", err)
	}
	defer func() {
		if err := shutdown(context.Background()); err != nil {
			log.Printf("failed to shutdown tracer: %v", err)
		}
	}()

	conn, err := db.InitFromEnv()
	if err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	store := room.NewMemoryStore()
	roomSvc := room.NewService(store, cfg.Passcode, cfg.BaseURL)
	authSvc := auth.NewAuthService(cfg.AdminPass, cfg.JWTSecret)
	studySvc := study.NewService(conn)
	r := router.New(cfg, roomSvc, studySvc, authSvc)

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}

	// Graceful shutdown
	go func() {
		log.Printf("[donfra-api] listening on %s", cfg.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[donfra-api] shutting down gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("server forced to shutdown: %v", err)
	}

	log.Println("[donfra-api] server exited")
}
