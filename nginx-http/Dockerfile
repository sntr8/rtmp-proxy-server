FROM nginx:1.28-alpine
ARG TZ=UTC
ENV TZ=${TZ}

COPY html /usr/share/nginx/html
COPY conf/nginx.conf.template /etc/nginx/nginx.conf.template
COPY scripts/entrypoint.sh /entrypoint.sh

RUN rm /etc/nginx/conf.d/default.conf && \
    apk add \
    jq \
    busybox-openrc && \
    rm -rf /var/cache/apk/* && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
