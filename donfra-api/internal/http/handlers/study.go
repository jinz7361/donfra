package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"gorm.io/gorm"

	"donfra-api/internal/domain/study"
	"donfra-api/internal/http/middleware"
	"donfra-api/internal/pkg/httputil"
)

// ListLessonsHandler handles GET /api/lessons and returns lessons based on auth status.
// Admin users see all lessons (published + unpublished), regular users see only published.
// Requires OptionalAdmin middleware to set context.
func (h *Handlers) ListLessonsHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}

	var lessons []study.Lesson
	var err error
	if middleware.IsAdminFromContext(r.Context()) {
		lessons, err = h.studySvc.ListAllLessons(r.Context())
	} else {
		lessons, err = h.studySvc.ListPublishedLessons(r.Context())
	}

	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "failed to load lessons")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, lessons)
}

// GetLessonBySlugHandler handles GET /api/lessons/{slug} and returns the lesson with full content.
// Unpublished lessons can only be accessed by admin users.
// Requires OptionalAdmin middleware to set context.
func (h *Handlers) GetLessonBySlugHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}
	slug := chi.URLParam(r, "slug")
	if slug == "" {
		httputil.WriteError(w, http.StatusBadRequest, "slug is required")
		return
	}

	lesson, err := h.studySvc.GetLessonBySlug(r.Context(), slug)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "lesson not found")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "failed to load lesson")
		return
	}

	// If lesson is unpublished, verify admin access
	if !lesson.IsPublished && !middleware.IsAdminFromContext(r.Context()) {
		httputil.WriteError(w, http.StatusNotFound, "lesson not found")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, lesson)
}

// CreateLessonHandler handles POST /api/lesson. Requires AdminOnly middleware.
func (h *Handlers) CreateLessonHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}

	var req study.CreateLessonRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	lesson := &study.Lesson{
		Slug:        req.Slug,
		Title:       req.Title,
		Markdown:    req.Markdown,
		Excalidraw:  req.Excalidraw,
		IsPublished: req.IsPublished,
	}

	created, err := h.studySvc.CreateLesson(r.Context(), lesson)
	if err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			httputil.WriteError(w, http.StatusConflict, "slug already exists")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "failed to create lesson")
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, created)
}

// UpdateLessonHandler handles PATCH /api/lessons/{slug}. Requires AdminOnly middleware.
func (h *Handlers) UpdateLessonHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}
	slug := chi.URLParam(r, "slug")
	if slug == "" {
		httputil.WriteError(w, http.StatusBadRequest, "slug is required")
		return
	}

	var req study.UpdateLessonRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	updates := map[string]any{}
	if req.Title != "" {
		updates["title"] = req.Title
	}
	if req.Markdown != "" {
		updates["markdown"] = req.Markdown
	}
	if len(req.Excalidraw) > 0 {
		updates["excalidraw"] = req.Excalidraw
	}
	if req.IsPublished != nil {
		updates["is_published"] = *req.IsPublished
	}

	if len(updates) == 0 {
		httputil.WriteError(w, http.StatusBadRequest, "no fields to update")
		return
	}

	if err := h.studySvc.UpdateLessonBySlug(r.Context(), slug, updates); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "lesson not found")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "failed to update lesson")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, study.UpdateLessonResponse{
		Slug:    slug,
		Updated: true,
	})
}

// DeleteLessonHandler handles DELETE /api/lessons/{slug}. Requires AdminOnly middleware.
func (h *Handlers) DeleteLessonHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}
	slug := chi.URLParam(r, "slug")
	if slug == "" {
		httputil.WriteError(w, http.StatusBadRequest, "slug is required")
		return
	}

	if err := h.studySvc.DeleteLessonBySlug(r.Context(), slug); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			httputil.WriteError(w, http.StatusNotFound, "lesson not found")
			return
		}
		httputil.WriteError(w, http.StatusInternalServerError, "failed to delete lesson")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
