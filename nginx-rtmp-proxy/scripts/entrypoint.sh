#!/bin/bash
set -eu

envsubst '$CASTER $TWITCH_STREAM_KEY $TWITCH_PROXY' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

if $PROXY_ONLY;
then
    sed -i -E '/^\s+exec_push ffmpeg.*twitch\.tv.*$/d' /etc/nginx/nginx.conf
fi

exec "$@"
