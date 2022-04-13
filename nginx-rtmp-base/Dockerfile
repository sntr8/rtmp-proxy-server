FROM debian:buster

ENV TZ="Europe/Helsinki"

ENV NGINX_VERSION nginx-1.21.6
ENV NGINX_RTMP_MODULE_COMMIT 23e1873aa62acb58b7881eed2a501f5bf35b82e9

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    ffmpeg \
    gcc \
    gettext-base \
    git \
    libpcre3-dev \
    libssl-dev \
    openssl \
    wget \
    zlib1g-dev \
    && \

    mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz \
    && \

    mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    git clone https://github.com/arut/nginx-rtmp-module.git . && \
    git checkout --detach ${NGINX_RTMP_MODULE_COMMIT} \
    && \

    cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --add-module=/tmp/build/nginx-rtmp-module/ && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build \
    && \

    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log \
    && \

    apt-get remove --purge -y \
            build-essential \
            ca-certificates \
            gcc \
            git \
            libpcre3-dev \
            libssl-dev \
            wget \
            zlib1g-dev \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache && \
    rm -rf /root/.cargo && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="${PATH}:/usr/local/nginx/sbin"

EXPOSE 1935
CMD ["nginx", "-g", "daemon off;"]
