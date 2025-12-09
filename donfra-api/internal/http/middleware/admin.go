package middleware

import (
	"context"
	"net/http"
	"strings"

	"donfra-api/internal/domain/auth"
)

type contextKey string

const IsAdminContextKey contextKey = "is_admin"

type TokenValidator interface {
	Validate(tokenStr string) (*auth.Claims, error)
}

// AdminOnly validates the Authorization Bearer token and ensures subject is "admin".
func AdminOnly(authSvc TokenValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if authSvc == nil {
				http.Error(w, "auth unavailable", http.StatusInternalServerError)
				return
			}
			authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
			if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
				authHeader = strings.TrimSpace(authHeader[7:])
			}
			if authHeader == "" {
				http.Error(w, "no auth header unauthorized", http.StatusUnauthorized)
				return
			}
			claims, err := authSvc.Validate(authHeader)
			if err != nil || claims == nil {
				http.Error(w, err.Error(), http.StatusUnauthorized)
				return
			}
			subject, err := claims.GetSubject()
			if err != nil || subject != "admin" {
				http.Error(w, err.Error(), http.StatusUnauthorized)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// OptionalAdmin checks if the request has a valid admin token and sets a context flag.
// Unlike AdminOnly, this middleware does not block non-admin requests.
func OptionalAdmin(authSvc TokenValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			isAdmin := false

			if authSvc != nil {
				authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
				if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
					token := strings.TrimSpace(authHeader[7:])
					if token != "" {
						claims, err := authSvc.Validate(token)
						if err == nil && claims != nil {
							subject, _ := claims.GetSubject()
							isAdmin = (subject == "admin")
						}
					}
				}
			}

			ctx := context.WithValue(r.Context(), IsAdminContextKey, isAdmin)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// IsAdminFromContext retrieves the is_admin flag from the request context.
func IsAdminFromContext(ctx context.Context) bool {
	val := ctx.Value(IsAdminContextKey)
	if val == nil {
		return false
	}
	isAdmin, ok := val.(bool)
	return ok && isAdmin
}
