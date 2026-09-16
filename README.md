<p align="center">
  <span style="font-size:52px;font-weight:900;background:linear-gradient(135deg,#5AD4B5 0%,#5B74FF 100%);-webkit-background-clip:text;background-clip:text;color:transparent;">◈ LEXIO INFRASTRUCTURE</span>
  <br/>
  <span style="font-size:20px;color:#94a3b8;">Здесь живёт весь стек Lexio — dev и prod, одной командой</span>
</p>

<p align="center">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Compose-5ad4b5?style=for-the-badge&logo=docker&logoColor=white&labelColor=0f0f0f">
  <img alt="Nginx" src="https://img.shields.io/badge/Nginx-1.27-5b74ff?style=for-the-badge&logo=nginx&logoColor=white&labelColor=0f0f0f">
  <img alt="Postgres" src="https://img.shields.io/badge/PostgreSQL-17-5ad4b5?style=for-the-badge&logo=postgresql&logoColor=white&labelColor=0f0f0f">
  <img alt="PHP" src="https://img.shields.io/badge/PHP-fpm-5b74ff?style=for-the-badge&logo=php&logoColor=white&labelColor=0f0f0f">
</p>

> Один репозиторий = одна команда = весь Lexio. Управляйте dev-стеком через `make`, продакшеном — через `deploy.sh`. Никаких конфликтов с соседними проектами: свой проект `lexio-prod`, своя сеть `lexio_network`, свой порт 81.

---

## 🏗️ Архитектура

```
Browser → Host nginx (80/443, TLS) → upstream 127.0.0.1:${NGINX_PORT}
                                        │
                                        ▼
                          ┌────────  Docker  ─────────┐
                          │  nginx:${NGINX_PORT}        │
                          │   ├  /      → frontend-dist │
                          │   └  /api/  → php-fpm       │
                          │  php (Laravel 13)           │
                          │  postgres 17 (healthcheck)  │
                          │  rabbitmq 4* / vite dev*    │
                          └─────────────────────────────┘
              * только в dev-стеке (docker-compose.dev.yml)
```

## 📂 Раскладка

