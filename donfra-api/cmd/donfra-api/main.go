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
	"donfra-api/internal/pkg/metrics"
	"donfra-api/internal/pkg/tracing"

	"github.com/redis/go-redis/v9"
)

func main() {
	cfg := config.Load()

	// Initialize OpenTelemetry tracing
	shutdownTracer, err := tracing.InitTracer("donfra-api", cfg.JaegerEndpoint)
	if err != nil {
		log.Fatalf("failed to initialize tracer: %v", err)
	}
	defer func() {
		if err := shutdownTracer(context.Background()); err != nil {
			log.Printf("failed to shutdown tracer: %v", err)
		}
	}()

	// Initialize OpenTelemetry metrics
	shutdownMetrics, err := metrics.InitMetrics("donfra-api", cfg.JaegerEndpoint)
	if err != nil {
		log.Fatalf("failed to initialize metrics: %v", err)
	}
	defer func() {
		if err := shutdownMetrics(context.Background()); err != nil {
			log.Printf("failed to shutdown metrics: %v", err)
		}
	}()

	conn, err := db.InitFromEnv()
	if err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	// Initialize room repository (Redis or Memory)
	var roomRepo room.Repository
	if cfg.UseRedis && cfg.RedisAddr != "" {
		redisClient := redis.NewClient(&redis.Options{
			Addr: cfg.RedisAddr,
		})
		// Test Redis connection
		if err := redisClient.Ping(context.Background()).Err(); err != nil {
			log.Fatalf("failed to connect to Redis at %s: %v", cfg.RedisAddr, err)
		}
		roomRepo = room.NewRedisRepository(redisClient)
		log.Printf("[donfra-api] using Redis repository at %s", cfg.RedisAddr)
	} else {
		roomRepo = room.NewMemoryRepository()
		log.Println("[donfra-api] using in-memory repository")
	}

	roomSvc := room.NewService(roomRepo, cfg.Passcode, cfg.BaseURL)
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
