FROM php:fpm

ENV TZ="Europe/Helsinki"

RUN docker-php-ext-install mysqli && \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" && \
    sed -i 's/expose_php = On/expose_php = off/g' $PHP_INI_DIR/php.ini

RUN mkdir -p /usr/share/nginx/html/ads
COPY nginx-http/html /usr/share/nginx/html