| Путь (на VPS: `/var/www/lexio/...`) | Что это |
|---|---|
| `frontend/` | React SPA — [lexio_frontend](https://github.com/Bogopodob/lexio_frontend) |
| `backend/` | Laravel API — [lexio_backend](https://github.com/Bogopodob/lexio_backend) |
| `infractructure/` | **этот репозиторий** — compose, make, deploy (CWD для запуска) |
| `frontend-dist/` | прод-сборка фронтенда (git-ignored, монтируется в nginx) |

---

## 👨‍💻 Dev-стек (`make up`)

Поднимает всё, чего нет в проде: vite-фронтенд, rabbitmq, открытый порт БД и xdebug.

| Сервис | Контейнер | Порт | Назначение |
|---|---|---|---|
| php | `lexio_php` | — + Xdebug 9003 | Laravel API |
| frontend | `lexio_frontend` | 5173 | vite dev-server |
| nginx | `lexio_nginx` | 8080 → 80 | прокси `/` и `/api/` |
| postgres | `lexio_postgres` | 5432 | БД (healthcheck) |
| rabbitmq | `lexio_rabbitmq` | 5672 / 15672 | очереди + management UI |

### Makefile — шпаргалка

| Команда | Что делает |
|---|---|
| `make up` | поднять dev-стек (`.env.example` + `docker-compose.dev.yml`) |
| `make down` · `make logs` · `make ps` · `make restart` | управление стеком |
| `make backend-shell` | шелл в `lexio_php` → `php artisan ...` |
| `make frontend-shell` | шелл в `lexio_frontend` |
| `make frontend-install` / `frontend-dev` / `frontend-build` | npm-команды внутри контейнера |
| `make postgres-shell` | `psql -U lexio` внутри контейнера |
| `make rabbitmq-shell` | шелл в rabbitmq |
| `make *-prod` | то же самое, но против прод-стека (`.env`) |

```bash
git clone git@github.com:Bogopodob/lexio_infractructure.git
cd infractructure
make up
# → http://localhost:5173  (frontend, HMR)
# → http://localhost:8080  (nginx: / и /api/)
# → http://localhost:15672 (rabbitmq: lexio/lexio)
```

> ⚠️ Если контейнеры со старыми именами `lexio_*` и сеть `lexio_network` остались от другого проекта — сначала `docker compose down`, затем удалите их (`docker rm -f`, `docker network rm lexio_network`) и только потом `make up`.

## 🌍 Прод-стек (`docker-compose.yml`)

Только `php + nginx + postgres`. Это ровно то, что задеплоено на VPS в `/var/www/lexio` (проект `lexio-prod`, сеть `lexio_network`, порт 81; БД без внешних портов, TLS на хостовом nginx).

### Один раз на сервере (первый деплой)

```bash
# 0. DNS + SSL: A-записи app.lexio.curatio.space и api.lexio.curatio.space → IP
#    сертификаты — для ОБОИХ имён (*.curatio.space не покрывает двухуровневые)

# 1. код
mkdir -p /var/www/lexio && cd /var/www/lexio
git clone git@github.com:Bogopodob/lexio_frontend.git frontend
git clone git@github.com:Bogopodob/lexio_backend.git    backend
git clone git@github.com:Bogopodob/lexio_infractructure.git infractructure
cd infractructure

# 2. виртуальный хост
sudo cp host-nginx-lexio.conf.example /etc/nginx/conf.d/lexio.conf
# → отредактировать пути к сертификатам, затем:
sudo nginx -t && sudo systemctl reload nginx

# 3. деплой (добавьте --seed при первом запуске, если languages пусты)
bash deploy.sh [--seed]
```

### Что делает `deploy.sh` (идемпотентен, безопасно перезапускать)

1. 🚫 Падает сразу, если порт `NGINX_PORT` занят чужим процессом (curatio владеет 8080);
2. 🔐 Создаёт `infractructure/.env` со свежим паролем БД и `backend/.env` (prod-значения) — **один раз**, никогда не перезаписывает;
3. ⬆️ `up -d --build`, `nginx -t`, `composer install --no-dev`, `key:generate`, `migrate`, caches;
4. 🏗️ Собирает фронтенд с `VITE_API_URL=https://api.lexio.curatio.space/api` в `frontend-dist`;
5. 🧪 Smoke-тестирует оба имени (`app.` и `api.`) и сверяет curatio-контейнеры до/после (регресс-проверка).

```bash
# Деплой по команде (после правок — просто перезапустите)
bash deploy.sh
```

## 🔧 Переменные окружения

| Файл | Смысл |
|---|---|
| `.env.example` | **dev-эталон**, все переменные с локальными значениями (`COMPOSE_PROJECT_NAME=lexio`, `NGINX_PORT=8080`, слабый пароль БД) |
| `.env` | **прод-секреты** (gitignored): проект `lexio-prod`, порт 81, пароль postgres, `APP_HOST` / `API_HOST` |

Ключевые переменные стека: `NGINX_PORT`, `POSTGRES_PASSWORD`, `APP_UID`/`APP_GID` (права файлов), `XDEBUG_MODE` (dev-стек), `APP_HOST`/`API_HOST` (зашиваются в прод-сборку фронта).

## 🧰 Сервисные команды

```bash
# прод-консоли вручную (без deploy)
make backend-shell-prod       # php artisan ...
make postgres-shell-prod      # psql
make rabbitmq-shell-prod      # bash в rabbitmq

# rollback прода
docker compose --env-file .env -f docker-compose.yml down
# + удалить хостовый vhost /etc/nginx/conf.d/lexio.conf + reload nginx
```

---

<p align="center">
  <span style="color:#5ad4b5;">◈</span> <span style="color:#94a3b8;">Infrastructure — связующее звено между красивым фронтом и умным бэком</span>
</p>