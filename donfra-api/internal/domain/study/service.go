package study

import (
	"context"
	"errors"
	"strings"

	"gorm.io/gorm"

	"donfra-api/internal/domain/auth"
	"donfra-api/internal/pkg/tracing"
)

type Lister interface {
	ListPublishedLessons(ctx context.Context) ([]Lesson, error)
	ListAllLessons(ctx context.Context) ([]Lesson, error)
}

type Getter interface {
	GetLessonBySlug(ctx context.Context, slug string) (*Lesson, error)
}

type LessonCreator interface {
	CreateLesson(ctx context.Context, lesson *Lesson) (*Lesson, error)
}

type LessonUpdater interface {
	UpdateLessonBySlug(ctx context.Context, slug string, updates map[string]interface{}) error
}

type LessonDeleter interface {
	DeleteLessonBySlug(ctx context.Context, slug string) error
}

// Service implements CRUD operations for lessons.
type Service struct {
	db   *gorm.DB
	auth *auth.AuthService
}

func NewService(db *gorm.DB, auth *auth.AuthService) *Service {
	return &Service{db: db, auth: auth}
}

// func (s *Service) Create(ctx context.Context, token string, lesson *Lesson) (*Lesson, error) {
// 	if err := s.requireAdmin(token); err != nil {
// 		return nil, err
// 	}
// 	if err := s.db.WithContext(ctx).Create(lesson).Error; err != nil {
// 		return nil, err
// 	}
// 	return lesson, nil
// }

func (s *Service) Update(ctx context.Context, token, slug string, updates *Lesson) (*Lesson, error) {
	if err := s.requireAdmin(token); err != nil {
		return nil, err
	}

	var lesson Lesson
	if err := s.db.WithContext(ctx).Where("slug = ?", slug).First(&lesson).Error; err != nil {
		return nil, err
	}

	lesson.Title = updates.Title
	lesson.Markdown = updates.Markdown
	lesson.Excalidraw = updates.Excalidraw
	lesson.IsPublished = updates.IsPublished

	if err := s.db.WithContext(ctx).Save(&lesson).Error; err != nil {
		return nil, err
	}
	return &lesson, nil
}

func (s *Service) Delete(ctx context.Context, token, slug string) error {
	if err := s.requireAdmin(token); err != nil {
		return err
	}
	return s.db.WithContext(ctx).Where("slug = ?", slug).Delete(&Lesson{}).Error
}

func (s *Service) Load(ctx context.Context, slug string) (*Lesson, error) {
	var lesson Lesson
	if err := s.db.WithContext(ctx).Where("slug = ?", slug).First(&lesson).Error; err != nil {
		return nil, err
	}
	return &lesson, nil
}

func (s *Service) GetLessonBySlug(ctx context.Context, slug string) (*Lesson, error) {
	ctx, span := tracing.StartSpan(ctx, "study.GetLessonBySlug",
		tracing.AttrDBOperation.String("SELECT"),
		tracing.AttrDBTable.String("lessons"),
		tracing.AttrLessonSlug.String(slug),
	)
	defer span.End()

	var lesson Lesson
	if err := s.db.WithContext(ctx).Where("slug = ?", slug).First(&lesson).Error; err != nil {
		tracing.RecordError(span, err)
		return nil, err
	}
	return &lesson, nil
}

// CreateLesson inserts a lesson. Caller must ensure admin authorization (e.g., via middleware).
func (s *Service) CreateLesson(ctx context.Context, newLesson *Lesson) (*Lesson, error) {
	ctx, span := tracing.StartSpan(ctx, "study.CreateLesson",
		tracing.AttrDBOperation.String("INSERT"),
		tracing.AttrDBTable.String("lessons"),
		tracing.AttrLessonSlug.String(newLesson.Slug),
		tracing.AttrLessonIsPublished.Bool(newLesson.IsPublished),
	)
	defer span.End()

	if err := s.db.WithContext(ctx).Create(newLesson).Error; err != nil {
		tracing.RecordError(span, err)
		return nil, err
	}

	return newLesson, nil
}

// UpdateLessonBySlug updates fields for the given lesson slug.
func (s *Service) UpdateLessonBySlug(ctx context.Context, slug string, updates map[string]any) error {
	if len(updates) == 0 {
		return errors.New("no updates provided")
	}
	res := s.db.WithContext(ctx).Model(&Lesson{}).Where("slug = ?", slug).Updates(updates)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// DeleteLessonBySlug deletes a lesson by slug.
func (s *Service) DeleteLessonBySlug(ctx context.Context, slug string) error {
	res := s.db.WithContext(ctx).Where("slug = ?", slug).Delete(&Lesson{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

// ListPublishedLessons returns all lessons marked as published.
func (s *Service) ListPublishedLessons(ctx context.Context) ([]Lesson, error) {
	ctx, span := tracing.StartSpan(ctx, "study.ListPublishedLessons",
		tracing.AttrDBOperation.String("SELECT"),
		tracing.AttrDBTable.String("lessons"),
	)
	defer span.End()

	var lessons []Lesson
	if err := s.db.WithContext(ctx).Where("is_published = ?", true).Find(&lessons).Error; err != nil {
		tracing.RecordError(span, err)
		return nil, err
	}
	return lessons, nil
}

// ListAllLessons returns all lessons (both published and unpublished).
func (s *Service) ListAllLessons(ctx context.Context) ([]Lesson, error) {
	ctx, span := tracing.StartSpan(ctx, "study.ListAllLessons",
		tracing.AttrDBOperation.String("SELECT"),
		tracing.AttrDBTable.String("lessons"),
	)
	defer span.End()

	var lessons []Lesson
	if err := s.db.WithContext(ctx).Find(&lessons).Error; err != nil {
		tracing.RecordError(span, err)
		return nil, err
	}
	return lessons, nil
}

func (s *Service) requireAdmin(token string) error {
	if s.auth == nil {
		return errors.New("auth service not configured")
	}
	if strings.TrimSpace(token) == "" {
		return errors.New("missing token")
	}
	claims, err := s.auth.Validate(token)
	if err != nil {
		return err
	}
	if claims.Subject != "admin" {
		return errors.New("unauthorized")
	}
	return nil
}
