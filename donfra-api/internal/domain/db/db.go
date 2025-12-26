package db

import (
	"fmt"
	"log"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/plugin/opentelemetry/tracing"

	"donfra-api/internal/config"
)

var Conn *gorm.DB

// InitFromEnv initializes the global GORM connection using DATABASE_URL.
// It also handles automatic migrations if needed.
func InitFromEnv() (*gorm.DB, error) {
	cfg := config.Load()
	dsn := cfg.DatabaseURL
	if dsn == "" {
		return nil, fmt.Errorf("DATABASE_URL not set")
	}

	database, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Install OpenTelemetry tracing plugin for automatic SQL query tracing
	if err := database.Use(tracing.NewPlugin()); err != nil {
		return nil, fmt.Errorf("failed to install tracing plugin: %w", err)
	}

	Conn = database

	// Auto-migrate models (optional - we use SQL migrations in docker-entrypoint-initdb.d)
	// Uncomment if you want GORM auto-migration instead of SQL scripts:
	// if err := Conn.AutoMigrate(&study.Lesson{}, &user.User{}); err != nil {
	// 	log.Fatalf("auto-migrate failed: %v", err)
	// }

	log.Println("[db] PostgreSQL connection established")

	return database, nil
}
