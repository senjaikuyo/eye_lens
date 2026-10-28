FROM node:22-alpine AS assets

WORKDIR /app

COPY package.json package-lock.json .npmrc ./

RUN npm ci --no-audit --no-fund

COPY . .

RUN npm run build

FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
    curl \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    oniguruma-dev

RUN docker-php-ext-install pdo pdo_mysql bcmath

COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . /var/www/html

COPY --from=assets /app/public/build /var/www/html/public/build

RUN composer install --no-interaction --optimize-autoloader --no-dev

RUN mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views bootstrap/cache \
    && chmod -R 777 storage bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]
