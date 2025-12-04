package study

import (
	"time"

	"gorm.io/datatypes"
)

type Lesson struct {
	ID          uint           `gorm:"primaryKey"`
	Slug        string         `gorm:"not null"`
	Title       string         `gorm:"not null"`
	Markdown    string         `gorm:"type:text;not null"`
	Excalidraw  datatypes.JSON `gorm:"type:jsonb;not null"`
	IsPublished bool           `gorm:"not null;default:true"`
	CreatedAt   time.Time
	UpdatedAt   time.Time
}
