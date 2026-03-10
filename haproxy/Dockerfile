FROM haproxy:2.4-alpine
USER root

ENV TZ="Europe/Helsinki"

COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh

RUN apk add \
    ca-certificates \
    openssl \
    rsyslog \
    certbot && \
    rm -rf /var/cache/apk/* \
    && \

    mkdir -p /etc/rsyslog.d/ && \
    touch /var/log/haproxy.log && \
    ln -sf /dev/stdout /var/log/haproxy.log \
    && \

    mkdir /opt/plugins \
    && \

    chmod +x /docker-entrypoint.sh && \
    mkdir /jail && \
    crond -b

COPY config/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY config/rsyslog.conf /etc/rsyslog.d/
COPY plugins/acme-http01.lua /opt/plugins/acme-http01.lua
COPY scripts/certbot.cron /etc/cron.d/certbot

# Store config templates for extraction
RUN mkdir -p /usr/local/etc/haproxy/templates
COPY config/haproxy.cfg /usr/local/etc/haproxy/templates/haproxy.cfg
COPY config/haproxy-rtmp.cfg /usr/local/etc/haproxy/templates/haproxy-rtmp.cfg

EXPOSE 80 443 8404 48001-48010 48101-48110

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "-f", "/usr/local/etc/haproxy/haproxy.cfg" ]
