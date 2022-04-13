#!/bin/bash
SOURCE_DIR="$(dirname "$0")"

source $SOURCE_DIR/functions/functions.sh
source /etc/profile

echo "Run start time: $(date)"

echo "Getting starting streams"
streammod --starting --ids | while read ID;
do
    ID=${ID%$'\r'}
    echo "[$ID] Staring processing"
    if db_stream_is_live $ID;
    then
        echo "[$ID] Stream is already live"
        continue
    fi

    CASTER=$(db_get_caster_with_stream_id $ID)
    CHANNEL=$(db_get_channel_with_stream_id $ID)

    if [[ "$CHANNEL" != proxy-only* ]];
    then
        GAME=$(db_get_game_with_stream_id $ID)
        TITLE=$(db_get_stream_title $ID)
    fi

    if MESSAGE=$(containermod --start nginx-rtmp $CASTER $CHANNEL $GAME;)
    then
        echo "[$ID] Container started"

        if [[ "$CHANNEL" != proxy-only* ]];
        then
            twitch_update_broadcast_info $CHANNEL "$GAME" "$TITLE"
            echo "[$ID] Twitch title and game updated"
        fi

        discordmod startup $ID
        echo "[$ID] Sent startup to Discord"

        streammod --set live $ID
        echo "[$ID] Set to live"
    else
        echo "[$ID] Container startup failed"
        echo "[$ID] $MESSAGE"
        streammod --skip $ID
        discordmod startup-failed $ID "$MESSAGE"
    fi
done

echo "Getting warnings"
streammod --warnings 15 | while read ID;
do
    ID=${ID%$'\r'}
    echo "[$ID] Staring processing"
    discordmod shutdown-warning $ID
    echo "[$ID] Sent shutdown-warning to Discord"
done

echo "Getting shutdowns"
streammod --ended 30 | while read ID;
do
    ID=${ID%$'\r'}
    echo "[$ID] Staring processing"
    CASTER=$(db_get_caster_with_stream_id $ID)

    if MESSAGE=$(containermod --stop nginx-rtmp $CASTER;)
    then
        echo "[$ID] Container stopped"
        discordmod shutdown $ID
        echo "[$ID] Sent notification to Discord"
    else
        echo "[$ID] Container stopping failed"
        echo "[$ID] $MESSAGE"
        discordmod shutdown-failed $ID "$MESSAGE"
        echo "[$ID] Sent notification to Discord"
    fi
    streammod --set nonlive $ID
    echo "[$ID] Set to nonlive"
done

echo "Run end time $(date)"
