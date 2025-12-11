package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"donfra-api/internal/domain/run"
	"donfra-api/internal/pkg/httputil"
	"donfra-api/internal/pkg/metrics"
)

func (h *Handlers) RunCode(w http.ResponseWriter, r *http.Request) {
	if !h.roomSvc.IsOpen(r.Context()) {
		httputil.WriteError(w, http.StatusForbidden, "room is not open")
		return
	}
	var req run.ExecutionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Code == "" {
		httputil.WriteError(w, http.StatusBadRequest, "code cannot be empty")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	// Record metric
	if metrics.CodeExecutions != nil {
		metrics.CodeExecutions.Add(ctx, 1)
	}

	result := run.RunPython(ctx, req.Code)
	if result.Error != nil {
		if errors.Is(result.Error, context.DeadlineExceeded) {
			httputil.WriteJSON(w, http.StatusOK, run.ExecutionResponse{Stdout: result.Stdout, Stderr: "Execution timed out"})
			return
		}
		httputil.WriteJSON(w, http.StatusOK, run.ExecutionResponse{Stdout: result.Stdout, Stderr: result.Stderr})
		return
	}
	httputil.WriteJSON(w, http.StatusOK, run.ExecutionResponse{Stdout: result.Stdout, Stderr: result.Stderr})
}
