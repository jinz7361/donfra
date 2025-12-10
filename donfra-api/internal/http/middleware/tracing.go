package middleware

import (
	"net/http"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// Tracing wraps the handler with OpenTelemetry HTTP instrumentation.
// This middleware automatically creates spans for each HTTP request with:
// - HTTP method, path, status code
// - Request/response headers
// - Timing information
// - Error tracking
func Tracing(serviceName string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return otelhttp.NewHandler(
			next,
			serviceName,
			otelhttp.WithSpanNameFormatter(func(operation string, r *http.Request) string {
				// Format: "HTTP GET /api/lessons"
				return "HTTP " + r.Method + " " + r.URL.Path
			}),
		)
	}
}
