#!/bin/bash

source /etc/profile

db_get_caster_discord_id() {
    CASTER=$1

    if [ -z $CASTER ];
    then
        echo "Caster was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        ID=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT discord_id FROM casters WHERE nick = '$CASTER'")
        ID=${ID%$'\r'}
        echo $ID
    fi
}

db_get_channel_access_token() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        ACCESS_TOKEN=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT access_token FROM channels WHERE name = '$CHANNEL'")
        ACCESS_TOKEN=${ACCESS_TOKEN%$'\r'}
        echo $ACCESS_TOKEN
    fi
}

db_get_channel_client_id() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        CLIENT_ID=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT client_id FROM channels WHERE name = '$CHANNEL'")
        CLIENT_ID=${CLIENT_ID%$'\r'}
        echo $CLIENT_ID
    fi
}

db_get_channel_refresh_token() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        REFRESH_TOKEN=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT refresh_token FROM channels WHERE name = '$CHANNEL'")
        REFRESH_TOKEN=${REFRESH_TOKEN%$'\r'}
        echo $REFRESH_TOKEN
    fi
}

db_get_channel_port() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        PORT=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT port FROM channels WHERE name = '$CHANNEL'")
        PORT=${PORT%$'\r'}
        echo $PORT
    fi
}

db_get_caster_with_stream_id() {
    STREAM=$1

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        CASTER=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT c.nick FROM casters c, streams s WHERE c.id = s.caster_id AND s.id = '$STREAM'")
        CASTER=${CASTER%$'\r'}
        echo $CASTER
    fi
}

db_get_channel_with_stream_id() {
    STREAM=$1

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        CHANNEL=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT c.name FROM channels c, streams s WHERE c.id = s.channel_id AND s.id = '$STREAM'")
        CHANNEL=${CHANNEL%$'\r'}
        echo $CHANNEL
    fi
}

db_get_game_with_stream_id() {
    STREAM=$1

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        GAME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT g.name FROM games g, streams s WHERE g.id = s.game_id AND s.id = '$STREAM'")
        GAME=${GAME%$'\r'}
        echo $GAME
    fi
}

db_get_caster_name_with_id() {
    CASTER=$1

    if [ -z $CASTER ];
    then
        echo "Caster ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        NAME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT nick FROM casters WHERE id = '$CASTER'")
        if [ ! -z "$NAME" ];
        then
            echo $NAME
            return 0
        else
            return 1
        fi
    fi
}

db_get_channel_name_with_id() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        NAME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT name FROM channels WHERE id = '$CHANNEL'")
        if [ ! -z "$NAME" ];
        then
            echo $NAME
            return 0
        else
            return 1
        fi
    fi
}

db_get_game_name_with_id() {
    GAME=$1

    if [ -z "$GAME" ];
    then
        echo "Game ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        NAME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT name FROM games WHERE id = '$GAME'")
        if [ ! -z "$NAME" ];
        then
            echo $NAME
            return 0
        else
            return 1
        fi
    fi
}

db_get_game_display_name_with_name() {
    GAME=$1

    if [ -z "$GAME" ];
    then
        echo "Game name was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        NAME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT display_name FROM games WHERE name = '$GAME'")
        if [ ! -z "$NAME" ];
        then
            echo $NAME
            return 0
        else
            return 1
        fi
    fi
}

db_get_stream_end_time() {
    STREAM=$1

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        END_TIME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT end_time FROM streams WHERE id = '$STREAM'")
        END_TIME=${END_TIME%$'\r'}
        echo $END_TIME
    fi
}

db_get_stream_shut_down_time() {
    STREAM=$1
    INTERVAL=$2

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        if [ -z $INTERVAL ];
        then
            INTERVAL="30"
        fi

        MYSQL_CONTAINER_ID=$(mysql_container_id)
        END_TIME=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT DATE_ADD(end_time, INTERVAL $INTERVAL MINUTE) FROM streams WHERE id = '$STREAM'")
        END_TIME=${END_TIME%$'\r'}
        echo $END_TIME
    fi
}

