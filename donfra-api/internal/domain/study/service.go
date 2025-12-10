package study

import (
	"context"
	"errors"

	"gorm.io/gorm"

	"donfra-api/internal/pkg/tracing"
)

// Service implements CRUD operations for lessons.
type Service struct {
	db *gorm.DB
}

func NewService(db *gorm.DB) *Service {
	return &Service{db: db}
}

// GetLessonBySlug retrieves a lesson by its slug.
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
