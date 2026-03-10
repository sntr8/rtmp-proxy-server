#!/bin/sh

until [ -f "/opt/nginx/logs/ffmpeg.log" ]
do
     sleep 5
done

echo -e "============ Start of ffmpeg log ============" >> /proc/1/fd/1
tail -f -n0 /opt/nginx/logs/ffmpeg.log >> /proc/1/fd/1
