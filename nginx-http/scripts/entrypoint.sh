#!/bin/sh
set -eu

# Substitute FQDN in nginx config
envsubst '${FQDN}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec "$@"
