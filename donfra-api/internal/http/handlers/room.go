package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"donfra-api/internal/domain/auth"
	"donfra-api/internal/domain/room"
	"donfra-api/internal/domain/study"
	"donfra-api/internal/pkg/httputil"
)

type Handlers struct {
	roomSvc  *room.Service
	studySvc StudyService
	auth     AuthService
}

type AuthService interface {
	Validate(tokenStr string) (*auth.Claims, error)
	IssueAdminToken(pass string) (string, error)
}

type StudyService interface {
	ListPublishedLessons(ctx context.Context) ([]study.Lesson, error)
	ListAllLessons(ctx context.Context) ([]study.Lesson, error)
	GetLessonBySlug(ctx context.Context, slug string) (*study.Lesson, error)
	CreateLesson(ctx context.Context, lesson *study.Lesson) (*study.Lesson, error)
	UpdateLessonBySlug(ctx context.Context, slug string, updates map[string]any) error
	DeleteLessonBySlug(ctx context.Context, slug string) error
}

func New(roomSvc *room.Service, studySvc StudyService, auth AuthService) *Handlers {
	return &Handlers{roomSvc: roomSvc, studySvc: studySvc, auth: auth}
}

func (h *Handlers) RoomInit(w http.ResponseWriter, r *http.Request) {
	var req room.InitRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	url, token, err := h.roomSvc.Init(strings.TrimSpace(req.Passcode), req.Size)
	if err != nil {
		httputil.WriteError(w, http.StatusConflict, err.Error())
		return
	}
	httputil.WriteJSON(w, http.StatusOK, room.InitResponse{InviteURL: url, Token: token})
}

func (h *Handlers) RoomStatus(w http.ResponseWriter, r *http.Request) {
	if h.roomSvc.IsOpen() && h.roomSvc.InviteLink() == "" {
		httputil.WriteError(w, http.StatusInternalServerError, "invite link is empty while room is open")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, room.StatusResponse{
		Open:       h.roomSvc.IsOpen(),
		InviteLink: h.roomSvc.InviteLink(),
		Headcount:  h.roomSvc.Headcount(),
		Limit:      h.roomSvc.Limit(),
	})
}

func (h *Handlers) RoomJoin(w http.ResponseWriter, r *http.Request) {
	var req room.JoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	if !h.roomSvc.IsOpen() {
		httputil.WriteError(w, http.StatusConflict, "room is not open")
		return
	}

	if ok := h.roomSvc.Validate(req.Token); !ok {
		httputil.WriteError(w, http.StatusUnauthorized, "invalid token")
		return
	}

	limit := h.roomSvc.Limit()
	if h.roomSvc.Headcount() >= limit {
		httputil.WriteError(w, http.StatusForbidden, "room is full at the configured limit")
		return
	}

	http.SetCookie(w, &http.Cookie{Name: "room_access", Value: "1", Path: "/", MaxAge: 86400, SameSite: http.SameSiteLaxMode, HttpOnly: false, Secure: false})
	httputil.WriteJSON(w, http.StatusOK, room.JoinResponse{Success: true})
}

func (h *Handlers) RoomClose(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(r) {
		httputil.WriteError(w, http.StatusUnauthorized, "admin token required")
		return
	}
	if err := h.roomSvc.Close(); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "failed to close room")
		return
	}
	httputil.WriteJSON(w, http.StatusOK, room.StatusResponse{Open: h.roomSvc.IsOpen()})
}

func (h *Handlers) requireAdmin(r *http.Request) bool {
	if h.auth == nil {
		return false
	}
	// Dashboard sends Authorization: Bearer <JWT>. We parse, strip the prefix,
	// and let the auth service validate signature + expiry against the shared secret.
	authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
	if authHeader == "" {
		return false
	}
	if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
		authHeader = strings.TrimSpace(authHeader[7:])
	}
	if authHeader == "" {
		return false
	}
	claims, err := h.auth.Validate(authHeader)
	if err != nil || claims == nil {
		return false
	}
	subject, err := claims.GetSubject()
	if err != nil {
		return false
	}
	return subject == "admin"
}

func (h *Handlers) RoomUpdatePeople(w http.ResponseWriter, r *http.Request) {
	var req room.UpdateHeadcountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	if err := h.roomSvc.UpdateHeadcount(req.Headcount); err != nil {
		httputil.WriteError(w, http.StatusInternalServerError, "failed to update headcount")
		return
	}

	httputil.WriteJSON(w, http.StatusOK, room.UpdateHeadcountResponse{Headcount: req.Headcount})
}