db_get_stream_title() {
    STREAM=$1

    if [ -z $STREAM ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        TITLE=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT title FROM streams WHERE id = '$STREAM'")
        TITLE=${TITLE%$'\r'}
        echo $TITLE
    fi
}

db_set_channel_access_token() {
    CHANNEL=$1
    TOKEN=$2

    if [ -z $CHANNEL ];
    then
        echo "A channel was not provided"
        return 1
    fi

    if [ -z $TOKEN ];
    then
        echo "A token was not provided"
        return 1
    fi

    MYSQL_CONTAINER_ID=$(mysql_container_id)
    if docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "UPDATE channels SET access_token = '$TOKEN' WHERE name = '$CHANNEL'";
    then
        echo "A new token $TOKEN was written to database"
        return 0
    else
        return 1
    fi
}

db_stream_is_live() {
    ID=$1

    if [ -z "$ID" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        MYSQL_CONTAINER_ID=$(mysql_container_id)
        LIVE=$(docker exec $MYSQL_CONTAINER_ID mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT CASE WHEN live = true THEN 'true' ELSE 'false' END FROM streams WHERE id = '$ID'")
        LIVE=${LIVE%$'\r'}
        if [ ! -z "$LIVE" ];
        then
            if [ "$LIVE" = "true" ];
            then
                return 0
            else
                return 1
            fi
        else
            echo "Stream was not found with id: $ID"
            return 1
        fi
    fi
}

mysql_container_id() {
    docker ps -aqf "name=mysql"
}

search_caster() {
    CASTER=$1

    castermod --list "$CASTER" > /dev/null

    CASTER_FOUND=$?

    if [ "$CASTER_FOUND" -eq 1 ];
    then
        echo "[ERROR]: Caster $CASTER was not found from the database"
        return 1
    fi
}

search_channel() {
    CHANNEL=$1

    CONTAINER_ID=$(docker ps -aqf "name=mysql")
    CHANNEL_FOUND=$(docker exec "$CONTAINER_ID" mysql --defaults-extra-file=/creds.cnf -sN -e "SELECT name FROM channels WHERE name = '$CHANNEL'")

    if [ -z "$CHANNEL_FOUND" ];
    then
        echo "Channel $CHANNEL not found from the database"
        return 1
    fi
}

search_game() {
    GAME=$1

    gamemod --list "$GAME" > /dev/null
    GAME_FOUND=$?

    if [ $GAME_FOUND -eq 1 ];
    then
        echo "[ERROR]: Game $GAME was not found from the database"
        return 1
    fi
}

twitch_get_broadcaster_id() {
    CHANNEL_LOGIN_NAME=$1

    if twitch_validate_access_token $CHANNEL;
    then
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

        curl -s -X GET "https://api.twitch.tv/helix/search/channels?query=kanaliiga" -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID" |jq -r ".data[] | select(.broadcaster_login==\"$CHANNEL_LOGIN_NAME\").id"
    else
        echo "Twitch access key is not valid"
        return 1
    fi
}

twitch_get_game_id_with_display_name() {
    GAME_NAME=$1
    CHANNEL=$2

    if twitch_validate_access_token $CHANNEL;
    then
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

        curl -s -G https://api.twitch.tv/helix/games --data-urlencode "name=$GAME_NAME" -X GET -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID" |jq -r '.data[].id'
    else
        echo "Twitch access key is not valid"
        return 1
    fi
}

twitch_get_stream_key() {
    CHANNEL=$1

    if [ -z $CHANNEL ];
    then
        echo "Channel was not provided"
        return 1
    fi

    if twitch_validate_access_token $CHANNEL;
    then

        BROADCASTER_ID=$(twitch_get_broadcaster_id $CHANNEL)
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

        curl -s -X GET "https://api.twitch.tv/helix/streams/key?broadcaster_id=$BROADCASTER_ID" -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID" |jq -r '.data[0].stream_key'
    else
        echo "Twitch access key is not valid"
        return 1
    fi
}

twitch_refresh_tokens() {
    CHANNEL=$1

    if [ ! -z "$CHANNEL" ];
    then

        TWITCH_REFRESH_TOKEN=$(db_get_channel_refresh_token $CHANNEL)

        RESULT=$(curl -s -X GET "https://twitchtokengenerator.com/api/refresh/$TWITCH_REFRESH_TOKEN")

        RESULT_REFRESH_KEY=$(echo $RESULT |jq -r '.refresh')

        if [ "$RESULT_REFRESH_KEY" == "$TWITCH_REFRESH_TOKEN" ];
        then
            ACCESS_TOKEN=$(echo $RESULT |jq -r '.token')

            if [ ! -z "$ACCESS_TOKEN" ];
            then
                echo "Refresh succeedeed"
                db_set_channel_access_token $CHANNEL $ACCESS_TOKEN
                return 0
            else
                echo "Refresh was asked but access token was missing from the reply"
                return 1
            fi
        else
            echo "Refresh did not succeed"
            return 1
        fi
    else
        echo "A channel was not provided"
        return 1
    fi
}

twitch_update_broadcast_info() {
    CHANNEL="$1"
    GAME="$2"
    TITLE="$3"

    if twitch_validate_access_token $CHANNEL;
    then

        BROADCASTER_ID=$(twitch_get_broadcaster_id $CHANNEL)
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)
        GAME_DISPLAY_NAME=$(db_get_game_display_name_with_name $GAME)
        GAME_ID=$(twitch_get_game_id_with_display_name "$GAME_DISPLAY_NAME" $CHANNEL)

        curl -X PATCH "https://api.twitch.tv/helix/channels?broadcaster_id=$BROADCASTER_ID" -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID" -H 'Content-Type: application/json' --data-raw "{\"game_id\":\"$GAME_ID\", \"title\":\"$TITLE\", \"broadcaster_language\":\"fi\"}"
    else
        echo "Twitch access key is not valid"
        return 1
    fi
}

twitch_validate_access_token() {
    CHANNEL=$1

    if ! twitch_check_accees_token $CHANNEL;
    then
        echo "Twitch OAuth tokens are not valid, refreshing tokens"
        if twitch_refresh_tokens $CHANNEL;
        then
            if twitch_check_accees_token $CHANNEL;
            then
                echo "Refresh succeeded."
                return 0
            else
                echo "ERROR: Twitch tokens are invalid."
                discordmod tokens-invalid
                return 1
            fi
        else
            echo "ERROR: Twitch token refresh failed"
            discordmod token-refresh-failed
            return 1
        fi
    else
        return 0
    fi
}

twitch_check_accees_token() {
    TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
    TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

    RESPONSE=$(curl -s -H "Authorization: OAuth $TWITCH_ACCESS_TOKEN" https://id.twitch.tv/oauth2/validate |jq -r '.client_id')

    if [ "$RESPONSE" == "$TWITCH_CLIENT_ID" ];
    then
        return 0
    else
        return 1
    fi
}
