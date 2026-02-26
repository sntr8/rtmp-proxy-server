FROM nginx:1.23.3-alpine
ENV TZ="Europe/Helsinki"

COPY html /usr/share/nginx/html
COPY conf /etc/nginx
COPY scripts/entrypoint.sh /entrypoint.sh

RUN rm /etc/nginx/conf.d/default.conf && \
    apk add \
    jq \
    busybox-openrc && \
    rm -rf /var/cache/apk/* && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
