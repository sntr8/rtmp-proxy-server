#!/bin/sh

# Set platform-specific configuration (default to twitch for backward compatibility)
PLATFORM="${PLATFORM:-twitch}"

# Set FFmpeg codec parameters and stream URL based on platform
if [ "$PLATFORM" = "twitch" ]; then
    export FFMPEG_CODEC="-codec copy"
    export STREAM_URL="${STREAM_URL:-rtmp://live.twitch.tv/app}"
elif [ "$PLATFORM" = "instagram" ]; then
    export FFMPEG_CODEC="-codec copy"
    export STREAM_URL="${STREAM_URL:-rtmp://live-upload.instagram.com:80/rtmp}"
elif [ "$PLATFORM" = "facebook" ]; then
    export FFMPEG_CODEC="-codec copy"
    export STREAM_URL="${STREAM_URL:-rtmps://live-api-s.facebook.com:443/rtmp}"
elif [ "$PLATFORM" = "youtube" ]; then
    export FFMPEG_CODEC="-codec copy"
    export STREAM_URL="${STREAM_URL:-rtmp://a.rtmp.youtube.com/live2}"
else
    echo "ERROR: Unknown platform '$PLATFORM'. Supported: twitch, instagram, facebook, youtube"
    exit 1
fi

if [ "$STREAM_DELAY" -eq 0 ];
then
    envsubst '$CASTER $TWITCH_STREAM_KEY $FFMPEG_CODEC $STREAM_URL' < /opt/nginx/nginx_proxy.conf.template > /opt/nginx/nginx.conf

    if [ "$PROXY_ONLY" = "true" ];
    then
        sed -i -E '/^\s+exec_push \/usr\/bin\/ffmpeg.*$/d' /opt/nginx/nginx.conf
    fi
else
    envsubst '$CASTER $TWITCH_STREAM_KEY $FFMPEG_CODEC $STREAM_URL' < /opt/nginx/nginx_delayer.conf.template > /opt/nginx/nginx.conf
    envsubst < /opt/rtmp/delayer_settings.py.template > /opt/rtmp/delayer_settings.py

    /run-delayer.sh &
fi

/ffmpeg-logs-to-docker.sh &

exec "$@"
