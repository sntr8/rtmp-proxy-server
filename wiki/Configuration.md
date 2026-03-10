# Configuration Guide

Comprehensive guide for configuring RTMP Proxy Server.

## Table of Contents

- [Games Configuration](#games-configuration)
- [Channels Configuration](#channels-configuration)
- [Casters Configuration](#casters-configuration)
- [Twitch API Tokens](#twitch-api-tokens)
- [Advertisements](#advertisements)
- [Discord Notifications](#discord-notifications)
- [HAProxy Configuration](#haproxy-configuration)
- [Advanced Settings](#advanced-settings)

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

Channels represent Twitch channels where streams are published.

### Adding a Channel

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES (
     'yourchannel',                        # Channel name (lowercase)
     'YourChannel',                        # Display name (exact Twitch capitalization)
     '$TWITCH_ACCESS_TOKEN',               # OAuth token
     '$TWITCH_CLIENT_ID',                  # Client ID
     '$TWITCH_REFRESH_TOKEN',              # Refresh token
     DATE_ADD(NOW(), INTERVAL 60 DAY),     # Expiry (60 days)
     48001,                                # RTMP port
     'https://twitch.tv/yourchannel'       # Channel URL
   )"
```

### Port Assignment

**Regular channels (Twitch output):** 48001-48010
- First channel: 48001
- Second channel: 48002
- Third channel: 48003
- etc.

**Proxy channels (internal only):** 48101-48110
- First proxy: 48101
- Second proxy: 48102
- etc.

**Important:** Each channel needs a unique port. Port determines HAProxy routing.

### Adding Proxy Channels

Proxy channels don't output to Twitch - used for internal relay or cocaster setups:

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, port, url)
   VALUES ('only1-proxy', 'Proxy Channel 1', 48101, '')"
```

Default proxy channels (automatically created by schema.sql):
- `only1-proxy` through `only6-proxy`

### Listing Channels

```bash
./channelmod --list
```

Or directly query:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, display_name, port, url FROM channels"
```

### Updating Channel Settings

```bash
./channelmod --set <channel_name> <field> <value>

# Examples:
./channelmod --set yourchannel display_name "YourNewName"
./channelmod --set yourchannel url "https://twitch.tv/yournewname"
./channelmod --set yourchannel port 48005
```

### Database Schema

```sql
CREATE TABLE channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,          -- Channel identifier
    display_name VARCHAR(255) NOT NULL,         -- Display name
    access_token TEXT,                           -- OAuth access token
    client_id VARCHAR(255),                      -- Twitch client ID
    refresh_token TEXT,                          -- OAuth refresh token
    access_token_expires DATETIME,               -- Token expiry
    port INT UNIQUE NOT NULL,                    -- RTMP port
    url VARCHAR(255) NOT NULL,                   -- Twitch URL
    stream_key VARCHAR(255)                      -- Twitch stream key (optional)
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
./channelmod --set yourchannel access_token_expires "2026-05-01 00:00:00"
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
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, access_token_expires FROM channels WHERE name NOT LIKE '%proxy%'"
```

Shows expiry dates for all channels.

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
export DISCORD_SUPPORT_GROUP="<@&987654321>"  # Optional: role ID for mentions
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
