FROM nginx:1.21.6
ENV TZ="Europe/Helsinki"

RUN rm /etc/nginx/conf.d/default.conf && \
    apt-get update && apt-get install -y \
    cron  && \
    rm -rf /var/lib/apt/lists/*

COPY html /usr/share/nginx/html
COPY conf /etc/nginx
COPY scripts/logo-switcher.sh /logo-switcher.sh
COPY scripts/entrypoint.sh /entrypoint.sh
COPY cron.d/logo-switcher.cron /etc/cron.daily/logo-switcher

RUN chmod +x /logo-switcher.sh && \
    chmod +x /entrypoint.sh && \
    chmod +x /etc/cron.daily/logo-switcher && \
    find /usr/share/nginx/html/pubg-obs/img/in-game/ -name "top-ad*" -exec basename \{} \; | sort | xargs -r0 > /usr/share/nginx/html/pubg-obs/img/in-game/images.txt && \
    /etc/init.d/cron start

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
