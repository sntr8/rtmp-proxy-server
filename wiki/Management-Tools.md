# Management Tools Quick Reference

Command syntax cheat sheet for all tools in `tools/` directory. For detailed explanations and workflows, see [Configuration Guide](Configuration).

## Table of Contents

- [channelmod](#channelmod) - Platform channels
- [broadcastmod](#broadcastmod) - RTMP ingress points
- [gamemod](#gamemod) - Games with delays
- [castermod](#castermod) - Streamers
- [streammod](#streammod) - Schedule streams
- [containermod](#containermod) - Container lifecycle
- [haproxy_configmod](#haproxy_configmod) - HAProxy routing
- [discordmod](#discordmod) - Discord notifications
- [cron_worker.sh](#cron_workersh) - Automation

---

## channelmod

Manage platform channels (Twitch, Instagram, YouTube, Facebook).

```bash
# Create channels
./channelmod --create <name> <platform> <stream_url> [stream_key]
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp <key>
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2
./channelmod --create my_facebook facebook rtmps://live-api-s.facebook.com:443/rtmp <key>

# Set credentials
./channelmod --set <channel> <field> <value>
./channelmod --set my_twitch access_token "<token>"
./channelmod --set my_twitch client_id "<client_id>"
./channelmod --set my_twitch refresh_token "<refresh_token>"
./channelmod --set my_youtube client_id "<client_id>"
./channelmod --set my_youtube client_secret "<secret>"
./channelmod --set my_youtube refresh_token "<refresh_token>"
./channelmod --set my_instagram stream_key "<key>"

# Manage
./channelmod --list
./channelmod --remove <channel>
./channelmod --test-tokens <channel>
./channelmod --auto-fetch-key <channel>
./channelmod --refresh-tokens <channel>
```

---

## broadcastmod

Manage broadcasts (RTMP ingress points with ports).

```bash
# Create and link
./broadcastmod --create <name> <port> <display_name>
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link <broadcast> <channel> [priority]
./broadcastmod --link main-show my_twitch 1
./broadcastmod --link main-show my_instagram 2

# Manage
./broadcastmod --list
./broadcastmod --list <broadcast>
./broadcastmod --remove <broadcast>
./broadcastmod --set <broadcast> display_name <name>

# Enable/disable links
./broadcastmod --unlink <broadcast> <channel>
./broadcastmod --disable <broadcast> <channel>
./broadcastmod --enable <broadcast> <channel>
```

---

## gamemod

Manage games with stream delays.

```bash
# Add games
./gamemod --add <tech_name> <display_name> <abbr> <delay_seconds>
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./gamemod --add lol "League of Legends" "LoL" 0

# Interactive add
./gamemod --add

# Manage
./gamemod --list
./gamemod --list --ids
./gamemod --remove <tech_name>
```

---

## castermod

Manage streamers (casters).

```bash
# Add casters
./castermod --add <nickname> [discord_id]
./castermod --add JohnDoe 123456789012345678

# Manage
./castermod --list
./castermod --list --ids
./castermod --remove <nickname>
```

---

## streammod

Schedule and manage streams.

**Note:** Times are interpreted in MySQL container timezone. Ensure MySQL timezone matches your server (set with `--build-arg TZ=` during image build).

```bash
# Schedule streams
./streammod --add              # Interactive, regular stream
./streammod --add-proxy        # Interactive, proxy-only

# View streams
./streammod --upcoming         # Future streams
./streammod --upcoming --ids   # IDs only
./streammod --live             # Currently active
./streammod --live --ids       # IDs only
./streammod --ending           # Ending within 30 min

# Modify streams
./streammod --update <id>      # Edit details
./streammod --extend <id>      # Extend by 30 min
./streammod --skip <id>        # Don't auto-start
./streammod --unskip <id>      # Re-enable auto-start
./streammod --delete <id>      # Delete
```

---

## containermod

Manage Docker containers.

```bash
# Base containers (mysql, haproxy, nginx-http, php-fpm)
./containermod --start --all
./containermod --stop --all
./containermod --restart --all
./containermod --start --name <container>
./containermod --stop --name <container>
./containermod --restart --name <container>

# Stream containers
./containermod --start --name nginx-rtmp --caster <nick> --broadcast <broadcast> --game <game>
./containermod --start --name nginx-rtmp --caster <nick> --broadcast <broadcast> --proxy
./containermod --stop --name nginx-rtmp --caster <nick>
./containermod --stop --name nginx-rtmp --caster <nick> --proxy

# List
./containermod --list
```

---

## haproxy_configmod

Manage HAProxy routing (usually automatic).

```bash
./haproxy_configmod --add --caster <nickname> --port <port>
./haproxy_configmod --remove --caster <nickname>
./haproxy_configmod --reload
```

**Note:** Called automatically by `containermod`.

---

## discordmod

Discord notifications (template-based, called by `cron_worker.sh`).

**Templates:** `tools/discord/templates/`

**Events:**
- `startup` / `startup_cc` - Stream started
- `shutdown` / `shutdown_cc` - Stream stopped
- `shutdown-warning` / `shutdown-warning_cc` - Stream ending soon
- `startup-failed` / `startup-failed_cc` - Container start failed
- `shutdown-failed` / `shutdown-failed_cc` - Container stop failed
- `token-refresh-failed` - Token refresh failed
- `tokens-invalid` - Invalid tokens detected

**Configuration:** Set `DISCORD_WEBHOOK` and `DISCORD_SUPPORT_GROUP` in `/etc/profile.d/stream.sh`

---

## cron_worker.sh

Automation worker for scheduled streams.

**Setup:**
```bash
sudo crontab -e
```
```cron
*/5 * * * * source /etc/profile.d/stream.sh && /opt/rtmp-proxy-server/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

**Behavior:**
- Starts containers 30 min before scheduled time
- Stops containers 30 min after scheduled time
- Sends Discord notifications

**Logs:**
```bash
tail -f /var/log/stream-cron.log
```

---

## Quick Workflows

### Set up a new channel and broadcast
```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "<token>"
./channelmod --set my_twitch client_id "<id>"
./channelmod --set my_twitch refresh_token "<refresh>"
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch
```

### Schedule a stream
```bash
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./castermod --add JohnDoe 123456789012345678
./streammod --add
```

### Manual test stream
```bash
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
# Stream to: rtmp://stream.yourdomain.com:48001/JohnDoe/
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

---

For detailed explanations, see [Configuration Guide](Configuration).

[Back to Wiki Home](Home)
