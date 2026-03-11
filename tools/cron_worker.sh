#!/bin/bash
SOURCE_DIR="$(dirname "$0")"

source "$SOURCE_DIR/functions/functions.sh"
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
    BROADCAST=$(db_get_channel_with_stream_id $ID)
    COCASTER=$(db_get_cocaster_name_with_stream_id $ID)
    PROXYOPT=""
    echo "[$ID]: Cocaster: $COCASTER"

    if [[ "$BROADCAST" != *-proxy ]];
    then
        GAME=$(db_get_game_with_stream_id $ID)
        TITLE=$(db_get_stream_title $ID)
    fi

    if [[ "$BROADCAST" == *-proxy ]];
    then
        PROXYOPT="--proxy"
    fi

    if MESSAGE=$(containermod --start --name nginx-rtmp --caster $CASTER --broadcast $BROADCAST --game $GAME $PROXYOPT;)
    then
        echo "[$ID] Container started"

        if [[ "$BROADCAST" != *-proxy ]];
        then
            twitch_update_broadcast_info $BROADCAST "$GAME" "$TITLE"
            echo "[$ID] Twitch title and game updated"
        fi

        discordmod startup $ID
        echo "[$ID] Sent startup to Discord"

        streammod --set live $ID
        echo "[$ID] Set to live"

        if [ ! -z "$COCASTER" ];
        then
          CCPROXY="$BROADCAST-proxy"
          if MESSAGE=$(containermod --start --name nginx-rtmp --caster $COCASTER --broadcast $CCPROXY --proxy;)
          then
            echo "[$ID] Co-caster proxy started for $COCASTER"

            discordmod startup_cc $ID
            echo "[$ID] Sent co-caster startup to Discord"
          else
            echo "[$ID] Co-caster container startup failed"
            echo "[$ID] $MESSAGE"
            discordmod startup-failed_cc $ID "$MESSAGE"
          fi
        else
          echo "[$ID] No co-caster was defined, skipping proxy creation."
        fi
    else
        echo "[$ID] Container startup failed"
        echo "[$ID] $MESSAGE"
        streammod --skip $ID
        discordmod startup-failed $ID "$MESSAGE"
    fi
    echo "[$ID] Finished processing"
done

echo "Getting warnings"
streammod --warnings $SHUTDOWN_WARNING_MINUTES | while read ID;
do
    ID=${ID%$'\r'}
    echo "[$ID] Staring processing"
    COCASTER=$(db_get_cocaster_name_with_stream_id $ID)

    discordmod shutdown-warning $ID
    echo "[$ID] Sent shutdown-warning to Discord"

    if [ ! -z "$COCASTER" ];
    then
      discordmod shutdown-warning_cc $ID
      echo "[$ID] Sent shutdown-warning_cc to Discord"
    else
      echo "[$ID] No co-caster defined, skipping warning"
    fi
    echo "[$ID] Finished processing"
done

echo "Getting shutdowns"
streammod --ended $CONTAINER_BUFFER_MINUTES | while read ID;
do
    ID=${ID%$'\r'}
    echo "[$ID] Staring processing"
    CASTER=$(db_get_caster_with_stream_id $ID)
    BROADCAST=$(db_get_channel_with_stream_id $ID)
    COCASTER=$(db_get_cocaster_name_with_stream_id $ID)
    PROXYOPT=""

    if [[ "$BROADCAST" == *-proxy ]];
    then
        PROXYOPT="--proxy"
    fi

    if MESSAGE=$(containermod --stop --name nginx-rtmp --caster $CASTER $PROXYOPT;)
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

    if [ ! -z "$COCASTER" ];
    then
      if MESSAGE=$(containermod --stop --name nginx-rtmp --caster $COCASTER --proxy;)
      then
          echo "[$ID] Container stopped"
          discordmod shutdown_cc $ID
          echo "[$ID] Sent shutdown_cc to Discord"
      else
          echo "[$ID] Container stopping failed"
          echo "[$ID] $MESSAGE"
          discordmod shutdown-failed_cc $ID "$MESSAGE"
          echo "[$ID] Sent notification to Discord"
      fi
    else
      echo "[$ID] No co-caster defined, skipping co-caster proxy shutdown"
    fi

    streammod --set nonlive $ID
    echo "[$ID] Set to nonlive"
    echo "[$ID] Finished processing"
done

echo "Run end time $(date)"
