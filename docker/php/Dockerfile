FROM ubuntu:24.04

ARG PHP_VERSION=8.3
ARG QEMU_APT_PACKAGES="qemu-utils"
ARG DEBIAN_FRONTEND=noninteractive

# Install PHP and extensions from packages (no compilation)
RUN apt-get update && apt-get install -y \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-zip \
    git \
    curl \
    unzip \
    wget \
    ca-certificates \
    gnupg \
    ${QEMU_APT_PACKAGES} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PHP-FPM: listen on 9000, run in foreground
RUN sed -i 's/;daemonize = yes/daemonize = no/' /etc/php/${PHP_VERSION}/fpm/php-fpm.conf && \
    sed -i 's/listen = .*/listen = 9000/' /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Symlink php for composer/artisan
RUN ln -sf /usr/bin/php${PHP_VERSION} /usr/bin/php

# Install Node.js and npm
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "riscv64" ]; then \
        apt-get update && apt-get install -y nodejs npm && apt-get clean && rm -rf /var/lib/apt/lists/*; \
    else \
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs; \
    fi && \
    node --version && npm --version

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Stable path for PHP config (version-agnostic for volume mount)
RUN mkdir -p /etc/php-app
COPY docker/php/local.ini /etc/php-app/local.ini
RUN ln -sf /etc/php-app/local.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-local.ini

# Expose port 9000
EXPOSE 9000

RUN printf '#!/bin/sh\nexec php-fpm%s -F\n' "${PHP_VERSION}" > /usr/local/bin/php-fpm-entry.sh && chmod +x /usr/local/bin/php-fpm-entry.sh
CMD ["/usr/local/bin/php-fpm-entry.sh"]
