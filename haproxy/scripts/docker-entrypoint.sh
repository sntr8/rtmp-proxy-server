#!/bin/sh

set -o errexit
set -o nounset

readonly RSYSLOG_PID="/var/run/rsyslogd.pid"

main() {
  start_rsyslogd
  start_lb "$@"
}

start_rsyslogd() {
  rm -f $RSYSLOG_PID
  rsyslogd
}

start_lb() {
  exec haproxy -W -db "$@"
}

if [ -n "$FQDN" ];
then

    if [ ! -d /usr/local/etc/haproxy/certs ];
    then
        mkdir /usr/local/etc/haproxy/certs
    fi

    if [ "$FQDN" = "configtest" ];
    then
        echo "Generating dummy ceritificate for $FQDN"
        mkdir -p "/usr/local/etc/haproxy/certs/$FQDN"
        printf "[dn]\nCN=$FQDN\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$FQDN, DNS:$FQDN\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth" > openssl.cnf
        openssl req -newkey rsa:2048 -nodes -keyout /usr/local/etc/haproxy/certs/$FQDN.crt.key -x509 -days 1 -out /usr/local/etc/haproxy/certs/$FQDN.crt \
        -subj "/C=FI/ST=FI/L=fi/O=configtest/OU=configtest/CN=configtest/emailAddress=configtest"
        rm -f openssl.cnf
    else
    	certbot certonly --no-self-upgrade -n --text --standalone \
        --preferred-challenges http-01 \
        -d "$FQDN" --keep --expand --agree-tos --email "$ADMIN_EMAIL"

        cat /etc/letsencrypt/live/$FQDN/privkey.pem \
          /etc/letsencrypt/live/$FQDN/fullchain.pem \
          | tee /usr/local/etc/haproxy/certs/haproxy-"$FQDN".pem >/dev/null
    fi
fi

main "$@"
