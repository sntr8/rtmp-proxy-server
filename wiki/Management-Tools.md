# Management Tools Reference

Complete reference for all management scripts in `tools/` directory.

## Table of Contents

- [containermod](#containermod) - Container lifecycle management
- [streammod](#streammod) - Stream scheduling
- [broadcastmod](#broadcastmod) - Broadcast management
- [channelmod](#channelmod) - Channel (platform) management
- [castermod](#castermod) - Caster management
- [gamemod](#gamemod) - Game configuration
- [haproxy_configmod](#haproxy_configmod) - HAProxy routing
- [discordmod](#discordmod) - Discord notifications
- [cron_worker.sh](#cron_workersh) - Automation worker

---

## containermod

Manage Docker containers (start, stop, restart, list).

### Usage

```bash
cd tools
./containermod [OPTIONS]
```

### Options

#### Start Containers

```bash
# Start all base containers
./containermod --start --all

# Start specific base container
./containermod --start --name <container>

# Start stream container
./containermod --start --name nginx-rtmp --caster <nick> --broadcast <broadcast> --game <game>

# Start proxy container
./containermod --start --name nginx-rtmp-proxy --caster <nick>
```

#### Stop Containers

```bash
# Stop all base containers
./containermod --stop --all

# Stop specific container
./containermod --stop --name <container>

# Stop stream container
./containermod --stop --name nginx-rtmp --caster <nick>
```

#### Restart Containers

```bash
# Restart all base containers
./containermod --restart --all

# Restart specific container
./containermod --restart --name <container>
```

#### List Containers

```bash
# List all running containers
./containermod --list

# Show detailed information
docker ps -a
```

### Examples

**Start all infrastructure:**
```bash
./containermod --start --all
```

Starts: haproxy, mysql, nginx-http, php-fpm

**Start stream for JohnDoe:**
```bash
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
```

Creates `nginx-rtmp-JohnDoe` container configured for CS:GO delay, outputting to all channels linked to `main-show` broadcast.

**Stop JohnDoe's stream:**
```bash
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

**Restart HAProxy:**
```bash
./containermod --restart --name haproxy
```

### Container Types

- **haproxy** - HAProxy routing
- **mysql** - MySQL database
- **nginx-http** - HTTP server
- **php-fpm** - PHP processor
- **nginx-rtmp** - Stream relay (dynamic)
- **nginx-rtmp-proxy** - Proxy relay (dynamic)

### Notes

- Base containers (`--all`) should always be running
- Stream containers are created/destroyed automatically by `cron_worker.sh`
- Manual container start useful for testing or emergency scenarios
- HAProxy updates automatically when stream containers start/stop

---

## streammod

Schedule and manage streams.

### Usage

```bash
cd tools
./streammod [OPTIONS]
```

### Options

#### Add Stream

```bash
# Interactive mode
./streammod --add

# Command-line mode (advanced)
./streammod --add --caster <id> --channel <id> --game <id> \
            --start "DD.MM.YYYY HH:MM" --end "DD.MM.YYYY HH:MM"
```

#### List Streams

```bash
# Upcoming streams
./streammod --upcoming

# Currently live streams
./streammod --live

# Past streams
./streammod --past

# All streams
./streammod --all
```

#### Modify Stream

```bash
# Extend end time by 1 hour
./streammod --extend <stream_id>

# Cancel scheduled stream
./streammod --cancel <stream_id>

# Update start time
./streammod --update <stream_id> --start "DD.MM.YYYY HH:MM"

# Update end time
./streammod --update <stream_id> --end "DD.MM.YYYY HH:MM"
```

### Examples

**Schedule a stream (interactive):**
```bash
./streammod --add
```

Prompts:
1. Select caster
2. Select channel (or cocaster)
3. Select game
4. Enter start time (DD.MM.YYYY HH:MM or MM/DD/YYYY HH:MM)
5. Enter end time

**View upcoming streams:**
```bash
./streammod --upcoming
```

Output:
```
ID  | Caster   | Channel      | Game  | Start            | End              | Status
----+----------+--------------+-------+------------------+------------------+--------
15  | JohnDoe  | mainchannel  | CSGO  | 10.03.2026 18:00 | 10.03.2026 22:00 | Scheduled
16  | JaneDoe  | secondchannel| LOL   | 10.03.2026 19:00 | 10.03.2026 23:00 | Scheduled
```

**Extend a stream:**
```bash
./streammod --extend 15
```

Extends end time by 1 hour (18:00-22:00 becomes 18:00-23:00).

**Cancel a stream:**
```bash
./streammod --cancel 15
```

Removes schedule and prevents container startup.

### Date Format

Supports both formats:
- **European:** DD.MM.YYYY HH:MM (e.g., 10.03.2026 18:00)
- **US:** MM/DD/YYYY HH:MM (e.g., 03/10/2026 18:00)

Times are in server local timezone.

### Container Timing

- **Start:** 30 minutes before scheduled time
- **Stop:** 30 minutes after scheduled time

Example: Stream scheduled 18:00-22:00
- Container starts: 17:30
- Container stops: 22:30

### Cocaster Feature

Multiple casters can share one main channel:

1. Main caster streams to main channel (port 48001)
2. Cocaster streams to proxy channel (port 48101)
3. Main caster adds cocaster in scheduling

Allows team streams where multiple people contribute to one Twitch channel.

---

## broadcastmod

Manage broadcasts (RTMP ingress points) and their linked channels.

### Usage

```bash
cd tools
./broadcastmod [OPTIONS]
```

### Options

#### Create Broadcast

```bash
./broadcastmod --create <name> <port> [display_name]
```

#### List Broadcasts

```bash
# List all broadcasts
./broadcastmod --list

# Show specific broadcast with linked channels
./broadcastmod --list <broadcast>
```

#### Link Channel to Broadcast

```bash
./broadcastmod --link <broadcast> <channel> [priority]
```

#### Unlink Channel from Broadcast

```bash
./broadcastmod --unlink <broadcast> <channel>
```

#### Enable/Disable Channel

```bash
./broadcastmod --enable <broadcast> <channel>
./broadcastmod --disable <broadcast> <channel>
```

#### Update Broadcast

```bash
./broadcastmod --set <broadcast> <key> <value>
```

#### Remove Broadcast

```bash
./broadcastmod --remove <broadcast>
```

### Examples

**Create a broadcast:**
```bash
./broadcastmod --create main-show 48001 "Main Show"
```

**Link channels to broadcast:**
```bash
./broadcastmod --link main-show my_twitch 1
./broadcastmod --link main-show my_instagram 2
./broadcastmod --link main-show my_youtube 3
```

Now `main-show` outputs to Twitch, Instagram, and YouTube simultaneously.

**List all broadcasts:**
```bash
./broadcastmod --list
```

Output:
```
ID | Name          | Port  | Display Name | Channels
---+---------------+-------+--------------+----------
1  | main-show     | 48001 | Main Show    | 3
2  | evening-cast  | 48002 | Evening      | 2
```

**Show specific broadcast with channels:**
```bash
./broadcastmod --list main-show
```

Output:
```
Broadcast: main-show (port 48001)
Display Name: Main Show

Linked Channels:
  1. my_twitch (twitch) - enabled, priority 1
  2. my_instagram (instagram) - enabled, priority 2
  3. my_youtube (youtube) - enabled, priority 3
```

**Temporarily disable Instagram:**
```bash
./broadcastmod --disable main-show my_instagram
```

Stream continues to Twitch and YouTube, but not Instagram.

**Re-enable Instagram:**
```bash
./broadcastmod --enable main-show my_instagram
```

**Unlink a channel:**
```bash
./broadcastmod --unlink main-show my_youtube
```

**Update broadcast properties:**
```bash
./broadcastmod --set main-show display_name "Updated Main Show"
./broadcastmod --set main-show port 48005
```

**Remove broadcast:**
```bash
./broadcastmod --remove main-show
```

**Warning**: Cannot remove if active streams exist.

### Notes

- Each broadcast has a unique port (48001-48010 for regular, 48101-48110 for proxy)
- One broadcast can output to multiple channels (multi-platform streaming)
- One channel can be linked to multiple broadcasts (reusable destinations)
- Priority determines output order (lower = higher priority, optional)
- Enabled flag allows temporary disable without unlinking

---

## castermod

Manage streamers (add, remove, list).

### Usage

```bash
cd tools
./castermod [OPTIONS]
```

### Options

#### Add Caster

```bash
./castermod --add <nickname> <discord_id>
```

#### Remove Caster

```bash
./castermod --remove <nickname>
```

#### List Casters

```bash
./castermod --list
```

#### Get Connection Info

```bash
./castermod --info <nickname>
```

### Examples

**Add a caster:**
```bash
./castermod --add JohnDoe 123456789012345678
```

Output:
```
Caster added successfully!

Nickname: JohnDoe
Stream Key: JohnDoe-abc123def456
Discord ID: 123456789012345678

Connection Details:
Server: rtmp://stream.yourdomain.com:48001/JohnDoe/
Stream Key: JohnDoe-abc123def456
```

**List all casters:**
```bash
./castermod --list
```

Output:
```
ID | Nickname  | Stream Key            | Discord ID
---+-----------+-----------------------+-------------------
1  | JohnDoe   | JohnDoe-abc123def456  | 123456789012345678
2  | JaneDoe   | JaneDoe-xyz789ghi012  | 987654321098765432
```

**Remove a caster:**
```bash
./castermod --remove JohnDoe
```

**Get connection info:**
```bash
./castermod --info JohnDoe
```

Shows RTMP server and stream key.

### Notes

- Stream keys are auto-generated: `<nickname>-<random12chars>`
- Discord ID is optional but recommended for notifications
- Cannot remove caster if scheduled streams exist (cancel streams first)
- Internal users (`internal_technical_user`, `vlc_viewer`) should not be deleted

---

## channelmod

Manage platform channels (Twitch, Instagram, YouTube, Facebook) and API credentials.

### Usage

```bash
cd tools
./channelmod [OPTIONS]
```

### Options

#### Create Channel

```bash
./channelmod --create <name> <platform> <stream_url> [stream_key]
```

Platforms: `twitch`, `instagram`, `facebook`, `youtube`

#### List Channels

```bash
./channelmod --list
```

#### Update Channel Field

```bash
./channelmod --set <channel> <field> <value>
```

Fields:
- `platform` - Platform type (twitch, instagram, facebook, youtube)
- `stream_url` - Platform RTMP URL
- `stream_key` - Manual stream key
- `display_name` - Display name
- `access_token` - OAuth access token (Twitch/YouTube)
- `client_id` - OAuth client ID (Twitch/YouTube)
- `client_secret` - OAuth client secret (YouTube only)
- `refresh_token` - OAuth refresh token (Twitch/YouTube)

#### Refresh Tokens

```bash
# Refresh specific channel (Twitch/YouTube)
./channelmod --refresh-tokens <channel>
```

#### Test API Credentials

```bash
./channelmod --test-tokens <channel>
```

#### Auto-Fetch Stream Key

```bash
./channelmod --auto-fetch-key <channel>
```

For Twitch/YouTube channels with API credentials.

#### Remove Channel

```bash
./channelmod --remove <channel>
```

### Examples

**Create Twitch channel with API:**
```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"
./channelmod --set my_twitch display_name "MyTwitchChannel"
```

**Create Instagram channel:**
```bash
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_key>"
./channelmod --set my_instagram display_name "My Instagram"
```

**Create YouTube channel with API:**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2
./channelmod --set my_youtube client_id "$YOUTUBE_CLIENT_ID"
./channelmod --set my_youtube client_secret "$YOUTUBE_CLIENT_SECRET"
./channelmod --set my_youtube refresh_token "$YOUTUBE_REFRESH_TOKEN"
./channelmod --set my_youtube display_name "My YouTube"
```

**List all channels:**
```bash
./channelmod --list
```

Output:
```
Name          | Platform  | Stream URL                                      | Display Name
--------------+-----------+-------------------------------------------------+--------------
my_twitch     | twitch    | rtmp://live.twitch.tv/app                       | MyTwitchChannel
my_instagram  | instagram | rtmp://live-upload.instagram.com:80/rtmp        | My Instagram
my_youtube    | youtube   | rtmp://a.rtmp.youtube.com/live2                 | My YouTube
```

**Update stream key:**
```bash
./channelmod --set my_instagram stream_key "new_instagram_key_here"
```

**Test Twitch credentials:**
```bash
./channelmod --test-tokens my_twitch
```

**Auto-fetch Twitch stream key:**
```bash
./channelmod --auto-fetch-key my_twitch
```

**Refresh Twitch tokens:**
```bash
./channelmod --refresh-tokens my_twitch
```

**Remove channel:**
```bash
./channelmod --remove my_instagram
```

**Warning**: Cannot remove if linked to broadcasts.

### Token Management

**Twitch**: Tokens expire after ~60 days
**YouTube**: Refresh tokens don't expire, but access tokens are fetched fresh each use

**Manual refresh:**
```bash
./channelmod --refresh-tokens my_twitch
```

**Automated refresh (crontab):**
```cron
0 2 * * 0 /path/to/tools/channelmod --refresh-tokens my_twitch >> /var/log/token-refresh.log 2>&1
```

### Auto-Fetch Behavior

**At container start**, stream keys are automatically fetched for:
- **Twitch channels** with `access_token`, `client_id`, `refresh_token`
- **YouTube channels** with `client_id`, `client_secret`, `refresh_token`

Channels without API credentials use manual `stream_key` from database.

---

## gamemod

Manage games (add, remove, list).

### Usage

```bash
cd tools
./gamemod [OPTIONS]
```

### Options

#### Add Game

```bash
# Interactive mode
./gamemod --add

# Command-line mode
./gamemod --add <technical> <display_name> <abbreviation> <delay>
```

#### List Games

```bash
./gamemod --list
```

#### Remove Game

```bash
./gamemod --remove <technical_name>
```

### Examples

**Add game (interactive):**
```bash
./gamemod --add
```

Prompts for: technical name, display name, abbreviation, delay.

**Add game (command-line):**
```bash
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./gamemod --add lol "League of Legends" "LoL" 0
./gamemod --add pubg "PlayerUnknown's Battlegrounds" "PUBG" 480
```

**List all games:**
```bash
./gamemod --list
```

Output:
```
ID | Technical | Display Name                          | Abbr  | Delay
---+-----------+---------------------------------------+-------+-------
1  | csgo      | Counter-Strike: Global Offensive      | CS:GO | 480s
2  | lol       | League of Legends                     | LoL   | 0s
3  | pubg      | PlayerUnknown's Battlegrounds         | PUBG  | 480s
```

**Remove game:**
```bash
./gamemod --remove csgo
```

### Notes

- Display name must match Twitch category exactly (case-sensitive)
- Delay in seconds: 0 = instant, 480 = 8 minutes, etc.
- Cannot remove game if scheduled streams reference it

---

## haproxy_configmod

Manage HAProxy routing configuration (usually automatic).

### Usage

```bash
cd tools
./haproxy_configmod [OPTIONS]
```

### Options

#### Add Route

```bash
./haproxy_configmod --add --caster <nickname> --port <port>
```

#### Remove Route

```bash
./haproxy_configmod --remove --caster <nickname>
```

#### Reload HAProxy

```bash
./haproxy_configmod --reload
```

### Examples

**Add routing for JohnDoe:**
```bash
./haproxy_configmod --add --caster JohnDoe --port 48001
```

Adds configuration block:
```haproxy
# ::JohnDoe::start
frontend rtmp-mainchannel
    bind *:48001
    mode tcp
    default_backend JohnDoe

backend JohnDoe
    server nginx-rtmp-JohnDoe nginx-rtmp-JohnDoe:1935 check
# ::JohnDoe::end
```

**Remove routing:**
```bash
./haproxy_configmod --remove --caster JohnDoe
```

**Reload HAProxy:**
```bash
./haproxy_configmod --reload
```

Graceful reload (existing streams continue).

### Notes

- Usually called automatically by `containermod`
- Manual use for debugging or custom routing
- Always reload HAProxy after manual edits
- Markers `# ::<caster>::start` and `# ::<caster>::end` identify managed blocks

---

## discordmod

Send Discord notifications.

### Usage

```bash
cd tools
./discordmod [OPTIONS]
```

### Options

#### Send Message

```bash
./discordmod --send "<message>"
```

#### Send with Mention

```bash
./discordmod --send "<message>" --mention
```

### Examples

**Simple message:**
```bash
./discordmod --send "Stream is starting!"
```

**Message with support mention:**
```bash
./discordmod --send "Error starting container" --mention
```

Mentions the role/user defined in `$DISCORD_SUPPORT_GROUP`.

**Custom message:**
```bash
CASTER="JohnDoe"
GAME="CS:GO"
./discordmod --send "🔴 **Live:** $CASTER is streaming $GAME"
```

### Configuration

Set environment variables:

```bash
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."

# DISCORD_SUPPORT_GROUP accepts flexible formats:
export DISCORD_SUPPORT_GROUP="987654321"        # Just ID (defaults to role)
export DISCORD_SUPPORT_GROUP="&987654321"       # Role with & prefix
export DISCORD_SUPPORT_GROUP="@123456789"       # User with @ prefix
export DISCORD_SUPPORT_GROUP="<@&987654321>"    # Full Discord role syntax
export DISCORD_SUPPORT_GROUP="<@123456789>"     # Full Discord user syntax
```

### Automated Messages

Used by `cron_worker.sh` for:
- Container start notifications
- Container stop notifications
- Error alerts

### Notes

- Requires Discord webhook URL
- Support group mention is optional
- Messages support Discord markdown

---

## cron_worker.sh

Automation worker for scheduled streams (called by cron).

### Usage

```bash
cd tools
./cron_worker.sh
```

### What It Does

1. **Check scheduled streams** in database
2. **Start containers** 30 minutes before stream start time
3. **Stop containers** 30 minutes after stream end time
4. **Send Discord notifications** for events
5. **Log activity** to stdout

### Cron Setup

```bash
sudo crontab -e
```

Add line:
```cron
*/5 * * * * source /etc/profile.d/stream.sh && /path/to/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

Runs every 5 minutes.

### Behavior

**Stream scheduled 18:00-22:00:**
- 17:30: Container starts, Discord notification sent
- 18:00: Streamer can begin
- 22:00: Stream ends
- 22:30: Container stops, Discord notification sent

### Logs

```bash
# View recent activity
tail -f /var/log/stream-cron.log

# Check cron execution
grep CRON /var/log/syslog
```

### Manual Execution

For testing:
```bash
cd tools
./cron_worker.sh
```

Immediately checks and processes schedules.

### Notes

- Runs independently - no user interaction required
- Safe to run manually (idempotent - won't duplicate actions)
- Relies on database timestamps, ensure server time is correct
- Failures logged to stdout/stderr

---

## Common Workflows

### Complete Stream Setup

```bash
# 1. Add game
cd tools
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480

# 2. Create channels (platform destinations)
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"

./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_key>"

# 3. Create broadcast and link channels
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch
./broadcastmod --link main-show my_instagram

# 4. Add caster
./castermod --add JohnDoe 123456789012345678

# 5. Schedule stream
./streammod --add
# Select: JohnDoe, main-show, csgo
# Start: 10.03.2026 18:00
# End: 10.03.2026 22:00

# 6. Verify schedule
./streammod --upcoming

# 7. Wait for cron or start manually
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
```

### Emergency Stop

```bash
# Stop specific container
cd tools
./containermod --stop --name nginx-rtmp --caster JohnDoe

# Stop all stream containers
docker ps | grep nginx-rtmp | awk '{print $1}' | xargs docker stop
```

### Database Direct Access

```bash
# Query database
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e "SELECT * FROM streams"

# Interactive MySQL
docker exec -it mysql mysql --defaults-extra-file=/creds.cnf stream
```

### Bulk Operations

```bash
# List all active streams
docker ps --filter "name=nginx-rtmp-" --format "table {{.Names}}\t{{.Status}}"

# Stop all stream containers
docker stop $(docker ps -q --filter "name=nginx-rtmp-")

# Remove all stopped containers
docker container prune -f
```

---

[Back to Wiki Home](Home)
