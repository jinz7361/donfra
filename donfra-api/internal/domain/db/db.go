package db

import (
	"fmt"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"donfra-api/internal/config"
)

var Conn *gorm.DB

// InitFromEnv initializes the global GORM connection using DATABASE_URL.
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

	Conn = database

	// if err := Conn.AutoMigrate(&study.Lesson{}); err != nil {
	// 	log.Fatalf("auto-migrate Lesson failed: %v", err)
	// }

	return database, nil
}
