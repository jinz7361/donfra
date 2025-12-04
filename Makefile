SHELL := /bin/zsh

# Path to the compose file used for local development
COMPOSE_FILE ?= infra/docker-compose.local.yml

# Allow overriding compose command (support `docker-compose` or `docker compose`)
DOCKER_COMPOSE ?= docker-compose

DC = $(DOCKER_COMPOSE) -f $(COMPOSE_FILE)

.PHONY: localdev-up localdev-down localdev-restart logs ps
.PHONY: localdev-up-api localdev-down-api localdev-restart-api
.PHONY: localdev-up-ws localdev-down-ws localdev-restart-ws
.PHONY: localdev-up-db localdev-down-db localdev-restart-db
.PHONY: localdev-up-ui localdev-down-ui localdev-restart-ui


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
	$(DC) restart api

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
	$(DC) up -d donfra-db

localdev-down-db:
	@echo "Stopping DB container"
	$(DC) stop donfra-db

localdev-restart-db:
	@echo "Restarting DB container"
	$(DC) restart donfra-db

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
