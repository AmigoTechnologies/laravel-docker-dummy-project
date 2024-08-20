# Accepted values: 8.3 - 8.2
ARG PHP_VERSION=8.3

FROM composer:latest AS composer

FROM php:${PHP_VERSION}-cli-alpine AS base

# Install dependencies and PHP extensions in one layer
RUN apk update && apk upgrade && \
    apk add --no-cache \
    curl wget nano git ncdu procps ca-certificates supervisor libsodium-dev && \
    curl -sSLf \
    -o /usr/local/bin/install-php-extensions \
    https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions \
    bz2 pcntl mbstring bcmath sockets pgsql pdo_pgsql opcache exif \
    pdo_mysql zip intl gd redis rdkafka memcached igbinary ldap swoole mongodb && \
    docker-php-source delete && \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Set up Supercronic for cron jobs
RUN wget -q "https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-amd64" \
    -O /usr/bin/supercronic && \
    chmod +x /usr/bin/supercronic && \
    mkdir -p /etc/supercronic

# Set up environment
ENV TERM=xterm-color \
    ROOT=/var/www/html \
    COMPOSER_FUND=0 \
    COMPOSER_MAX_PARALLEL_HTTP=24

WORKDIR ${ROOT}

# Set up user
ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG USER=octane

RUN addgroup -g ${WWWGROUP} ${USER} && \
    adduser -D -h ${ROOT} -G ${USER} -u ${WWWUSER} -s /bin/sh ${USER} && \
    mkdir -p /var/log/supervisor /var/run/supervisor && \
    chown -R ${USER}:${USER} ${ROOT} /var/log /var/run && \
    chmod -R a+rw ${ROOT} /var/log /var/run

# Copy PHP configuration
COPY --chown=${USER}:${USER} deployment/php.ini ${PHP_INI_DIR}/conf.d/99-octane.ini

# Copy Composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Copy application files
COPY --chown=${USER}:${USER} . .

# Install Composer dependencies
RUN composer install --no-dev --no-interaction --no-autoloader --no-ansi --no-scripts --audit && \
    composer install --classmap-authoritative --no-interaction --no-ansi --no-dev && \
    composer clear-cache

# Set up Laravel storage and cache
RUN mkdir -p \
    storage/framework/sessions \
    storage/framework/views \
    storage/framework/cache \
    storage/framework/testing \
    storage/logs \
    bootstrap/cache && \
    chmod -R a+rw storage

# Copy configuration files
COPY --chown=${USER}:${USER} deployment/supervisord.conf /etc/supervisor/
COPY --chown=${USER}:${USER} deployment/octane/Swoole/supervisord.swoole.conf /etc/supervisor/conf.d/
COPY --chown=${USER}:${USER} deployment/supervisord.*.conf /etc/supervisor/conf.d/
COPY --chown=${USER}:${USER} deployment/start-container /usr/local/bin/start-container

# Create the supercronic file and set permissions before switching user
RUN chmod +x /usr/local/bin/start-container && \
    echo "*/1 * * * * php ${ROOT}/artisan schedule:run --no-interaction" > /etc/supercronic/laravel && \
    chown ${USER}:${USER} /etc/supercronic/laravel

# Switch to non-root user
USER ${USER}

# Append utilities to bashrc
RUN cat deployment/utilities.sh >> ~/.bashrc

EXPOSE 8000

ENTRYPOINT ["start-container"]

HEALTHCHECK --start-period=5s --interval=2s --timeout=5s --retries=8 CMD php artisan octane:status || exit 1
