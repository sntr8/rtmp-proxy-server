FROM alpine:3.23 AS nginx-rtmp-builder

ENV NGINX_VERSION nginx-1.28.2
ENV NGINX_RTMP_MODULE_COMMIT 23e1873aa62acb58b7881eed2a501f5bf35b82e9

RUN apk add --update-cache \
    build-base \
    git \
    openssl-dev \
    pcre-dev \
    wget \
    zlib-dev \
    && \
    \
    mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz \
    && \
    \
    mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    git clone https://github.com/arut/nginx-rtmp-module.git . && \
    git checkout --detach ${NGINX_RTMP_MODULE_COMMIT} \
    && \
    \
    cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --prefix=/opt/nginx \
        --sbin-path=/opt/nginx/sbin/nginx \
        --conf-path=/opt/nginx/nginx.conf \
        --error-log-path=/opt/nginx/logs/error.log \
        --pid-path=/opt/nginx/nginx.pid \
        --lock-path=/opt/nginx/nginx.lock \
        --http-log-path=/opt/nginx/logs/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --add-module=/tmp/build/nginx-rtmp-module/ && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

RUN mkdir -p /opt/rtmp/workdir && \
    chmod 777 /opt/rtmp/workdir

COPY rtmp_stream_delayer/stream_delayer.py /opt/rtmp/
RUN chmod +x /opt/rtmp/stream_delayer.py

FROM alpine:3.23 AS nginx-rtmp

ARG TZ=UTC
ENV TZ=${TZ}

ENV PROXY_ONLY false
ENV PATH="${PATH}:/opt/nginx/sbin"

COPY --from=nginx-rtmp-builder /opt/ /opt/
COPY scripts/run-delayer.sh scripts/ffmpeg-logs-to-docker.sh scripts/entrypoint.sh /
COPY templates/nginx_delayer.conf.template templates/nginx_proxy.conf.template /opt/nginx/
COPY templates/delayer_settings.py.template /opt/rtmp/delayer_settings.py.template

RUN apk add \
        python3-dev \
        ffmpeg \
        gettext \
        pcre-dev \
        && \
    rm -rf /var/cache/apk/* \
    && \
    \
    cd /usr/local/bin && \
    ln -s /usr/bin/python3 python \
    && \
    \
    ln -sf /dev/stdout /opt/nginx/logs/access.log && \
    ln -sf /dev/stderr /opt/nginx/logs/error.log \
    && \
    \
    chmod +x /entrypoint.sh && \
    chmod +x /run-delayer.sh && \
    chmod +x /ffmpeg-logs-to-docker.sh

EXPOSE 1935
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
