package metrics

import (
	"context"
	"log"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

var (
	// HTTP Metrics
	HTTPRequestsTotal   metric.Int64Counter
	HTTPRequestDuration metric.Float64Histogram

	// Business Metrics
	LessonsCreated metric.Int64Counter
	RoomOpened     metric.Int64Counter
	RoomClosed     metric.Int64Counter
	CodeExecutions metric.Int64Counter
	RoomJoins      metric.Int64Counter
)

// InitMetrics initializes the OpenTelemetry metrics provider and instruments.
// Returns a cleanup function that should be called on shutdown.
func InitMetrics(serviceName, otlpEndpoint string) (func(context.Context) error, error) {
	// If no OTLP endpoint is configured, return no-op
	if otlpEndpoint == "" {
		log.Println("[metrics] OTLP endpoint not configured, metrics disabled")
		return func(context.Context) error { return nil }, nil
	}

	// Create OTLP HTTP exporter
	exporter, err := otlpmetrichttp.New(
		context.Background(),
		otlpmetrichttp.WithEndpoint(otlpEndpoint),
		otlpmetrichttp.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	// Create resource with service information
	res, err := resource.New(
		context.Background(),
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion("1.0.0"),
		),
	)
	if err != nil {
		return nil, err
	}

	// Create meter provider
	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exporter,
			sdkmetric.WithInterval(15*time.Second),
		)),
		sdkmetric.WithResource(res),
	)

	// Set global meter provider
	otel.SetMeterProvider(meterProvider)

	// Create meter
	meter := meterProvider.Meter("donfra-api")

	// Initialize HTTP metrics
	HTTPRequestsTotal, err = meter.Int64Counter(
		"http.server.requests.total",
		metric.WithDescription("Total number of HTTP requests"),
	)
	if err != nil {
		return nil, err
	}

	HTTPRequestDuration, err = meter.Float64Histogram(
		"http.server.request.duration",
		metric.WithDescription("HTTP request duration in seconds"),
		metric.WithUnit("s"),
	)
	if err != nil {
		return nil, err
	}

	// Initialize business metrics
	LessonsCreated, err = meter.Int64Counter(
		"lessons.created.total",
		metric.WithDescription("Total number of lessons created"),
	)
	if err != nil {
		return nil, err
	}

	RoomOpened, err = meter.Int64Counter(
		"room.opened.total",
		metric.WithDescription("Total number of times room was opened"),
	)
	if err != nil {
		return nil, err
	}

	RoomClosed, err = meter.Int64Counter(
		"room.closed.total",
		metric.WithDescription("Total number of times room was closed"),
	)
	if err != nil {
		return nil, err
	}

	CodeExecutions, err = meter.Int64Counter(
		"code.executions.total",
		metric.WithDescription("Total number of code executions"),
	)
	if err != nil {
		return nil, err
	}

	RoomJoins, err = meter.Int64Counter(
		"room.joins.total",
		metric.WithDescription("Total number of room joins"),
	)
	if err != nil {
		return nil, err
	}

	log.Printf("[metrics] Metrics initialized: %s -> %s", serviceName, otlpEndpoint)

	// Return shutdown function
	return func(ctx context.Context) error {
		ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		return meterProvider.Shutdown(ctx)
	}, nil
}
