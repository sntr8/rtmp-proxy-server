FROM registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-base:devel

ENV PROXY_ONLY false

COPY templates/nginx.conf /etc/nginx/nginx.conf.template

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
