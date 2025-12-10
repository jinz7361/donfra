APP=donfra-api
BIN_DIR=./bin
BIN_FILE=$(BIN_DIR)/$(APP)
DOCKER_COMPOSE?=docker compose

.PHONY: run build docker docker-run clean dev-up up down logs test test-coverage test-race test-verbose ci-test lint lint-fix

run:
	go run ./cmd/$(APP)

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_FILE) ./cmd/$(APP)

dev-up: build
	$(BIN_FILE)

docker:
	docker build -t $(APP):dev .

docker-run:
	docker run --rm -p 8080:8080 \
	 -e CORS_ORIGIN=http://localhost:3000 \
	 -e PASSCODE=19930115 \
	 $(APP):dev

up:
	$(DOCKER_COMPOSE) up -d --build

down:
	$(DOCKER_COMPOSE) down

logs:
	$(DOCKER_COMPOSE) logs -f api

clean:
	rm -f $(BIN_FILE)
	go clean -cache -testcache

format:
	go fmt ./...

# Testing commands
test:
	@echo "Running all tests..."
	go test ./...

test-verbose:
	@echo "Running tests with verbose output..."
	go test ./... -v

test-coverage:
	@echo "Running tests with coverage..."
	go test ./... -coverprofile=coverage.out
	@echo "\nCoverage summary:"
	go tool cover -func=coverage.out | grep total
	@echo "\nOpen coverage report in browser:"
	@echo "  go tool cover -html=coverage.out"

test-race:
	@echo "Running tests with race detector..."
	go test ./... -race

ci-test:
	@echo "Running CI test suite..."
	go test ./... -v -race -coverprofile=coverage.out
	@echo "\nCoverage report:"
	go tool cover -func=coverage.out

# Linting commands
lint:
	@echo "Running golangci-lint..."
	@which golangci-lint > /dev/null || (echo "golangci-lint not installed. Install: https://golangci-lint.run/usage/install/" && exit 1)
	golangci-lint run

lint-fix:
	@echo "Running golangci-lint with auto-fix..."
	golangci-lint run --fix
