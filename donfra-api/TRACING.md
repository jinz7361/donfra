# Jaeger Distributed Tracing

This API is instrumented with OpenTelemetry and exports traces to Jaeger for distributed tracing and performance monitoring.

## Architecture

- **OpenTelemetry SDK**: Modern, vendor-neutral telemetry standard
- **OTLP HTTP Exporter**: Sends traces to Jaeger via OpenTelemetry Protocol
- **Jaeger All-in-One**: Receives, stores, and visualizes traces

## Quick Start

### 1. Start with Docker Compose

```bash
cd infra
make localdev-up
```

This will start:
- API on `:8080`
- Jaeger UI on `:16686`
- Database on `:5432`

### 2. Access Jaeger UI

Open [http://localhost:16686](http://localhost:16686) in your browser.

### 3. Generate Some Traces

Make requests to your API:

```bash
# Get lessons
curl http://localhost:8080/api/lessons

# Get specific lesson
curl http://localhost:8080/api/lessons/intro-to-go

# Create a lesson (requires admin token)
curl -X POST http://localhost:8080/api/lessons \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"slug":"test","title":"Test","markdown":"# Test"}'
```

### 4. View Traces in Jaeger

1. Go to [http://localhost:16686](http://localhost:16686)
2. Select **Service**: `donfra-api`
3. Click **Find Traces**
4. Click on any trace to see detailed timing information

## What Gets Traced

Every HTTP request is automatically traced with:

- **Span Name**: `HTTP <METHOD> <PATH>` (e.g., "HTTP GET /api/lessons")
- **HTTP Metadata**:
  - Method (GET, POST, etc.)
  - Path
  - Status code
  - Request/response headers
- **Timing Information**:
  - Total request duration
  - Time spent in middleware
  - Database query timing (future enhancement)
- **Error Tracking**:
  - Stack traces for errors
  - HTTP error codes

## Environment Variables

### `JAEGER_ENDPOINT`

The Jaeger collector endpoint for OTLP HTTP.

- **Docker Compose**: `jaeger:4318` (already configured)
- **Local Development**: `localhost:4318`
- **Production**: Your Jaeger collector endpoint
- **Disabled**: Leave empty (`""`) to disable tracing

Examples:

```bash
# Docker Compose (default)
export JAEGER_ENDPOINT=jaeger:4318

# Local development
export JAEGER_ENDPOINT=localhost:4318

# Production
export JAEGER_ENDPOINT=jaeger.prod.example.com:4318

# Disable tracing
export JAEGER_ENDPOINT=
```

## Trace Context Propagation

This API uses W3C Trace Context for propagation:

- **Incoming requests**: Extracts `traceparent` header to continue existing traces
- **Outgoing requests**: Injects `traceparent` header for downstream services

This allows distributed tracing across multiple services.

## Production Considerations

### Sampling

Currently set to **100% sampling** (`AlwaysSample()`). For production:

```go
// In internal/pkg/tracing/tracing.go
sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))) // 10% sampling
```

### Performance

- **Overhead**: ~0.1-0.5ms per request (negligible)
- **Network**: Traces are batched and sent asynchronously
- **Storage**: Jaeger stores traces in memory by default (configure persistent storage for production)

### Security

- **Insecure mode**: Currently using `WithInsecure()` for local development
- **Production**: Use TLS:
  ```go
  otlptracehttp.WithEndpoint(jaegerEndpoint),
  otlptracehttp.WithTLSClientConfig(&tls.Config{...}),
  ```

## Jaeger Storage

The `jaegertracing/all-in-one` image uses in-memory storage by default. For production:

1. **Use Jaeger with Elasticsearch**:
   ```yaml
   jaeger:
     image: jaegertracing/jaeger-collector:latest
     environment:
       - SPAN_STORAGE_TYPE=elasticsearch
       - ES_SERVER_URLS=http://elasticsearch:9200
   ```

2. **Use Jaeger with Cassandra**:
   ```yaml
   jaeger:
     image: jaegertracing/jaeger-collector:latest
     environment:
       - SPAN_STORAGE_TYPE=cassandra
       - CASSANDRA_SERVERS=cassandra
   ```

## Troubleshooting

### Traces not appearing

1. **Check Jaeger is running**:
   ```bash
   docker ps | grep jaeger
   ```

2. **Check API logs**:
   ```bash
   docker logs donfra-api | grep tracing
   ```

3. **Verify endpoint**:
   ```bash
   curl http://localhost:4318/v1/traces
   ```

### Connection refused

- Make sure Jaeger service started before API
- Check `JAEGER_ENDPOINT` is set correctly
- Verify network connectivity: `docker network inspect donfra-local`

### High memory usage

- Reduce sampling rate
- Configure Jaeger storage limits
- Use persistent storage instead of in-memory

## Advanced Usage

### Custom Spans

Add custom spans in your code:

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
)

func MyFunction(ctx context.Context) {
    tracer := otel.Tracer("donfra-api")
    ctx, span := tracer.Start(ctx, "MyFunction")
    defer span.End()

    // Add custom attributes
    span.SetAttributes(
        attribute.String("user_id", "123"),
        attribute.Int("item_count", 42),
    )

    // Your code here
}
```

### Database Tracing

Add GORM tracing plugin (future enhancement):

```go
import "gorm.io/plugin/opentelemetry/tracing"

db.Use(tracing.NewPlugin())
```

## Metrics vs Tracing

| Feature | Metrics | Tracing |
|---------|---------|---------|
| Purpose | Aggregated statistics | Individual request details |
| Storage | Time series | Individual spans |
| Use Case | Dashboards, alerts | Debugging, performance |
| Overhead | Very low | Low |
| Example | "Avg response time: 50ms" | "This request took 120ms because..." |

## References

- [OpenTelemetry Go](https://opentelemetry.io/docs/languages/go/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)
