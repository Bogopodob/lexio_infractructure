# Lexio infractructure — runbook

One repo, one stack at the root: this IS the production layout used on the
VPS (`/var/www/lexio`). Dev-specific settings live in `.env.example`; real
production values live in `.env` (never committed).

## Layout (same relative shape as locally)

    /var/www/lexio/frontend
    /var/www/lexio/backend
    /var/www/lexio/infractructure   (this repo; CWD for deploy)
    /var/www/lexio/frontend-dist    (built by deploy.sh, git-ignored)

## First deploy (on the VPS)

```bash
# 0. DNS + panel SSL first: A-records app.lexio.curatio.space and
#    api.lexio.curatio.space → VPS IP, panel certs issued for BOTH
#    (*.curatio.space does NOT cover two-level names)

# 1. code
mkdir -p /var/www/lexio && cd /var/www/lexio
git clone git@github.com:Bogopodob/lexio_frontend.git frontend
git clone git@github.com:Bogopodob/lexio_backend.git backend
git clone git@github.com:Bogopodob/lexio_infractructure.git infractructure
cd infractructure

# 2. host nginx vhost (curatio files untouched)
sudo cp host-nginx-lexio.conf.example /etc/nginx/conf.d/lexio.conf
# edit cert paths inside, then:
sudo nginx -t && sudo systemctl reload nginx

# 3. deploy (add --seed on the very first deploy if languages are empty)
bash deploy.sh [--seed]
```

## What deploy.sh does

1. Fails fast if `NGINX_PORT` is taken.
2. Creates `infractructure/.env` (fresh DB password) and `backend/.env`
   (prod values) **once** — never overwrites.
3. `up -d --build`, `nginx -t`, composer install, key, migrate, caches.
4. Builds the frontend with `VITE_API_URL=https://api.lexio.curatio.space/api`
   into `/var/www/lexio/frontend-dist` (mounted ro into nginx).
5. Smoke-tests both server names + prints curatio containers before/after.

## Notes

- Container nginx publishes `NGINX_PORT` (prod = 81); the DB has no host ports.
- `MAIL_MAILER=log` by default — set real SMTP in `backend/.env` before launch.
- Rollback: `docker compose --env-file .env -f docker-compose.yml down`, remove
  the host vhost, reload nginx.
- `.env` = production secrets (gitignored). `.env.example` = local/dev reference.
```
