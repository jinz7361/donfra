package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"gorm.io/datatypes"
	"gorm.io/gorm"

	"donfra-api/internal/domain/study"
	"donfra-api/internal/pkg/httputil"
)

// ListLessonsHandler handles GET /api/lessons and returns published lessons.
func (h *Handlers) ListLessonsHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}

	lessons, err := h.studySvc.ListPublishedLessons(r.Context())
	if err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "failed to load lessons")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, lessons)
}

// GetLessonBySlugHandler handles GET /api/lessons/{slug} and returns the lesson with full content.
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

	httputil.WriteJSON(w, http.StatusOK, lesson)
}

// CreateLessonHandler handles POST /api/lesson. Requires AdminOnly middleware.
func (h *Handlers) CreateLessonHandler(w http.ResponseWriter, r *http.Request) {
	if h.studySvc == nil {
		httputil.WriteError(w, http.StatusInternalServerError, "study service unavailable")
		return
	}

	var req struct {
		Slug       string         `json:"slug"`
		Title      string         `json:"title"`
		Markdown   string         `json:"markdown"`
		Excalidraw datatypes.JSON `json:"excalidraw"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	lesson := &study.Lesson{
		Slug:       req.Slug,
		Title:      req.Title,
		Markdown:   req.Markdown,
		Excalidraw: req.Excalidraw,
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

	var req struct {
		Title       string         `json:"title"`
		Markdown    string         `json:"markdown"`
		Excalidraw  datatypes.JSON `json:"excalidraw"`
		IsPublished *bool          `json:"is_published"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	updates := map[string]interface{}{}
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

	httputil.WriteJSON(w, http.StatusOK, map[string]interface{}{
		"slug":    slug,
		"updated": true,
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
