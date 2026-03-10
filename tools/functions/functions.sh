#!/bin/bash

source /etc/profile

# Configuration constants
readonly CONTAINER_BUFFER_MINUTES=30      # Minutes before/after stream for container start/stop
readonly SHUTDOWN_WARNING_MINUTES=15      # Minutes before end to send shutdown warning

# MySQL wrapper functions to reduce code duplication
mysql_container_id() {
    docker ps -aqf "name=mysql"
}

haproxy_container_id() {
    docker ps -aqf "name=haproxy"
}

mysql_exec() {
    # Execute MySQL command with default output
    # Usage: mysql_exec "SELECT * FROM table"
    docker exec "$(mysql_container_id)" mysql --defaults-extra-file=/creds.cnf -e "$@"
}

mysql_exec_silent() {
    # Execute MySQL command with silent output (-sN)
    # Usage: mysql_exec_silent "SELECT column FROM table"
    docker exec "$(mysql_container_id)" mysql --defaults-extra-file=/creds.cnf -sN -e "$@"
}

mysql_exec_interactive() {
    # Execute MySQL command with interactive mode (-it)
    # Usage: mysql_exec_interactive "SELECT * FROM table"
    docker exec -it "$(mysql_container_id)" mysql --defaults-extra-file=/creds.cnf -e "$@"
}

strip_cr() {
    # Strip carriage return from string
    # Usage: result=$(strip_cr "$variable")
    echo "${1%$'\r'}"
}

sanitize_sql_string() {
    # Escape single quotes for SQL string literals
    # Usage: safe_value=$(sanitize_sql_string "$user_input")
    # Replaces ' with '' (SQL standard escaping)
    local input="$1"
    echo "${input//\'/\'\'}"
}

