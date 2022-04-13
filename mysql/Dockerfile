FROM mysql:8.0
ENV TZ="Europe/Helsinki"

RUN apt-get update && apt-get install -y \
    gettext-base  && \
    rm -rf /var/lib/apt/lists/*

COPY conf/ /etc/mysql/conf.d/
COPY templates/creds.cnf /creds.cnf.template

COPY db/create/stream_mysql_create.sql /docker-entrypoint-initdb.d/
COPY db /opt/db

RUN echo "envsubst < /creds.cnf.template > /creds.cnf" >> /entrypoint.sh
