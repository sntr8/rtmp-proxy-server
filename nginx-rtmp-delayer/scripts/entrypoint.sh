#!/bin/bash
set -eu

envsubst '$CASTER $TWITCH_STREAM_KEY' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
envsubst < /opt/rtmp/delayer_settings.py.template > /opt/rtmp/delayer_settings.py

sh -c "/run-delayer.sh &" &

exec "$@"
