# Lexio infractructure — Makefile
#
#   make up                    start local DEV stack (docker-compose.dev.yml)
#   make frontend-shell        shell into the vite frontend container
#   make backend-shell         shell into the php backend container
#   make rabbitmq-shell        shell into rabbitmq
#   make postgres-shell        psql into postgres
#   make frontend-install      npm install in the frontend container
#   make frontend-dev          run vite dev server inside the frontend container
#   make frontend-build        npm run build in the frontend container
#
#   make ps / logs / down / restart  ...
#
# PROD targets (docker-compose.yml, real .env) are handled by deploy.sh on the
# VPS; a few *-prod helpers exist for manual console access.

DEV_ENV  = .env.example
PROD_ENV = .env

COMPOSE_DEV  = docker compose --env-file $(DEV_ENV) -f docker-compose.dev.yml
COMPOSE_PROD = docker compose --env-file $(PROD_ENV) -f docker-compose.yml

.PHONY: up down build restart logs ps pull config \
	backend-shell frontend-shell postgres-shell rabbitmq-shell \
	frontend-install frontend-dev frontend-build \
	backend-shell-prod postgres-shell-prod rabbitmq-shell-prod

up:
	$(COMPOSE_DEV) up -d --build

down:
	$(COMPOSE_DEV) down

build:
	$(COMPOSE_DEV) build

restart:
	$(COMPOSE_DEV) restart

logs:
	$(COMPOSE_DEV) logs -f

ps:
	$(COMPOSE_DEV) ps

pull:
	$(COMPOSE_DEV) pull

config:
	$(COMPOSE_DEV) config

backend-shell:
	$(COMPOSE_DEV) exec php sh

frontend-shell:
	$(COMPOSE_DEV) exec frontend sh

frontend-install:
	$(COMPOSE_DEV) exec frontend sh -c "if [ -f package.json ]; then npm install; else printf 'frontend/package.json not found\n'; fi"

frontend-dev:
	$(COMPOSE_DEV) exec frontend sh -c "if [ -f package.json ]; then npm run dev -- --host 0.0.0.0 --port 5173; else printf 'frontend/package.json not found\n'; fi"

frontend-build:
	$(COMPOSE_DEV) exec frontend sh -c "if [ -f package.json ]; then npm run build; else printf 'frontend/package.json not found\n'; fi"

postgres-shell:
	$(COMPOSE_DEV) exec postgres sh -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB'

rabbitmq-shell:
	$(COMPOSE_DEV) exec rabbitmq sh

backend-shell-prod:
	$(COMPOSE_PROD) exec php sh

postgres-shell-prod:
	$(COMPOSE_PROD) exec postgres sh -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB'

rabbitmq-shell-prod:
	$(COMPOSE_PROD) exec rabbitmq sh