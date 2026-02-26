#!/bin/sh
if [ $STREAM_DELAY -eq 0 ];
then
    envsubst '$CASTER $TWITCH_STREAM_KEY' < /opt/nginx/nginx_proxy.conf.template > /opt/nginx/nginx.conf

    if $PROXY_ONLY;
    then
        sed -i -E '/^\s+exec_push ffmpeg.*twitch\.tv.*$/d' /opt/nginx/nginx.conf
    fi
else
    envsubst '$CASTER $TWITCH_STREAM_KEY' < /opt/nginx/nginx_delayer.conf.template > /opt/nginx/nginx.conf
    envsubst < /opt/rtmp/delayer_settings.py.template > /opt/rtmp/delayer_settings.py

    sh -c "/run-delayer.sh &" &
fi

sh -c "/ffmpeg-logs-to-docker.sh" &

exec "$@"
