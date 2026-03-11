# Management Tools Reference

Command syntax reference for all tools in `tools/` directory. For concepts and how things work, see [Architecture](Architecture).

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

Manage Docker container lifecycle. See [Architecture - Container Architecture](Architecture#container-architecture).

### Syntax

```bash
cd tools

# Start/stop/restart base infrastructure
./containermod --start|--stop|--restart --all
./containermod --start|--stop|--restart --name <container>

# Start stream container
./containermod --start --name nginx-rtmp --caster <nick> --broadcast <broadcast> --game <game>

# Stop stream container
./containermod --stop --name nginx-rtmp --caster <nick>

# List containers
./containermod --list
```

### Examples

```bash
./containermod --start --all                                                      # Start infrastructure
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo  # Start stream
./containermod --stop --name nginx-rtmp --caster JohnDoe                          # Stop stream
./containermod --restart --name haproxy                                           # Restart HAProxy
```

**Container types:** haproxy, mysql, nginx-http, php-fpm, nginx-rtmp, nginx-rtmp-proxy

---

## streammod

Schedule streams. See [Configuration - Broadcasts](Configuration#broadcasts-configuration).

### Syntax

```bash
cd tools

# Add (interactive)
./streammod --add

# List
./streammod --upcoming|--live|--past|--all

# Modify
./streammod --extend <stream_id>       # +1 hour
./streammod --cancel <stream_id>
./streammod --update <stream_id> --start|--end "DD.MM.YYYY HH:MM"
```

### Examples

```bash
./streammod --add                   # Interactive: select caster, broadcast, game, times
./streammod --upcoming              # List upcoming
./streammod --extend 15             # Extend stream 15 by 1 hour
./streammod --cancel 15             # Cancel stream 15
```

**Date formats:** `DD.MM.YYYY HH:MM` or `MM/DD/YYYY HH:MM` (server timezone)

**Container timing:** Starts 30 min before, stops 30 min after scheduled times

---

## broadcastmod

Manage broadcasts (RTMP ingress points). See [Architecture - Broadcasts](Architecture#many-to-many-broadcast-architecture).

### Syntax

```bash
cd tools

./broadcastmod --create <name> <port> [display_name]
./broadcastmod --list [broadcast]
./broadcastmod --link <broadcast> <channel> [priority]
./broadcastmod --unlink <broadcast> <channel>
./broadcastmod --enable|--disable <broadcast> <channel>
./broadcastmod --set <broadcast> <key> <value>
./broadcastmod --remove <broadcast>
```

### Examples

```bash
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch 1
./broadcastmod --link main-show my_instagram 2
./broadcastmod --list main-show                      # Show with linked channels
./broadcastmod --disable main-show my_instagram      # Temp disable (no unlink)
./broadcastmod --enable main-show my_instagram       # Re-enable
./broadcastmod --unlink main-show my_youtube         # Permanent unlink
./broadcastmod --set main-show display_name "New Name"
./broadcastmod --remove main-show
```

**Port ranges:** Regular 48001-48010, Proxy 48101-48110

---

## channelmod

Manage platform channels. See [Architecture - Channels](Architecture#many-to-many-broadcast-architecture) and [Configuration - Channels](Configuration#channels-configuration).

### Syntax

```bash
cd tools

./channelmod --create <name> <platform> <stream_url> [stream_key]
./channelmod --list
./channelmod --set <channel> <field> <value>
./channelmod --remove <channel>
./channelmod --test-tokens <channel>
./channelmod --refresh-tokens <channel>
./channelmod --auto-fetch-key <channel>
```

**Platforms:** `twitch`, `instagram`, `facebook`, `youtube`

**Fields:** `platform`, `stream_url`, `stream_key`, `display_name`, `access_token`, `client_id`, `client_secret`, `refresh_token`

### Examples

```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "<your_access_token>"
./channelmod --set my_twitch client_id "<your_client_id>"
./channelmod --set my_twitch refresh_token "<your_refresh_token>"
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_key>"
./channelmod --list
./channelmod --test-tokens my_twitch
./channelmod --auto-fetch-key my_twitch
./channelmod --refresh-tokens my_twitch
./channelmod --remove my_instagram
```

---

## castermod

Manage casters (streamers). See [Architecture - Authentication](Architecture#authentication-system).

### Syntax

```bash
cd tools

./castermod --add <nickname> <discord_id>
./castermod --list
./castermod --info <nickname>
./castermod --remove <nickname>
```

### Examples

```bash
./castermod --add JohnDoe 123456789012345678   # Generates stream key
./castermod --list
./castermod --info JohnDoe                      # Show connection details
./castermod --remove JohnDoe
```

**Stream key format:** `<nickname>-<random12chars>` (auto-generated)

**Note:** Don't delete `internal_technical_user` or `vlc_viewer` (system users)

---

## gamemod

Manage games. See [Architecture - Stream Delay](Architecture#stream-delay-implementation).

### Syntax

```bash
cd tools

./gamemod --add [<technical> <display_name> <abbreviation> <delay>]
./gamemod --list
./gamemod --remove <technical_name>
```

### Examples

```bash
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./gamemod --add lol "League of Legends" "LoL" 0
./gamemod --list
./gamemod --remove csgo
```

**Delay:** 0 = instant, 480 = 8 minutes, 300 = 5 minutes

**Note:** Display name must match Twitch category exactly

---

## haproxy_configmod

Manage HAProxy routing (usually automatic). See [Architecture - HAProxy](Architecture#haproxy-configuration-structure).

### Syntax

```bash
cd tools

./haproxy_configmod --add --caster <nickname> --port <port>
./haproxy_configmod --remove --caster <nickname>
./haproxy_configmod --reload
```

### Examples

```bash
./haproxy_configmod --add --caster JohnDoe --port 48001
./haproxy_configmod --remove --caster JohnDoe
./haproxy_configmod --reload   # Graceful reload
```

**Note:** Usually called automatically by `containermod`

---

## discordmod

Send Discord notifications. See [Configuration - Discord Notifications](Configuration#discord-notifications).

### Syntax

```bash
cd tools

./discordmod --send "<message>" [--mention]
```

### Examples

```bash
./discordmod --send "Stream is starting!"
./discordmod --send "Error starting container" --mention   # Mentions $DISCORD_SUPPORT_GROUP
```

**Configuration:** Set `$DISCORD_WEBHOOK` and optionally `$DISCORD_SUPPORT_GROUP` in `/etc/profile.d/stream.sh`

---

## cron_worker.sh

Automation worker for scheduled streams. Starts containers 30 min before, stops 30 min after.

### Usage

Automatic (via cron):
```cron
*/5 * * * * source /etc/profile.d/stream.sh && /path/to/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

Manual (testing):
```bash
cd tools
./cron_worker.sh
```

### Behavior

Stream scheduled 18:00-22:00:
- 17:30: Container starts, notification sent
- 22:30: Container stops, notification sent

**Logs:** `tail -f /var/log/stream-cron.log`

---

## Common Workflows

See [Configuration Guide](Configuration) for complete setup instructions.

### Quick Setup

```bash
cd tools
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch
./castermod --add JohnDoe 123456789012345678
./streammod --add  # Interactive: select JohnDoe, main-show, csgo, times
./streammod --upcoming
```

### Emergency Stop

```bash
./containermod --stop --name nginx-rtmp --caster JohnDoe
docker stop $(docker ps -q --filter "name=nginx-rtmp-")  # Stop all
```

### Database Access

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e "SELECT * FROM streams"
docker exec -it mysql mysql --defaults-extra-file=/creds.cnf stream
```

---

[Back to Wiki Home](Home)
