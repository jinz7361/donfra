SHELL := /bin/zsh

# Path to the compose file used for local development
COMPOSE_FILE ?= infra/docker-compose.local.yml

# Path to production compose file
PROD_COMPOSE_FILE ?= infra/docker-compose.yml

# UI Image Tag
UI_IMAGE_TAG ?= 1.0.4

# Allow overriding compose command (support `docker-compose` or `docker compose`)
DOCKER_COMPOSE ?= docker-compose

DC = $(DOCKER_COMPOSE) -f $(COMPOSE_FILE)
PROD = $(DOCKER_COMPOSE) -f $(PROD_COMPOSE_FILE)

.PHONY: localdev-up localdev-down localdev-restart logs ps
.PHONY: localdev-up-api localdev-down-api localdev-restart-api
.PHONY: localdev-up-ws localdev-down-ws localdev-restart-ws
.PHONY: localdev-up-db localdev-down-db localdev-restart-db
.PHONY: localdev-up-ui localdev-down-ui localdev-restart-ui
.PHONY: localdev-up-redis localdev-restart-redis localdev-logs-redis
.PHONY: prod-up prod-down prod-restart prod-logs prod-ps
.PHONY: jaeger-ui jaeger-logs jaeger-hash-password
.PHONY: k8s-setup k8s-teardown k8s-rebuild k8s-logs k8s-status k8s-portforward-db k8s-portforward-jaeger


localdev-up:
	@echo "Starting local development stack using $(COMPOSE_FILE)"
	$(DC) up -d --build

localdev-down:
	@echo "Stopping local development stack (bringing down containers)"
	$(DC) down

localdev-restart: localdev-down localdev-up

localdev-up-api:
	@echo "Starting API container"
	$(DC) up -d --build api

localdev-down-api:
	@echo "Stopping API container"
	$(DC) stop api

localdev-restart-api:
	@echo "Restarting API container"
	$(DC) stop api && $(DC) up --build -d api

localdev-up-ws:
	@echo "Starting WS container"
	$(DC) up -d --build ws

localdev-down-ws:
	@echo "Stopping WS container"
	$(DC) stop ws

localdev-restart-ws:
	@echo "Restarting WS container"
	$(DC) restart ws

localdev-up-db:
	@echo "Starting DB container"
	$(DC) up -d db

localdev-down-db:
	@echo "Stopping DB container"
	$(DC) down db -v
localdev-restart-db:
	@echo "Restarting DB container"
	$(DC) down db -v && $(DC) up --build -d db

logs:
	$(DC) logs -f --tail=200

ps:
	$(DC) ps


localdev-down-ui:
	@echo "Stopping UI container"
	$(DC) stop ui

localdev-up-ui:
	@echo "Starting UI container"
	$(DC) up -d --build ui

localdev-restart-ui: localdev-down-ui localdev-up-ui

localdev-up-redis:
	@echo "Starting Redis container"
	$(DC) up -d redis

localdev-restart-redis:
	@echo "Restarting Redis container"
	$(DC) restart redis

localdev-logs-redis:
	@echo "Viewing Redis logs"
	$(DC) logs -f redis

docker-build-ui:
	@echo "Building UI container"
	cd donfra-ui ; docker build -t doneowth/donfra-ui:$(UI_IMAGE_TAG) .

docker-push-ui:
	@echo "Pushing UI container to Docker Hub"
	cd donfra-ui ; docker push doneowth/donfra-ui:$(UI_IMAGE_TAG)

# ===== Production Commands =====

prod-up:
	@echo "Starting production stack using $(PROD_COMPOSE_FILE)"
	$(PROD) up -d --build

prod-down:
	@echo "Stopping production stack"
	$(PROD) down

prod-restart:
	@echo "Restarting production stack"
	$(PROD) restart

prod-logs:
	@echo "Viewing production logs"
	$(PROD) logs -f --tail=200

prod-ps:
	@echo "Listing production containers"
	$(PROD) ps

prod-restart-api:
	@echo "Restarting production API container"
	$(PROD) stop api && $(PROD) up --build -d api

prod-restart-caddy:
	@echo "Restarting production Caddy container"
	$(PROD) restart caddy

# ===== Jaeger Commands =====

jaeger-ui:
	@echo "Opening Jaeger UI in browser..."
	@echo "Local: http://localhost:16686"
	@echo "Production: https://donfra.dev/jaeger"

jaeger-logs:
	@echo "Viewing Jaeger logs (local dev)..."
	$(DC) logs -f jaeger

jaeger-logs-prod:
	@echo "Viewing Jaeger logs (production)..."
	$(PROD) logs -f jaeger

jaeger-hash-password:
	@echo "Generate password hash for Caddy Basic Auth:"
	@echo "Enter your password when prompted:"
	@docker run --rm -it caddy:2 caddy hash-password

# ===== Kubernetes Commands =====

k8s-setup:
	@echo "Setting up Donfra on Kind cluster..."
	cd infra/k8s && ./setup-kind.sh

k8s-teardown:
	@echo "Tearing down Kind cluster..."
	cd infra/k8s && ./teardown-kind.sh

k8s-rebuild:
	@echo "Rebuilding and reloading Docker images..."
	cd infra/k8s && ./rebuild-images.sh

k8s-logs:
	@echo "Usage: make k8s-logs SERVICE=<api|ws|ui|postgres|redis|jaeger>"
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE parameter is required"; \
		echo "Example: make k8s-logs SERVICE=api"; \
		exit 1; \
	fi
	cd infra/k8s && ./logs.sh $(SERVICE)

k8s-status:
	@echo "Checking Kubernetes cluster status..."
	@kubectl get pods -n donfra
	@echo ""
	@kubectl get services -n donfra
	@echo ""
	@kubectl get ingress -n donfra

k8s-portforward-db:
	@echo "Port forwarding PostgreSQL to localhost:5432..."
	kubectl port-forward -n donfra svc/postgres 5432:5432

k8s-portforward-jaeger:
	@echo "Port forwarding Jaeger UI to localhost:16686..."
	kubectl port-forward -n donfra svc/jaeger 16686:16686

k8s-restart-api:
	@echo "Restarting API deployment..."
	kubectl rollout restart deployment/api -n donfra

k8s-restart-ws:
	@echo "Restarting WebSocket deployment..."
	kubectl rollout restart deployment/ws -n donfra

k8s-restart-ui:
	@echo "Restarting UI deployment..."
	kubectl rollout restart deployment/ui -n donfra