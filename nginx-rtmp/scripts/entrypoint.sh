#!/bin/sh

# Determine config template based on delay mode
if [ "$STREAM_DELAY" -eq 0 ]; then
    CONFIG_TEMPLATE="/opt/nginx/nginx_proxy.conf.template"
else
    CONFIG_TEMPLATE="/opt/nginx/nginx_delayer.conf.template"
fi

# Generate base config (substitute $CASTER only)
envsubst '$CASTER' < "$CONFIG_TEMPLATE" > /opt/nginx/nginx.conf

# Remove template exec_push line (contains template variables)
sed -i '/exec_push.*\${FFMPEG_CODEC}.*\${STREAM_URL}.*\${TWITCH_STREAM_KEY}/d' /opt/nginx/nginx.conf

if [ "$PROXY_ONLY" != "true" ] && [ -n "$OUTPUTS" ]; then
    # Build all exec_push lines from OUTPUTS
    # Format: platform|stream_url|stream_key (one per line)
    echo "Configuring multi-platform outputs:"
    echo "$OUTPUTS" | while IFS='|' read -r platform stream_url stream_key; do
        if [ -n "$platform" ] && [ -n "$stream_url" ] && [ -n "$stream_key" ]; then
            echo "  - $platform -> $stream_url"

            # Build exec_push line with platform-specific log
            EXEC_LINE="            exec_push /usr/bin/ffmpeg -loglevel debug -re -rtmp_live live -i \"rtmp://127.0.0.1/\${app}/\${name}\" -codec copy -f flv ${stream_url}/${stream_key} 2>>/opt/nginx/logs/ffmpeg-${platform}.log;"

            # Append to temp file
            echo "$EXEC_LINE" >> /tmp/exec_push_lines.txt
        fi
    done

    # Insert all exec_push lines before the closing } of the application block
    if [ -f /tmp/exec_push_lines.txt ]; then
        while IFS= read -r line; do
            # Escape special characters for sed
            ESCAPED_LINE=$(echo "$line" | sed 's/[&/\]/\\&/g')
            sed -i "/application ${CASTER} {/,/^[[:space:]]*}[[:space:]]*$/ {
                /^[[:space:]]*}[[:space:]]*$/ {
                    i\\
$ESCAPED_LINE
                }
            }" /opt/nginx/nginx.conf
        done < /tmp/exec_push_lines.txt
        rm /tmp/exec_push_lines.txt
    fi
fi

# Handle delay mode
if [ "$STREAM_DELAY" -ne 0 ]; then
    envsubst < /opt/rtmp/delayer_settings.py.template > /opt/rtmp/delayer_settings.py
    /run-delayer.sh &
fi

/ffmpeg-logs-to-docker.sh &

exec "$@"