validate_alphanumeric() {
    # Validate that input contains only alphanumeric, dash, underscore
    # Usage: if validate_alphanumeric "$input"; then ...
    # Returns 0 if valid, 1 if invalid
    local input="$1"
    if [[ "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_numeric() {
    # Validate that input contains only digits
    # Usage: if validate_numeric "$input"; then ...
    # Returns 0 if valid, 1 if invalid
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

require_operation() {
    # Validate that operation parameter is provided
    # Usage: require_operation "$OPERATION"
    if [ -z "$1" ];
    then
        echo "$(basename "$0"): try '$(basename "$0") --help' for more information"
        exit 1
    fi
}

# Datetime conversion functions
# Convert datetime from EU/US formats to MySQL format
# Accepts: DD.MM.YYYY HH:MM (EU) or MM/DD/YYYY HH:MM (US)
# Returns: YYYY-MM-DD HH:MM (MySQL format) or empty string on error
convert_to_mysql_datetime() {
    local input="$1"
    local result=""

    # Try European format (DD.MM.YYYY HH:MM) - macOS
    result=$(date -j -f "%d.%m.%Y %H:%M" "$input" "+%Y-%m-%d %H:%M" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    # Try European format - Linux
    result=$(date -d "$input" "+%Y-%m-%d %H:%M" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    # Try US format (MM/DD/YYYY HH:MM) - macOS
    result=$(date -j -f "%m/%d/%Y %H:%M" "$input" "+%Y-%m-%d %H:%M" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$result"
        return 0
    fi

    # Try US format - Linux (with proper parsing)
    if [[ "$input" =~ ^([0-9]{2})/([0-9]{2})/([0-9]{4})\ ([0-9]{2}:[0-9]{2})$ ]]; then
        # Convert MM/DD/YYYY HH:MM to YYYY-MM-DD HH:MM for Linux date command
        local us_format="${BASH_REMATCH[3]}-${BASH_REMATCH[1]}-${BASH_REMATCH[2]} ${BASH_REMATCH[4]}"
        result=$(date -d "$us_format" "+%Y-%m-%d %H:%M" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$result"
            return 0
        fi
    fi

    return 1
}

# Validate datetime format (accepts both EU and US formats)
validate_datetime() {
    local input="$1"
    if convert_to_mysql_datetime "$input" >/dev/null; then
        return 0
    else
        return 1
    fi
}

db_get_caster_discord_id() {
    CASTER=$1

    if [ -z "$CASTER" ];
    then
        echo "Caster was not provided"
        return 1
    else
        ID=$(mysql_exec_silent "SELECT discord_id FROM casters WHERE nick = '$CASTER'")
        echo $(strip_cr "$ID")
    fi
}

db_get_channel_access_token() {
    CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "Channel was not provided"
        return 1
    else
        ACCESS_TOKEN=$(mysql_exec_silent "SELECT access_token FROM channels WHERE name = '$CHANNEL'")
        echo $(strip_cr "$ACCESS_TOKEN")
    fi
}

db_get_channel_client_id() {
    CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "Channel was not provided"
        return 1
    else
        CLIENT_ID=$(mysql_exec_silent "SELECT client_id FROM channels WHERE name = '$CHANNEL'")
        echo $(strip_cr "$CLIENT_ID")
    fi
}

db_get_channel_refresh_token() {
    CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "Channel was not provided"
        return 1
    else
        REFRESH_TOKEN=$(mysql_exec_silent "SELECT refresh_token FROM channels WHERE name = '$CHANNEL'")
        echo $(strip_cr "$REFRESH_TOKEN")
    fi
}

db_get_channel_port() {
    CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "Channel was not provided"
        return 1
    else
        PORT=$(mysql_exec_silent "SELECT port FROM channels WHERE name = '$CHANNEL'")
        echo $(strip_cr "$PORT")
    fi
}

db_get_caster_with_stream_id() {
    STREAM=$1

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        CASTER=$(mysql_exec_silent "SELECT c.nick FROM casters c, streams s WHERE c.id = s.caster_id AND s.id = '$STREAM'")
        echo $(strip_cr "$CASTER")
    fi
}

db_get_channel_with_stream_id() {
    STREAM=$1

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        CHANNEL=$(mysql_exec_silent "SELECT c.name FROM channels c, streams s WHERE c.id = s.channel_id AND s.id = '$STREAM'")
        echo $(strip_cr "$CHANNEL")
    fi
}

db_get_game_with_stream_id() {
    STREAM=$1

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        GAME=$(mysql_exec_silent "SELECT g.name FROM games g, streams s WHERE g.id = s.game_id AND s.id = '$STREAM'")
        echo $(strip_cr "$GAME")
    fi
}

db_get_caster_name_with_id() {
    CASTER=$1

    if [ -z "$CASTER" ];
    then
        echo "Caster ID was not provided"
        return 1
    else
        NAME=$(mysql_exec_silent "SELECT nick FROM casters WHERE id = '$CASTER'")
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

    if [ -z "$CHANNEL" ];
    then
        echo "Channel ID was not provided"
        return 1
    else
        NAME=$(mysql_exec_silent "SELECT name FROM channels WHERE id = '$CHANNEL'")
        if [ ! -z "$NAME" ];
        then
            echo $NAME
            return 0
        else
            return 1
        fi
    fi
}

db_get_cocaster_name_with_stream_id() {
  STREAM=$1

  if [ -z "$STREAM" ];
  then
      echo "Stream ID was not provided"
      return 1
  else
      COCASTER=$(mysql_exec_silent "SELECT c.nick FROM casters c, streams s WHERE c.id = s.cocaster_id AND s.id = '$STREAM'")
      echo $(strip_cr "$COCASTER")
  fi
}

db_get_proxychannel_count() {
  COUNT=$(mysql_exec_silent "SELECT count(*) FROM channels WHERE name LIKE 'only%-proxy'")
  echo $(strip_cr "$COUNT")
}

db_get_game_name_with_id() {
    GAME=$1

    if [ -z "$GAME" ];
    then
        echo "Game ID was not provided"
        return 1
    else
        NAME=$(mysql_exec_silent "SELECT name FROM games WHERE id = '$GAME'")
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
        NAME=$(mysql_exec_silent "SELECT display_name FROM games WHERE name = '$GAME'")
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

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        END_TIME=$(mysql_exec_silent "SELECT end_time FROM streams WHERE id = '$STREAM'")
        echo $(strip_cr "$END_TIME")
    fi
}

db_get_stream_start_time() {
    STREAM=$1

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        START_TIME=$(mysql_exec_silent "SELECT start_time FROM streams WHERE id = '$STREAM'")
        echo $(strip_cr "$START_TIME")
    fi
}

db_get_stream_shut_down_time() {
    STREAM=$1
    INTERVAL=$2

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        if [ -z "$INTERVAL" ];
        then
            INTERVAL="$CONTAINER_BUFFER_MINUTES"
        fi

        END_TIME=$(mysql_exec_silent "SELECT DATE_ADD(end_time, INTERVAL $INTERVAL MINUTE) FROM streams WHERE id = '$STREAM'")
        echo $(strip_cr "$END_TIME")
    fi
}

db_get_stream_title() {
    STREAM=$1

    if [ -z "$STREAM" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        TITLE=$(mysql_exec_silent "SELECT title FROM streams WHERE id = '$STREAM'")
        echo $(strip_cr "$TITLE")
    fi
}

db_is_channel_free() {
    TIME=$1
    ID=$2
    EXCLUDE=$3

    if [[ -z "$TIME" || -z "$ID" ]];
    then
        echo "Channel ID or time was not provided"
        return 1
    else
        if [ ! -z "$EXCLUDE" ];
        then
            COUNT=$(mysql_exec_silent "SELECT count(*) FROM streams WHERE STR_TO_DATE('$TIME','%d.%m.%Y %T') BETWEEN start_time AND end_time AND channel_id = '$ID' AND id != '$EXCLUDE'")
        else
            COUNT=$(mysql_exec_silent "SELECT count(*) FROM streams WHERE STR_TO_DATE('$TIME','%d.%m.%Y %T') BETWEEN start_time AND end_time AND channel_id = '$ID'")
        fi
        COUNT=$(strip_cr "$COUNT")
        if [ $COUNT -eq 0 ];
        then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

db_set_channel_access_token() {
    CHANNEL=$1
    TOKEN=$2

    if [ -z "$CHANNEL" ];
    then
        echo "A channel was not provided"
        return 1
    fi

    if [ -z "$TOKEN" ];
    then
        echo "A token was not provided"
        return 1
    fi

    if mysql_exec_silent "UPDATE channels SET access_token = '$TOKEN' WHERE name = '$CHANNEL'";
    then
        echo "A new token $TOKEN was written to database"
        return 0
    else
        return 1
    fi
}

db_stream_collides_with_another() {
    ID=$1
    START_TIME=$2
    END_TIME=$3
    EXCLUDE=$4

    if [[ -z "$START_TIME" || -z "$END_TIME" || -z "$ID" ]];
    then
        echo "Channel ID or time was not provided"
        return 1
    else
        if [ ! -z "$EXCLUDE" ];
        then
            COUNT=$(mysql_exec_silent "SELECT count(*) FROM streams WHERE (start_time BETWEEN STR_TO_DATE('$START_TIME','%d.%m.%Y %T') AND STR_TO_DATE('$END_TIME','%d.%m.%Y %T') or end_time BETWEEN STR_TO_DATE('$START_TIME','%d.%m.%Y %T') AND STR_TO_DATE('$END_TIME','%d.%m.%Y %T')) AND channel_id = '$ID' AND id != '$EXCLUDE';")
        else
            COUNT=$(mysql_exec_silent "SELECT count(*) FROM streams WHERE (start_time BETWEEN STR_TO_DATE('$START_TIME','%d.%m.%Y %T') AND STR_TO_DATE('$END_TIME','%d.%m.%Y %T') or end_time BETWEEN STR_TO_DATE('$START_TIME','%d.%m.%Y %T') AND STR_TO_DATE('$END_TIME','%d.%m.%Y %T')) AND channel_id = '$ID';")
        fi
        COUNT=$(strip_cr "$COUNT")
        if [ $COUNT -eq 0 ];
        then
          return 0
        else
          return 1
        fi
    fi
}

db_stream_exists() {
    ID=$1

    if [ -z "$ID" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        STREAMCOUNT=$(mysql_exec_silent "select count(*) from streams where id = $ID")
        STREAMCOUNT=$(strip_cr "$STREAMCOUNT")
        if [ $STREAMCOUNT -eq 0 ];
        then
            return 1
        elif [ $STREAMCOUNT -eq 1 ];
        then
            return 0
        else
            return 1
        fi
    fi
}

db_stream_is_live() {
    ID=$1

    if [ -z "$ID" ];
    then
        echo "Stream ID was not provided"
        return 1
    else
        LIVE=$(mysql_exec_silent "SELECT CASE WHEN live = true THEN 'true' ELSE 'false' END FROM streams WHERE id = '$ID'")
        LIVE=$(strip_cr "$LIVE")
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

# Validation functions - search for entities in database
search_caster() {
    local CASTER=$1

    if [ -z "$CASTER" ];
    then
        echo "[ERROR]: Caster name not provided"
        return 1
    fi

    local CASTER_FOUND=$(mysql_exec_silent "SELECT nick FROM casters WHERE nick = '$CASTER' AND internal = false")

    if [ -z "$CASTER_FOUND" ];
    then
        echo "[ERROR]: Caster '$CASTER' not found in database"
        return 1
    fi
    return 0
}

search_channel() {
    local CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "[ERROR]: Channel name not provided"
        return 1
    fi

    local CHANNEL_FOUND=$(mysql_exec_silent "SELECT name FROM channels WHERE name = '$CHANNEL'")

    if [ -z "$CHANNEL_FOUND" ];
    then
        echo "[ERROR]: Channel '$CHANNEL' not found in database"
        return 1
    fi
    return 0
}

search_game() {
    local GAME=$1

    if [ -z "$GAME" ];
    then
        echo "[ERROR]: Game name not provided"
        return 1
    fi

    local GAME_FOUND=$(mysql_exec_silent "SELECT name FROM games WHERE name = '$GAME'")

    if [ -z "$GAME_FOUND" ];
    then
        echo "[ERROR]: Game '$GAME' not found in database"
        return 1
    fi
    return 0
}

twitch_get_api_error() {
    CHANNEL=$1

    if [ -z "$CHANNEL" ];
    then
        echo "Channel was not provided"
        return 1
    fi

    if twitch_validate_access_token $CHANNEL;
    then

        BROADCASTER_ID=$(twitch_get_broadcaster_id $CHANNEL)
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

        curl -s -X GET "https://api.twitch.tv/helix/streams/key?broadcaster_id=$BROADCASTER_ID" -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID"
    else
        echo "Twitch access key is not valid"
        return 1
    fi
}

twitch_get_broadcaster_id() {
    CHANNEL_LOGIN_NAME=$1

    if twitch_validate_access_token $CHANNEL;
    then
        TWITCH_ACCESS_TOKEN=$(db_get_channel_access_token $CHANNEL)
        TWITCH_CLIENT_ID=$(db_get_channel_client_id $CHANNEL)

        curl -s -X GET "https://api.twitch.tv/helix/search/channels?query=$CHANNEL_LOGIN_NAME" -H "Authorization: Bearer $TWITCH_ACCESS_TOKEN" -H "Client-Id: $TWITCH_CLIENT_ID" |jq -r ".data[] | select(.broadcaster_login==\"$CHANNEL_LOGIN_NAME\").id"
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

    if [ -z "$CHANNEL" ];
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
