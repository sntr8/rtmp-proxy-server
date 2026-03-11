# Configuration Guide

Comprehensive guide for configuring RTMP Proxy Server.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Platform Configuration](#platform-configuration)
- [Channels Configuration](#channels-configuration)
- [Broadcasts Configuration](#broadcasts-configuration)
- [Games Configuration](#games-configuration)
- [Casters Configuration](#casters-configuration)
- [Twitch API Tokens](#twitch-api-tokens)
- [YouTube API Tokens](#youtube-api-tokens)
- [Advertisements](#advertisements)
- [Discord Notifications](#discord-notifications)
- [HAProxy Configuration](#haproxy-configuration)
- [Advanced Settings](#advanced-settings)

## Architecture Overview

The system uses a **many-to-many** relationship between broadcasts and channels:

- **Channels**: Platform destinations (Twitch, Instagram, YouTube, Facebook) - reusable across broadcasts
- **Broadcasts**: RTMP ingress points with ports where streamers connect
- **Broadcast_Channels**: Junction table linking broadcasts to channels

**Example workflow:**
1. Create channels for your platforms (`my_twitch`, `my_instagram`, `my_youtube`)
2. Create a broadcast with a port (`main-show` on port 48001)
3. Link channels to the broadcast
4. Streamers connect to port 48001, stream outputs to all linked channels

## Platform Configuration

RTMP Proxy Server supports streaming to multiple platforms with platform-specific optimizations.

### Supported Platforms

| Platform | Stream Key Source | Notes |
|----------|-------------------|-------|
| **Twitch** | API (automatic) | Full automation support |
| **Instagram Live** | Manual | Requires stream key from Instagram |
| **Facebook Live** | Manual | Requires stream key from Facebook |
| **YouTube Live** | Manual | Requires stream key from YouTube |

### Default Platform URLs

```
Twitch:    rtmp://live.twitch.tv/app
Instagram: rtmp://live-upload.instagram.com:80/rtmp
Facebook:  rtmps://live-api-s.facebook.com:443/rtmp
YouTube:   rtmp://a.rtmp.youtube.com/live2
```

### Stream Key Management

| Platform | Stream Key Source | Auto-Fetch at Container Start |
|----------|-------------------|-------------------------------|
| **Twitch** | API (if credentials configured) or manual | ✅ Yes |
| **YouTube** | API (if credentials configured) or manual | ✅ Yes |
| **Instagram** | Manual only | ❌ No |
| **Facebook** | Manual only | ❌ No |

**Twitch with API credentials**: Stream key automatically fetched every container start
**YouTube with API credentials**: Stream key automatically fetched every container start
**Twitch/YouTube without API**: Uses manual `stream_key` from database
**Instagram/Facebook**: Always uses manual `stream_key` from database

### Important Configuration Notes

**OBS Settings for Instagram/Facebook:**
To ensure compatibility with Instagram and Facebook Live, configure your OBS with:
- **Video Codec**: H.264
- **Keyframe Interval**: 2 seconds
- **Audio Codec**: AAC, 44.1kHz, 128kbps
- **Rate Control**: CBR
- **Bitrate**: 3000-4000 kbps recommended

**YouTube Settings:**
- Same as above, but keyframe interval can be up to 4 seconds

The system uses passthrough (`-codec copy`) for all platforms, relying on correct OBS configuration.

### Getting Stream Keys

**Instagram Live:**
1. Use Instagram Live Producer or third-party tools
2. Navigate to live settings
3. Copy RTMP URL and Stream Key

**Facebook Live:**
1. Go to facebook.com/live/producer
2. Create new live stream
3. Copy Stream Key from settings

**YouTube Live:**
1. Go to youtube.com/live_dashboard
2. Create stream or event
3. Copy Stream key from Stream settings

## Games Configuration

Games determine stream delay settings and Twitch category information.

### Adding a Game

**Interactive mode:**
```bash
cd tools
./gamemod --add
```

Follow prompts:
1. **Technical name:** Short lowercase identifier (e.g., `csgo`, `pubg`, `lol`)
2. **Display name:** Must match Twitch exactly (e.g., `Counter-Strike: Global Offensive`)
3. **Abbreviation:** Short form for UI (e.g., `CS:GO`, `PUBG`, `LoL`)
4. **Delay:** Seconds (0 for instant, 480 for 8 minutes, etc.)

**Command-line mode:**
```bash
./gamemod --add <technical> <display_name> <abbreviation> <delay>

# Examples:
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480
./gamemod --add lol "League of Legends" "LoL" 0
./gamemod --add pubg "PlayerUnknown's Battlegrounds" "PUBG" 480
./gamemod --add rl "Rocket League" "RL" 0
./gamemod --add wow "World of Warcraft" "WoW" 300
```

### Common Game Delays

**Competitive games (stream sniping prevention):**
- 8 minutes (480s): PUBG, CS:GO, Valorant, Apex Legends
- 5 minutes (300s): MMO games, WoW

**Non-competitive games:**
- 0 seconds: Single-player games, League of Legends, Rocket League

### Listing Games

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

### Removing a Game

```bash
./gamemod --remove <technical_name>

# Example:
./gamemod --remove csgo
```

**Warning:** Cannot remove game if scheduled streams reference it.

### Database Schema

```sql
CREATE TABLE games (
    id INT AUTO_INCREMENT PRIMARY KEY,
    technical VARCHAR(255) UNIQUE NOT NULL,    -- Short identifier
    display_name VARCHAR(255) NOT NULL,         -- Twitch category name
    abbreviation VARCHAR(20) NOT NULL,          -- Short form
    delay INT NOT NULL DEFAULT 0                -- Delay in seconds
);
```

## Channels Configuration

Channels represent **platform destinations** where streams are published. Channels are reusable across multiple broadcasts.

### Creating a Channel

Use `channelmod` to create platform channels:

**Twitch Channel with API credentials (recommended):**
```bash
cd tools
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"
./channelmod --set my_twitch display_name "YourTwitchChannel"
```

**Twitch Channel with manual stream key:**
```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app live_123456789_abcdefg
./channelmod --set my_twitch display_name "YourTwitchChannel"
```

**Instagram Channel:**
```bash
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_stream_key>"
./channelmod --set my_instagram display_name "My Instagram Live"
```

**Facebook Channel:**
```bash
./channelmod --create my_facebook facebook rtmps://live-api-s.facebook.com:443/rtmp
./channelmod --set my_facebook stream_key "<facebook_stream_key>"
./channelmod --set my_facebook display_name "My Facebook Live"
```

**YouTube Channel with API credentials (recommended):**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2
./channelmod --set my_youtube client_id "$YOUTUBE_CLIENT_ID"
./channelmod --set my_youtube client_secret "$YOUTUBE_CLIENT_SECRET"
./channelmod --set my_youtube refresh_token "$YOUTUBE_REFRESH_TOKEN"
./channelmod --set my_youtube display_name "My YouTube Channel"
```

**YouTube Channel with manual stream key:**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2 xxxx-xxxx-xxxx-xxxx
./channelmod --set my_youtube display_name "My YouTube Channel"
```

### Listing Channels

```bash
cd tools
./channelmod --list
```

Output shows all channels with their platform, stream URL, and display name.

### Updating Channel Settings

```bash
./channelmod --set <channel_name> <field> <value>

# Examples:
./channelmod --set my_twitch display_name "NewChannelName"
./channelmod --set my_instagram stream_key "new_ig_stream_key"
./channelmod --set my_youtube stream_url rtmp://b.rtmp.youtube.com/live2

# API credentials (Twitch/YouTube)
./channelmod --set my_twitch access_token "new_token_here"
./channelmod --set my_twitch client_id "new_client_id"
./channelmod --set my_twitch refresh_token "new_refresh_token"
./channelmod --set my_youtube client_secret "new_client_secret"
```

**Available fields**: `platform`, `stream_url`, `stream_key`, `display_name`, `access_token`, `client_id`, `client_secret`, `refresh_token`

### Removing a Channel

```bash
./channelmod --remove <channel_name>
```

**Warning**: Cannot remove channel if linked to broadcasts. Unlink first using `broadcastmod --unlink`.

### Testing API Credentials

**Twitch:**
```bash
./channelmod --test-tokens my_twitch
```

**YouTube:**
```bash
./channelmod --test-tokens my_youtube
```

### Auto-Fetching Stream Keys

For channels with API credentials configured:

**Twitch:**
```bash
./channelmod --auto-fetch-key my_twitch
```

**YouTube:**
```bash
./channelmod --auto-fetch-key my_youtube
```

Stream keys are automatically fetched at container start for channels with API credentials.

### Database Schema

```sql
CREATE TABLE channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    platform ENUM('twitch', 'instagram', 'facebook', 'youtube') DEFAULT 'twitch',
    stream_url VARCHAR(512),
    stream_key VARCHAR(512),
    display_name VARCHAR(255),
    access_token TEXT,
    client_id VARCHAR(255),
    client_secret VARCHAR(512),
    refresh_token TEXT
);
```

## Broadcasts Configuration

Broadcasts represent **RTMP ingress points** where streamers connect. Each broadcast has a unique port and can output to multiple channels.

### Creating a Broadcast

```bash
cd tools
./broadcastmod --create <name> <port> [display_name]

# Examples:
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --create evening-cast 48002 "Evening Cast"
./broadcastmod --create tournament 48003 "Tournament Stream"
```

### Port Assignment

**Regular broadcasts:** 48001-48010
**Proxy broadcasts:** 48101-48110 (internal relay, no platform output)

**Important:** Each broadcast needs a unique port. Port determines HAProxy routing.

### Linking Channels to Broadcasts

```bash
./broadcastmod --link <broadcast> <channel> [priority]

# Examples:
./broadcastmod --link main-show my_twitch 1
./broadcastmod --link main-show my_instagram 2
./broadcastmod --link main-show my_youtube 3

# Result: main-show outputs to Twitch, Instagram, and YouTube simultaneously
```

**Priority**: Optional parameter for output order (lower = higher priority).

### Unlinking Channels

```bash
./broadcastmod --unlink <broadcast> <channel>

# Example:
./broadcastmod --unlink main-show my_instagram
```

### Enabling/Disabling Channels

Temporarily disable a channel without unlinking:

```bash
# Disable Instagram output without stopping stream
./broadcastmod --disable main-show my_instagram

# Re-enable later
./broadcastmod --enable main-show my_instagram
```

### Listing Broadcasts

```bash
# List all broadcasts
./broadcastmod --list

# Show specific broadcast with linked channels
./broadcastmod --list main-show
```

### Updating Broadcast Settings

```bash
./broadcastmod --set <broadcast> <key> <value>

# Examples:
./broadcastmod --set main-show display_name "Updated Main Show"
./broadcastmod --set main-show port 48005
```

**Available keys**: `name`, `display_name`, `port`

### Removing a Broadcast

```bash
./broadcastmod --remove <broadcast>
```

**Warning**: Cannot remove broadcast if:
- Active streams are using it
- Scheduled streams reference it

### Database Schema

```sql
-- Broadcasts table
CREATE TABLE broadcasts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    port INT UNIQUE NOT NULL,
    display_name VARCHAR(255)
);

-- Junction table
CREATE TABLE broadcast_channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    broadcast_id INT NOT NULL,
    channel_id INT NOT NULL,
    enabled TINYINT(1) DEFAULT 1,
    priority INT DEFAULT 0,
    FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id) ON DELETE CASCADE,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    UNIQUE KEY unique_broadcast_channel (broadcast_id, channel_id)
);
```

## Casters Configuration

Casters are streamers who have access to the system.

### Adding a Caster

```bash
cd tools
./castermod --add <nickname> <discord_id>

# Examples:
./castermod --add JohnDoe 123456789012345678
./castermod --add JaneDoe 987654321098765432
```

**What happens:**
- Creates database entry
- Generates unique stream key (format: `<nickname>-<random12chars>`)
- Outputs connection details

**Discord ID:** Optional but recommended for notifications. Get it by enabling Developer Mode in Discord, right-click user → Copy ID.

### Listing Casters

```bash
./castermod --list
```

Output shows:
- Nickname
- Stream key
- Discord ID (if set)

### Removing a Caster

```bash
./castermod --remove <nickname>

# Example:
./castermod --remove JohnDoe
```

**Warning:** Cannot remove caster if scheduled streams reference them.

### Updating Stream Key

Regenerate a caster's stream key (e.g., if compromised):

```bash
# Remove and re-add
./castermod --remove JohnDoe
./castermod --add JohnDoe 123456789012345678
```

Or directly in database:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE casters SET stream_key = 'JohnDoe-newabc123def' WHERE nick = 'JohnDoe'"
```

### Database Schema

```sql
CREATE TABLE casters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nick VARCHAR(255) UNIQUE NOT NULL,      -- Nickname
    stream_key VARCHAR(255) UNIQUE NOT NULL, -- Authentication key
    discord_id VARCHAR(255),                 -- Discord user ID
    proxy_channel_id INT,                    -- Assigned proxy channel
    FOREIGN KEY (proxy_channel_id) REFERENCES channels(id)
);
```

### Internal Technical Users

Two special casters exist for system operation:

```sql
INSERT INTO casters (nick, stream_key) VALUES
    ('internal_technical_user', 'internal-technical'),  -- Delay system
    ('vlc_viewer', 'vlc-view');                         -- VLC playback
```

**Do not delete these.** They're used for internal container communication.

## Twitch API Tokens

Tokens authenticate with Twitch API for managing channel information.

### Getting Tokens

1. Visit [twitchtokengenerator.com](https://twitchtokengenerator.com)
2. Select scopes:
   - `channel:manage:broadcast` (required)
   - `channel:read:stream_key` (optional, for key retrieval)
3. Authorize with Twitch
4. Copy:
   - **Client ID**
   - **Access Token**
   - **Refresh Token**

### Setting Tokens

**During installation:**
Add to `/etc/profile.d/stream.sh`:
```bash
export TWITCH_CLIENT_ID="your_client_id"
export TWITCH_ACCESS_TOKEN="your_access_token"
export TWITCH_REFRESH_TOKEN="your_refresh_token"
```

**For existing channels:**
```bash
./channelmod --set yourchannel access_token "new_token_here"
./channelmod --set yourchannel refresh_token "new_refresh_token"
./channelmod --set yourchannel client_id "new_client_id"
```

### Refreshing Tokens

Tokens expire after ~60 days. Refresh them:

```bash
./channelmod --refresh-tokens <channel_name>

# Example:
./channelmod --refresh-tokens yourchannel
```

This uses the stored refresh token to get a new access token.

**Automated refresh:**
Add to crontab:
```cron
0 2 * * 0 /path/to/tools/channelmod --refresh-tokens-all >> /var/log/token-refresh.log 2>&1
```

Runs weekly on Sundays at 2 AM.

### Checking Token Status

```bash
./channelmod --test-tokens <channel_name>

# Example:
./channelmod --test-tokens my_twitch
```

## YouTube API Tokens

YouTube OAuth2 credentials enable automatic stream key fetching.

### Getting YouTube Credentials

1. **Create OAuth2 app** in Google Cloud Console
2. **Enable YouTube Data API v3**
3. **Create OAuth2 credentials** (Desktop app or Web app)
4. **Get authorization code** using OAuth2 flow
5. **Exchange for refresh_token**

### Required Scopes

```
https://www.googleapis.com/auth/youtube.readonly
```

### Setting YouTube Credentials

```bash
cd tools
./channelmod --set my_youtube client_id "your_client_id.apps.googleusercontent.com"
./channelmod --set my_youtube client_secret "your_client_secret"
./channelmod --set my_youtube refresh_token "your_refresh_token"
```

### Testing YouTube Credentials

```bash
./channelmod --test-tokens my_youtube
```

### Auto-Fetching YouTube Stream Keys

```bash
./channelmod --auto-fetch-key my_youtube
```

**Automatic behavior**: When starting a container, YouTube stream keys are automatically fetched if:
- Channel has `client_id`, `client_secret`, and `refresh_token` configured
- Active YouTube live stream exists at studio.youtube.com

**How it works**:
- Fetches fresh 1-hour access token using refresh_token
- Retrieves stream key from YouTube API
- Uses immediately, then discards (access_token not stored)
- Repeats every container start

### Refreshing YouTube Credentials

```bash
./channelmod --refresh-tokens my_youtube
```

Verifies credentials are valid.

## Advertisements

Serve rotating advertisements on a web page for use in OBS browser sources.

### Directory Structure

```
nginx-http/html/ads/
├── ads.php              # Main ad rotation page
├── carousel.js          # Carousel implementation
├── img/
│   ├── common/         # Ads shown on all streams
│   │   ├── sponsor1.png
│   │   └── sponsor2.jpg
│   ├── csgo/           # CS:GO specific ads
│   │   ├── tournament.png
│   │   └── team-sponsor.jpg
│   ├── pubg/           # PUBG specific ads
│   │   └── event.png
│   └── lol/            # League of Legends ads
│       └── league-sponsor.jpg
```

### Adding Advertisements

1. **Prepare images:**
   - Format: `.png` or `.jpg` (lowercase extension required)
   - Recommended resolution: 1920x1080 or 1280x720
   - File size: Keep under 2MB for fast loading

2. **Copy to nginx-http directory:**
```bash
cd nginx-http/html/ads/img

# Common ads (all games)
cp /path/to/ad.png common/

# Game-specific ads
cp /path/to/csgo-ad.jpg csgo/
cp /path/to/pubg-ad.png pubg/
```

3. **Rebuild nginx-http container:**
```bash
cd tools
docker build -t nginx-http:v1.6 ../nginx-http/
./containermod --restart --name nginx-http
```

### Using Ads in OBS

Add a **Browser Source** in OBS:

**URL:**
```
https://stream.yourdomain.com/ads/?game=csgo&interval=10
```

**Parameters:**
- `game`: Game technical name (e.g., `csgo`, `pubg`, `lol`)
- `interval`: Seconds between ad rotation (default: 10)

**OBS Settings:**
- Width: 1920 (or your stream resolution)
- Height: 1080
- FPS: 30
- Check "Shutdown source when not visible"
- Uncheck "Control audio via OBS"

**Positioning:**
Position the browser source at bottom of scene for lower-third ad display.

### Ad Rotation Logic

1. Loads images from `img/common/` (shown on all streams)
2. Loads images from `img/<game>/` (game-specific)
3. Combines both arrays
4. Rotates through all ads with fade transition
5. Respects `interval` parameter

### Testing Ads

Open in browser:
```
https://stream.yourdomain.com/ads/?game=csgo
```

Should see ads rotating with fade transitions.

## Discord Notifications

Automated Discord messages for stream events.

### Setup

1. **Create Discord webhook:**
   - Server Settings → Integrations → Webhooks
   - Create webhook, copy URL

2. **Set environment variable:**
```bash
# Add to /etc/profile.d/stream.sh
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/123456789/abcdefg..."

# Optional: Support group for error notifications (flexible formats accepted)
export DISCORD_SUPPORT_GROUP="987654321"        # Just ID (defaults to role)
export DISCORD_SUPPORT_GROUP="&987654321"       # Role with & prefix
export DISCORD_SUPPORT_GROUP="@123456789"       # User with @ prefix
export DISCORD_SUPPORT_GROUP="<@&987654321>"    # Full Discord syntax
```

3. **Reload environment:**
```bash
source /etc/profile.d/stream.sh
```

### Notification Events

- **Stream starting:** "Container starting for [Caster] - [Game]"
- **Stream ending:** "Container stopping for [Caster]"
- **Errors:** Container start/stop failures
- **Token expiry:** Twitch token expiring soon

### Manual Notification

```bash
cd tools
./discordmod --send "Test message"
```

### Customizing Messages

Edit `tools/discordmod`:
```bash
# Customize message format
MESSAGE="🔴 **Live:** $CASTER is streaming $GAME on $CHANNEL"
```

## HAProxy Configuration

HAProxy routing is usually managed automatically by `haproxy_configmod`, but manual editing is possible.

### Configuration File

Location: `/opt/haproxy/haproxy.cfg` (on host, mounted into container)

### Manual Editing

```bash
sudo vi /opt/haproxy/haproxy.cfg
```

**Important:** Don't edit between `# ::<CasterName>::start` and `# ::<CasterName>::end` markers - these are managed automatically.

### Reload HAProxy

After manual edits:
```bash
docker exec haproxy killall -HUP haproxy
```

Graceful reload - existing connections continue.

### Adding Custom Backends

Example: Add a custom RTMP server behind HAProxy:

```haproxy
frontend rtmp-custom
    bind *:48020
    mode tcp
    default_backend custom-rtmp

backend custom-rtmp
    mode tcp
    server custom-server 192.168.1.100:1935 check
```

### SSL Certificate Management

HAProxy uses Let's Encrypt via certbot.

**Certificate location:**
```
/etc/haproxy/certs/live/${FQDN}/fullchain.pem
/etc/haproxy/certs/live/${FQDN}/privkey.pem
```

**Manual renewal:**
```bash
docker exec haproxy /usr/local/bin/certbot renew
```

**Auto-renewal (crontab):**
```cron
0 3 * * * docker exec haproxy /usr/local/bin/certbot renew --quiet
```

## Advanced Settings

### Changing Stream Delay

**Per game:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE games SET delay = 600 WHERE technical = 'csgo'"
```

Changes CS:GO delay to 10 minutes (600 seconds).

**Per stream (override):**
Not directly supported - delay is determined by game setting.

### Custom FFmpeg Parameters

Edit nginx-rtmp configuration templates:

**For delay mode:** `nginx-rtmp/templates/delayer_settings.py.template`
```python
FFMPEG_EXTRA_OPTS = [
    '-loglevel', 'debug',
    '-rtmp_buffer', '1000',
    # Add custom FFmpeg options
]
```

**For instant mode:** `nginx-rtmp/templates/nginx_proxy.conf.template`
```nginx
exec_push /usr/bin/ffmpeg -loglevel debug -re -rtmp_live live
          -i rtmp://127.0.0.1/${app}/${name}
          -c:v libx264 -preset ultrafast -tune zerolatency  # Custom encoding
          -c:a aac -b:a 128k
          -f flv rtmp://live.twitch.tv/app/${TWITCH_STREAM_KEY};
```

**Rebuild containers** after editing:
```bash
cd tools
./build_all_images.sh v1.6
```

### Changing Port Ranges

**Extend beyond 48001-48110:**

1. **Update haproxy/Dockerfile:**
```dockerfile
EXPOSE 48001-48020  # Extend range
EXPOSE 48101-48120
```

2. **Rebuild HAProxy:**
```bash
cd haproxy
docker build -t haproxy:v1.7 .
```

3. **Update firewall:**
```bash
sudo ufw allow 48001:48020/tcp
sudo ufw allow 48101:48120/tcp
```

4. **Assign new ports to channels in database**

### MySQL Tuning

For high-load scenarios, tune MySQL:

Edit `mysql/my.cnf`:
```ini
[mysqld]
max_connections = 500
innodb_buffer_pool_size = 1G
query_cache_size = 32M
```

Restart MySQL:
```bash
cd tools
./containermod --restart --name mysql
```

### Logging Configuration

**HAProxy logs:**
```bash
docker logs haproxy
docker logs -f haproxy  # Follow mode
```

**nginx-rtmp logs:**
```bash
docker logs nginx-rtmp-JohnDoe
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/error.log
```

**MySQL logs:**
```bash
docker logs mysql
docker exec mysql tail -f /var/log/mysql/error.log
```

**FFmpeg logs (delay mode):**
```bash
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/ffmpeg.log
```

### Backup and Restore

**Database backup:**
```bash
docker exec mysql mysqldump -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE > backup.sql
```

**Database restore:**
```bash
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < backup.sql
```

**Configuration backup:**
```bash
cp -r /opt/haproxy haproxy-backup
cp /etc/profile.d/stream.sh stream.sh.backup
```

---

[Back to Wiki Home](Home)
