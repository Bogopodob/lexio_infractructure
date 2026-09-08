#!/usr/bin/env bash
# Lexio PROD deploy (VPS). Idempotent: safe to re-run.
# Run from /var/www/lexio/infractructure. Never touches curatio.
set -euo pipefail

ROOT=/var/www/lexio
INFRA=$ROOT/infractructure
COMPOSE="docker compose --env-file $INFRA/.env -f $INFRA/docker-compose.yml"

need() { command -v "$1" >/dev/null 2>&1 || { echo "FATAL: missing $1"; exit 1; }; }
need docker
docker compose version >/dev/null 2>&1 || { echo "FATAL: docker compose missing"; exit 1; }

# --- 0. layout -------------------------------------------------------------
for d in frontend backend infractructure; do
  [ -d "$ROOT/$d" ] || { echo "FATAL: $ROOT/$d missing (clone the 3 repos first)"; exit 1; }
done

# --- 0b. curatio snapshot (regression baseline) ------------------------------
echo "--- curatio containers BEFORE (must be identical AFTER) ---"
docker ps --format '{{.Names}} {{.Status}}' | grep -E '^curatio_' || echo "(no curatio_* containers seen)"

# --- 1. infra .env -------------------------------------------------------------
if [ ! -f "$INFRA/.env" ]; then
  cp "$INFRA/.env.example" "$INFRA/.env"
  PW=$(openssl rand -base64 24 | tr -d '\n')
  sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PW/" "$INFRA/.env"
  echo "Created $INFRA/.env with a fresh DB password."
fi
# shellcheck disable=SC1091
set -a; . "$INFRA/.env"; set +a

# --- 2. free port check (curatio owns 8080; we take NGINX_PORT) ---------------
# Allow when the port is already held by our OWN stack (idempotent re-deploy):
# only a foreign holder (e.g. curatio) is a blocker.
BOUND=$( (ss -tln 2>/dev/null || netstat -tln 2>/dev/null) | grep -E "[:.]${NGINX_PORT} " || true )
if [ -n "$BOUND" ]; then
  NGINX_CONTAINER_EXPECTED=${NGINX_CONTAINER_NAME:-lexio_nginx}
  # e.g. "80/tcp -> 0.0.0.0:81"
  if ! docker port "$NGINX_CONTAINER_EXPECTED" 2>/dev/null | grep -qE "0\.0\.0\.0:${NGINX_PORT}->|127\.0\.0\.1:${NGINX_PORT}->"; then
    echo "FATAL: host port $NGINX_PORT is taken — pick a free one in .env and retry."
    exit 1
  fi
fi

# --- 2b. collision + resources guard -------------------------------------------
if docker network ls --format '{{.Name}}' | grep -qx "lexio_network"; then
  OWNER=$(docker network inspect lexio_network --format '{{ index .Labels "com.docker.compose.project" }}' 2>/dev/null || echo "?")
  if [ "$OWNER" != "lexio-prod" ]; then
    echo "FATAL: docker network lexio_network already exists (project: $OWNER) — resolve before deploy."
    exit 1
  fi
fi
MEM_MB=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}' || echo 9999)
if [ "$MEM_MB" -lt 1500 ]; then
  echo "WARN: only ${MEM_MB}MB free RAM — 'npm ci && build' may OOM. Add swap or free memory, then re-run."
fi

# --- 3. backend .env (created once, never overwritten) ------------------------
BENV=$ROOT/backend/.env
if [ ! -f "$BENV" ]; then
  cp "$ROOT/backend/.env.example" "$BENV"
  sed -i \
    -e "s|^APP_ENV=.*|APP_ENV=production|" \
    -e "s|^APP_DEBUG=.*|APP_DEBUG=false|" \
    -e "s|^APP_URL=.*|APP_URL=https://${API_HOST}|" \
    -e "s|^DB_HOST=.*|DB_HOST=lexio_postgres|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${POSTGRES_DB}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=${POSTGRES_USER}|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${POSTGRES_PASSWORD}|" \
    -e "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=https://${APP_HOST}|" \
    "$BENV"
  grep -q "^CORS_ALLOWED_ORIGINS=" "$BENV" || echo "CORS_ALLOWED_ORIGINS=https://${APP_HOST}" >> "$BENV"
  echo "Created backend/.env — check MAIL_* before going live (default is log)."
fi

# --- 4. up --------------------------------------------------------------------
$COMPOSE up -d --build
$COMPOSE exec -T nginx nginx -t

# --- 5. backend: vendor, key, storage, migrate ---------------------------------
$COMPOSE exec -T php composer install --no-dev --optimize-autoloader --no-interaction
if ! grep -qE "^APP_KEY=.+" "$BENV"; then
  $COMPOSE exec -T php php artisan key:generate --force
fi
$COMPOSE exec -T php php artisan storage:link || true
$COMPOSE exec -T php php artisan migrate --force
$COMPOSE exec -T php php artisan config:cache
$COMPOSE exec -T php php artisan route:cache
$COMPOSE exec -T php php artisan view:cache
if [ "${1:-}" = "--seed" ]; then
  $COMPOSE exec -T php php artisan db:seed --force
else
  LANGS=$($COMPOSE exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM languages;" 2>/dev/null || echo 0)
  [ "$LANGS" -gt 0 ] || echo "WARN: languages table is empty — run with --seed on first deploy."
fi

# --- 6. frontend prod build (API URL is baked in) ------------------------------
mkdir -p "$ROOT/frontend-dist"
docker run --rm \
  -v "$ROOT/frontend:/app:ro" \
  -v "$ROOT/frontend-dist:/out" \
  -e "VITE_API_URL=https://${API_HOST}/api" \
  node:22-alpine sh -c "cd /app && npm ci --no-audit --no-fund && npm run build && cp -r dist/. /out/"
echo "Frontend built with VITE_API_URL=https://${API_HOST}/api"

# --- 7. smoke (container level; host TLS is checked separately) ----------------
curl -sf -o /dev/null -H "Host: $APP_HOST" "http://127.0.0.1:${NGINX_PORT}/" \
  && echo "SMOKE app: OK" || { echo "SMOKE app: FAIL"; exit 1; }
curl -sf -o /dev/null -H "Host: $API_HOST" "http://127.0.0.1:${NGINX_PORT}/api/" \
  && echo "SMOKE api: OK" || echo "SMOKE api: check routes (may be legit 404 on /)"

# --- 8. curatio regression ------------------------------------------------------
echo "--- curatio containers AFTER (compare with BEFORE) ---"
docker ps --format '{{.Names}} {{.Status}}' | grep -E '^curatio_' || echo "(no curatio_* containers seen)"

echo "DONE. Next: host nginx vhost (host-nginx-lexio.conf.example) + DNS + panel SSL,"
echo "then: curl https://$APP_HOST https://$API_HOST/api/"
echo "Rollback: $COMPOSE down [+ remove host vhost + nginx reload]."
