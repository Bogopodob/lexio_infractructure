include .env

COMPOSE=docker compose --env-file .env -f docker-compose.yml

.PHONY: up down build restart logs ps pull config backend-shell frontend-shell postgres-shell rabbitmq-shell frontend-install frontend-dev frontend-build

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

pull:
	$(COMPOSE) pull

config:
	$(COMPOSE) config

backend-shell:
	$(COMPOSE) exec php sh

frontend-shell:
	$(COMPOSE) exec frontend sh

frontend-install:
	$(COMPOSE) exec frontend sh -c "if [ -f package.json ]; then npm install; else printf 'frontend/package.json not found\n'; fi"

frontend-dev:
	$(COMPOSE) exec frontend sh -c "if [ -f package.json ]; then npm run dev -- --host 0.0.0.0 --port 5173; else printf 'frontend/package.json not found\n'; fi"

frontend-build:
	$(COMPOSE) exec frontend sh -c "if [ -f package.json ]; then npm run build; else printf 'frontend/package.json not found\n'; fi"

postgres-shell:
	$(COMPOSE) exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

rabbitmq-shell:
	$(COMPOSE) exec rabbitmq sh
