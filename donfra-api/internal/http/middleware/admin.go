package middleware

import (
	"net/http"
	"strings"

	"donfra-api/internal/domain/auth"
)

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
