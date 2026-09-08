FROM php:8.5-fpm

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl

# Composer: retry on flaky networks and require the binary to actually exist
# (curl dying mid-pipe must not yield a layer without composer).
RUN for i in $(seq 1 5); do \
      curl --fail --retry 5 --connect-timeout 10 -sS https://getcomposer.org/installer -o /tmp/c-installer.php \
      && php /tmp/c-installer.php -- --install-dir=/usr/local/bin --filename=composer; \
      test -x /usr/local/bin/composer && break; \
      echo "composer install attempt $i failed, retrying"; \
    done \
    && test -x /usr/local/bin/composer \
    && composer --version

RUN for i in $(seq 1 5); do \
      pecl install redis && docker-php-ext-enable redis && break; \
      echo "pecl redis attempt $i failed, retrying"; \
    done \
    && php -m | grep -qi redis

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        libzip-dev \
        libpq-dev \
        postgresql-client \
        zip \
        unzip \
        gnupg \
        librdkafka-dev \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        pgsql \
        zip \
        bcmath \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN for i in $(seq 1 5); do \
      pecl install -f rdkafka-6.0.3 && docker-php-ext-enable rdkafka && break; \
      echo "pecl rdkafka attempt $i failed, retrying"; \
    done \
    && php -m | grep -qi rdkafka

RUN for i in $(seq 1 5); do \
      pecl install xdebug && docker-php-ext-enable xdebug && break; \
      echo "pecl xdebug attempt $i failed, retrying"; \
    done \
    && php -m | grep -qi xdebug

# GD (required by phpoffice/phpspreadsheet at install time; used by imports).
# Kept last so rebuilds reuse all cached layers above.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpng-dev libjpeg-dev \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-install gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/backend

CMD ["php-fpm"]
