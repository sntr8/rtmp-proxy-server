#!/bin/bash

DAYOFWEEK=$(date '+%u')
TOURNAMENT=$(echo $TOURNAMENT_BANNER)

cd /usr/share/nginx/html/pubg-obs/img/in-game/

if [ $DAYOFWEEK -eq 3 ];
then
    if [ -f "top-banner.png" ];
    then
        rm top-banner.png
    fi
    ln -s top-banner-weekly.png top-banner.png
else
    if [ -f "top-banner.png" ];
    then
        rm top-banner.png
    fi
    ln -s top-banner-$TOURNAMENT.png top-banner.png
fi
