FROM php:8.5-fpm

RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN pecl install redis \
    && docker-php-ext-enable redis

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

RUN pecl install -f rdkafka-6.0.3 \
    && docker-php-ext-enable rdkafka

RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

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
