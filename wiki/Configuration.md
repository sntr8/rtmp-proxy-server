# Configuration Guide

Complete setup guide after installing base containers. If you haven't installed yet, see [Installation Guide](Installation) first.

## Table of Contents

- [Quick Setup Workflow](#quick-setup-workflow)
- [Platform Configuration](#platform-configuration)
- [Channels Configuration](#channels-configuration)
- [Broadcasts Configuration](#broadcasts-configuration)
- [Games Configuration](#games-configuration)
- [Casters Configuration](#casters-configuration)
- [Scheduling Streams](#scheduling-streams)
- [Testing Your Setup](#testing-your-setup)
- [OBS Settings](#obs-settings)
- [Twitch API Tokens](#twitch-api-tokens)
- [YouTube API Tokens](#youtube-api-tokens)
- [Advertisements](#advertisements)
- [Discord Notifications](#discord-notifications)
- [HAProxy Configuration](#haproxy-configuration)
- [Advanced Settings](#advanced-settings)

## Quick Setup Workflow

The system uses a many-to-many model: **Channels** (platform destinations) ↔ **Broadcasts** (RTMP ingress points). See [Architecture - Many-to-Many Model](Architecture#many-to-many-broadcast-architecture) for details.

**Complete these steps to start streaming:**
1. Create channels for your platforms → `channelmod`
2. Create a broadcast with a port → `broadcastmod --create`
3. Link channels to the broadcast → `broadcastmod --link`
4. Add games → `gamemod --add`
5. Add casters → `castermod --add`
6. Schedule streams → `streammod --add`
7. Test your setup

## Platform Configuration

Supports streaming to Twitch, Instagram, Facebook, and YouTube simultaneously. See [Architecture - Multi-Platform Support](Architecture#many-to-many-broadcast-architecture) for technical details.

### Platform URLs

```
Twitch:    rtmp://live.twitch.tv/app
Instagram: rtmp://live-upload.instagram.com:80/rtmp
Facebook:  rtmps://live-api-s.facebook.com:443/rtmp
YouTube:   rtmp://a.rtmp.youtube.com/live2
```

### Stream Key Management

| Platform | Auto-Fetch | Manual |
|----------|-----------|--------|
| **Twitch** | ✅ Yes (with API credentials) | ✅ Yes |
| **YouTube** | ✅ Yes (with API credentials) | ✅ Yes |
| **Instagram** | ❌ No | ✅ Yes |
| **Facebook** | ❌ No | ✅ Yes |

See [Twitch API Tokens](#twitch-api-tokens) and [YouTube API Tokens](#youtube-api-tokens) for auto-fetch setup.

### Getting Manual Stream Keys

- **Instagram**: Use Instagram Live Producer → Copy stream key
- **Facebook**: facebook.com/live/producer → Create stream → Copy key
- **YouTube**: youtube.com/live_dashboard → Create stream → Copy key

## Games Configuration

Games determine stream delay and Twitch category. See [Architecture - Stream Delay](Architecture#stream-delay-implementation) for how delays work.

### Adding a Game

```bash
cd tools
./gamemod --add <technical> <display_name> <abbreviation> <delay_seconds>

# Examples:
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./gamemod --add lol "League of Legends" "LoL" 0
./gamemod --add pubg "PlayerUnknown's Battlegrounds" "PUBG" 480
```

**Fields:**
- `technical`: Short identifier (lowercase, e.g., `csgo`)
- `display_name`: Must match Twitch category exactly
- `abbreviation`: Short form for display (e.g., `CS:GO`)
- `delay_seconds`: 0 = instant, 480 = 8 minutes, 300 = 5 minutes

**Common delays:**
- Competitive (stream sniping): 480s (8 min)
- Non-competitive: 0s (instant)

### Listing and Removing

```bash
./gamemod --list
./gamemod --remove <technical_name>
```

## Channels Configuration

Channels are reusable platform destinations. See [Architecture - Channels](Architecture#many-to-many-broadcast-architecture) for the data model.

### Creating Channels

**Twitch with API (auto-fetch keys):**
```bash
cd tools
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "<your_access_token>"
./channelmod --set my_twitch client_id "<your_client_id>"
./channelmod --set my_twitch refresh_token "<your_refresh_token>"
./channelmod --set my_twitch display_name "MyTwitchChannel"
```

**Twitch with manual key:**
```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app live_123456789_abc
./channelmod --set my_twitch display_name "MyTwitchChannel"
```

**Instagram (manual key only):**
```bash
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_key>"
./channelmod --set my_instagram display_name "My Instagram"
```

**Facebook (manual key only):**
```bash
./channelmod --create my_facebook facebook rtmps://live-api-s.facebook.com:443/rtmp
./channelmod --set my_facebook stream_key "<facebook_key>"
./channelmod --set my_facebook display_name "My Facebook"
```

**YouTube with API (auto-fetch keys):**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2
./channelmod --set my_youtube client_id "<your_client_id>"
./channelmod --set my_youtube client_secret "<your_client_secret>"
./channelmod --set my_youtube refresh_token "<your_refresh_token>"
./channelmod --set my_youtube display_name "My YouTube"
```

**YouTube with manual key:**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2 xxxx-xxxx-xxxx-xxxx
./channelmod --set my_youtube display_name "My YouTube"
```

### Managing Channels

```bash
./channelmod --list                              # List all channels
./channelmod --set <channel> <field> <value>     # Update field
./channelmod --remove <channel>                  # Remove (if not linked)
./channelmod --test-tokens <channel>             # Test API credentials
./channelmod --auto-fetch-key <channel>          # Manually fetch key (Twitch/YouTube)
```

**Note:** Channels with API credentials auto-fetch keys at container start.

## Broadcasts Configuration

Broadcasts are RTMP ingress points where streamers connect. See [Architecture - Broadcasts](Architecture#many-to-many-broadcast-architecture) for the data model.

### Creating and Linking

```bash
cd tools

# Create broadcast with unique port
./broadcastmod --create main-show 48001 "Main Show"

# Link channels (enables multi-platform streaming)
./broadcastmod --link main-show my_twitch 1
./broadcastmod --link main-show my_instagram 2
./broadcastmod --link main-show my_youtube 3

# Result: Streaming to port 48001 outputs to all 3 platforms
```

**Port ranges:**
- Regular: 48001-48010
- Proxy: 48101-48110 (internal relay only)

### Managing Broadcasts

```bash
./broadcastmod --list                           # List all
./broadcastmod --list main-show                 # Show linked channels
./broadcastmod --unlink main-show my_instagram  # Remove link
./broadcastmod --disable main-show my_instagram # Temp disable
./broadcastmod --enable main-show my_instagram  # Re-enable
./broadcastmod --set main-show display_name "New Name"
./broadcastmod --remove main-show               # Remove (if not in use)
```

## Casters Configuration

Casters are streamers with system access. See [Architecture - Authentication](Architecture#authentication-system) for how keys work.

### Adding and Managing Casters

```bash
cd tools
./castermod --add <nickname> <discord_id>     # Add (generates stream key)
./castermod --list                            # List all
./castermod --remove <nickname>               # Remove (if not scheduled)

# Example:
./castermod --add JohnDoe 123456789012345678
```

**Stream key format:** `<nickname>-<random12chars>` (auto-generated)

**Discord ID:** Optional, for notifications (Discord → User Settings → Copy ID)

### Regenerating Stream Keys

If compromised, remove and re-add:
```bash
./castermod --remove JohnDoe
./castermod --add JohnDoe 123456789012345678
```

**Note:** Do not delete `internal_technical_user` or `vlc_viewer` (system users).

## Scheduling Streams

Schedule streams to automatically start/stop containers at specified times.

### Adding a Stream

```bash
cd tools
./streammod --add
```

Follow the interactive prompts:
- **Caster**: Select from list
- **Co-caster**: Optional, for dual-stream setups
- **Broadcast**: Select from list
- **Game**: Select from list
- **Twitch title**: Stream title
- **Start time**: Format `DD.MM.YYYY HH:MM` (EU) or `MM/DD/YYYY HH:MM` (US)
- **End time**: Same format

**Add proxy-only stream** (no platform output, internal relay only):
```bash
./streammod --add-proxy
```

**Important:**
- Containers automatically start **30 minutes before** scheduled time
- Containers automatically stop **30 minutes after** scheduled time
- Times are interpreted in **MySQL container timezone** (set during image build with `--build-arg TZ=<timezone>`)
  - If MySQL timezone doesn't match your server, scheduling will be confusing
  - Example: MySQL in UTC, server in UTC+2 → scheduling "19:30" starts at 21:30 local time

### Managing Streams

```bash
# View streams
./streammod --upcoming          # Future streams
./streammod --live              # Currently active
./streammod --ending            # Ending soon (within 30 min)

# Modify streams
./streammod --update <id>       # Update stream details
./streammod --extend <id>       # Extend end time by 30 minutes
./streammod --skip <id>         # Skip (don't auto-start)
./streammod --unskip <id>       # Re-enable auto-start
./streammod --delete <id>       # Delete from database
```

## Container Management

Manually start/stop containers for testing or manual streaming.

### Base Containers

```bash
cd tools

# Start/stop all base containers (mysql, haproxy, nginx-http, php-fpm)
./containermod --start --all
./containermod --stop --all
./containermod --restart --all

# Individual containers
./containermod --start --name <container>
./containermod --stop --name <container>
./containermod --restart --name <container>

# List running containers
./containermod --list
```

**Container names:** `mysql`, `haproxy`, `nginx-http`, `php-fpm`

### Stream Containers

```bash
# Start a stream container
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo

# Start a proxy container (internal relay only)
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast johndoe-proxy --proxy

# Stop a stream container
./containermod --stop --name nginx-rtmp --caster JohnDoe

# Stop a proxy container
./containermod --stop --name nginx-rtmp --caster JohnDoe --proxy
```

**Note:** Stream containers are normally managed automatically via `cron_worker.sh` based on scheduled streams.

## Testing Your Setup

Once you've configured channels, broadcasts, and casters, test your streaming setup.

### Manual Test Stream

1. **Start a test container:**
```bash
cd tools
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
```

2. **Configure OBS:**
   - **Server:** `rtmp://stream.yourdomain.com:48001/JohnDoe/`
   - **Stream Key:** `JohnDoe-abc123def456` (get from `./castermod --list`)

3. **Start streaming in OBS**

4. **Check output** on linked platform channels (Twitch, Instagram, YouTube, etc.)

5. **Stop container when done:**
```bash
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

### Verify Multi-Platform Output

If you linked multiple channels to your broadcast:
- Check each platform (Twitch, Instagram, YouTube, Facebook)
- Verify stream appears on all linked platforms
- Check stream quality and sync

## OBS Settings

The system uses passthrough encoding (`-codec copy`), so correct OBS settings are critical.

**For Instagram/Facebook (required):**
- Keyframe Interval: 2 seconds
- Video: H.264, CBR, 3000-4000 kbps
- Audio: AAC, 44.1kHz, 128kbps

**For YouTube/Twitch:**
- Keyframe Interval: 2-4 seconds
- Same video/audio settings as above

**Why keyframe interval matters:**
- Instagram/Facebook require 2-second keyframes or the stream will fail
- YouTube/Twitch are more flexible (2-4 seconds)
- If streaming to multiple platforms, use 2 seconds for compatibility

## Twitch API Tokens

Enables auto-fetch of stream keys and automatic title/game updates.

### Getting Tokens

1. Visit [twitchtokengenerator.com](https://twitchtokengenerator.com)
2. Select scopes: `channel:manage:broadcast`, `channel:read:stream_key`
3. Copy: Client ID, Access Token, Refresh Token

### Setting Tokens

```bash
cd tools
./channelmod --set my_twitch access_token "<your_access_token>"
./channelmod --set my_twitch client_id "<your_client_id>"
./channelmod --set my_twitch refresh_token "<your_refresh_token>"
```

### Refreshing Tokens

Tokens expire after ~60 days:

```bash
./channelmod --refresh-tokens my_twitch
./channelmod --test-tokens my_twitch  # Verify
```

**Automated refresh (crontab):**
```cron
0 2 * * 0 /path/to/tools/channelmod --refresh-tokens my_twitch >> /var/log/token-refresh.log 2>&1
```

## YouTube API Tokens

Enables auto-fetch of stream keys. Requires OAuth2 setup in Google Cloud Console.

### Getting Credentials

1. Create OAuth2 app in Google Cloud Console
2. Enable YouTube Data API v3
3. Create credentials (scope: `youtube.readonly`)
4. Get: Client ID, Client Secret, Refresh Token

### Setting Credentials

```bash
cd tools
./channelmod --set my_youtube client_id "your_client_id.apps.googleusercontent.com"
./channelmod --set my_youtube client_secret "your_client_secret"
./channelmod --set my_youtube refresh_token "your_refresh_token"
```

### Testing

```bash
./channelmod --test-tokens my_youtube
./channelmod --auto-fetch-key my_youtube  # Manual fetch
```

**Note:** Keys auto-fetched at container start if credentials configured. Requires active YouTube live stream at studio.youtube.com.

## Advertisements

Rotating ads for OBS browser sources.

### Adding Advertisements

1. **Prepare images** (`.png` or `.jpg`, 1920x1080 recommended, <2MB)

2. **Copy to nginx-http:**
```bash
cd nginx-http/html/ads/img
cp /path/to/ad.png common/          # All games
cp /path/to/csgo-ad.jpg csgo/       # Game-specific
```

3. **Rebuild container:**
```bash
cd tools
docker build -t nginx-http:v1.6 ../nginx-http/
./containermod --restart --name nginx-http
```

### Using in OBS

Add Browser Source:
```
URL: https://stream.yourdomain.com/ads/?game=csgo&interval=10
Width: 1920, Height: 1080, FPS: 30
```

Parameters: `game` (technical name), `interval` (seconds between rotations)

## Discord Notifications

Automated notifications for stream events.

### Setup

```bash
# Add to /etc/profile.d/stream.sh
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
export DISCORD_SUPPORT_GROUP="987654321"  # Optional, for error pings

source /etc/profile.d/stream.sh
```

**Get webhook:** Discord → Server Settings → Integrations → Webhooks → Create

**Automated events:** Stream start/stop, errors, token expiry (sent by `cron_worker.sh`)

**Note:** Discord notifications use predefined templates. Custom messages require editing template files in `tools/discord/templates/`.

## HAProxy Configuration

Usually auto-managed. See [Architecture - HAProxy](Architecture#haproxy-configuration-structure) for details.

### Manual Edits

```bash
sudo vi /opt/haproxy/haproxy.cfg
docker exec haproxy killall -HUP haproxy  # Graceful reload
```

**Warning:** Don't edit between `# ::<CasterName>::start/end` markers (auto-managed).

### SSL Certificates

Certificates are automatically renewed by the HAProxy container (checks every 12 hours).

**Force fresh certificate (if renewal fails):**
```bash
sudo rm -rf /opt/letsencrypt/*
docker restart haproxy
```

## Advanced Settings

### Changing Stream Delay

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE games SET delay = 600 WHERE technical = 'csgo'"
```

### Extending Port Ranges

1. Update `haproxy/Dockerfile`: `EXPOSE 48001-48020`
2. Rebuild HAProxy
3. Update firewall: `sudo ufw allow 48001:48020/tcp`
4. Create broadcasts with new ports

### Backup and Restore

```bash
# Backup database
docker exec mysql mysqldump -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE > backup.sql

# Restore database
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < backup.sql

# Backup configs
cp -r /opt/haproxy haproxy-backup
cp /etc/profile.d/stream.sh stream.sh.backup
```

### Viewing Logs

```bash
# Container logs (includes nginx and FFmpeg output)
docker logs haproxy
docker logs nginx-rtmp-JohnDoe
docker logs -f nginx-rtmp-JohnDoe  # Follow mode

# Check specific log files inside container (if needed)
docker exec nginx-rtmp-JohnDoe ls -la /opt/nginx/logs/
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/error.log
```

For MySQL tuning, custom FFmpeg parameters, see [Architecture](Architecture).

---

[Back to Wiki Home](Home)
