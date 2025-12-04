package main

import (
	"log"
	"net/http"
	"time"

	"donfra-api/internal/config"
	"donfra-api/internal/domain/auth"
	"donfra-api/internal/domain/db"
	"donfra-api/internal/domain/room"
	"donfra-api/internal/domain/study"
	"donfra-api/internal/http/router"
)

func main() {
	cfg := config.Load()

	conn, err := db.InitFromEnv()
	if err != nil {
		log.Fatalf("failed to initialize database: %v", err)
	}

	store := room.NewMemoryStore()
	roomSvc := room.NewService(store, cfg.Passcode, cfg.BaseURL)
	authSvc := auth.NewAuthService(cfg.AdminPass, cfg.JWTSecret)
	studySvc := study.NewService(conn, authSvc)
	r := router.New(cfg, roomSvc, studySvc, authSvc)

	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("[donfra-api] listening on %s", cfg.Addr)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
