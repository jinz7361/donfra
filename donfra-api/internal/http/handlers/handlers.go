package handlers

import (
	"context"

	"donfra-api/internal/domain/auth"
	"donfra-api/internal/domain/study"
)

// Handlers holds all service dependencies for HTTP handlers.
type Handlers struct {
	roomSvc  RoomService
	studySvc StudyService
	authSvc  AuthService
}

// RoomService defines the interface for room operations.
type RoomService interface {
	Init(passcode string, size int) (inviteURL string, token string, err error)
	IsOpen() bool
	InviteLink() string
	Headcount() int
	Limit() int
	Validate(token string) bool
	Close() error
	UpdateHeadcount(count int) error
}

// StudyService defines the interface for lesson operations.
type StudyService interface {
	ListPublishedLessons(ctx context.Context) ([]study.Lesson, error)
	ListAllLessons(ctx context.Context) ([]study.Lesson, error)
	GetLessonBySlug(ctx context.Context, slug string) (*study.Lesson, error)
	CreateLesson(ctx context.Context, newLesson *study.Lesson) (*study.Lesson, error)
	UpdateLessonBySlug(ctx context.Context, slug string, updates map[string]any) error
	DeleteLessonBySlug(ctx context.Context, slug string) error
}

// AuthService defines the interface for authentication operations.
type AuthService interface {
	Validate(tokenStr string) (*auth.Claims, error)
	IssueAdminToken(pass string) (string, error)
}

// New creates a new Handlers instance with the given services.
func New(roomSvc RoomService, studySvc StudyService, authSvc AuthService) *Handlers {
	return &Handlers{
		roomSvc:  roomSvc,
		studySvc: studySvc,
		authSvc:  authSvc,
	}
}
