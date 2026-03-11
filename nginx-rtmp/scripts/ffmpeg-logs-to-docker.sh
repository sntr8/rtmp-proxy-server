#!/bin/sh

# Wait for at least one FFmpeg log file to exist
until ls /opt/nginx/logs/ffmpeg*.log 1> /dev/null 2>&1
do
     sleep 5
done

echo -e "============ Start of ffmpeg logs ============" >> /proc/1/fd/1

# Tail all ffmpeg logs (handles both single ffmpeg.log and platform-specific logs)
tail -f -n0 /opt/nginx/logs/ffmpeg*.log >> /proc/1/fd/1
