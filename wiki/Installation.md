# Installation Guide

Complete step-by-step guide for installing RTMP Proxy Server from scratch.

## Prerequisites

### Hardware & System
- Linux server (Ubuntu 20.04+ or Debian 11+ recommended)
- At least 2GB RAM
- 10GB disk space (more for stream recordings if using delay)
- Docker installed and running
- Root or sudo access

### Network Requirements
- Domain name pointing to your server's IP address
- **Firewall/Security Group Configuration:**
  - Port 22 (SSH)
  - Port 80 (HTTP - Let's Encrypt validation, redirects to HTTPS)
  - Port 443 (HTTPS - Web interface)
  - Ports 48001-48010 (RTMP stream channels)
  - Ports 48101-48110 (RTMP proxy channels)

### Streaming Platform Requirements

**Twitch:**
- Twitch account(s) for channels you want to stream to
- Twitch API credentials (Client ID, Access Token, Refresh Token)
  - Get these from [twitchtokengenerator.com](https://twitchtokengenerator.com)
  - Requires: `channel:manage:broadcast`, `channel:read:stream_key` scopes

**YouTube:**
- YouTube account with live streaming enabled
- Option 1: API credentials (Client ID, Client Secret, Refresh Token) for auto-fetch
  - Get from [Google Cloud Console](https://console.cloud.google.com)
  - Enable YouTube Data API v3
  - Scope: `youtube.readonly`
- Option 2: Manual stream key from [YouTube Live Dashboard](https://youtube.com/live_dashboard)

**Instagram:**
- Instagram account with live streaming access
- Manual stream key from [Instagram Live Producer](https://www.instagram.com/live/producer)

**Facebook:**
- Facebook page or profile with live streaming access
- Manual stream key from [Facebook Live Producer](https://facebook.com/live/producer)

### Optional
- GitLab account for HAProxy config backup
- Discord webhook URL for notifications

## Quick Start

For experienced users who want the fast track:

```bash
# Clone and configure
git clone https://github.com/sntr8/rtmp-proxy-server.git
cd rtmp-proxy-server
sudo vi /etc/profile.d/stream.sh  # Set all environment variables
source /etc/profile.d/stream.sh

# Make environment available everywhere
echo '[ -f /etc/profile.d/stream.sh ] && . /etc/profile.d/stream.sh' | sudo tee -a /etc/bash.bashrc
echo 'Defaults env_keep += "FQDN MYSQL_* TWITCH_* HAPROXY_VERSION MYSQL_VERSION NGINX_HTTP_VERSION NGINX_RTMP_VERSION PHP_FPM_VERSION DOCKER_USERNAME REGISTRY_URL DISCORD_*"' | sudo EDITOR='tee -a' visudo

# Build and deploy
cd tools
./build_all_images.sh v1.6
./containermod --start --name mysql

# Add channel, broadcast, and caster
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch
./containermod --start --all
./castermod --add JohnDoe 123456789012345678
./streammod --add
```

## Detailed Installation

### Step 1: Clone Repository

```bash
cd /opt  # or your preferred location
git clone https://github.com/sntr8/rtmp-proxy-server.git
cd rtmp-proxy-server
```

### Step 2: Configure Environment Variables

Create `/etc/profile.d/stream.sh` with the following content:

```bash
#!/bin/bash

# Domain Configuration
export FQDN="stream.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"

# MySQL Configuration
export MYSQL_ROOT_PASSWORD="your_very_secure_root_password"
export MYSQL_USER="stream_user"
export MYSQL_PASSWORD="your_secure_password"
export MYSQL_DATABASE="stream"

# Twitch API Credentials (from twitchtokengenerator.com)
export TWITCH_CLIENT_ID="your_twitch_client_id"
export TWITCH_ACCESS_TOKEN="your_twitch_access_token"
export TWITCH_REFRESH_TOKEN="your_twitch_refresh_token"

# Discord Webhooks (optional, for notifications)
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
# Support group - accepts multiple formats:
# Role: "987654321", "&987654321", or "<@&987654321>"
# User: "@123456789" or "<@123456789>"
export DISCORD_SUPPORT_GROUP="987654321"

# Container Versions (check releases for latest)
export HAPROXY_VERSION="v1.6"
export MYSQL_VERSION="v1.6"
export NGINX_HTTP_VERSION="v1.6"
export NGINX_RTMP_VERSION="v1.6"
export PHP_FPM_VERSION="v1.6"
```

**Important:** Replace all placeholder values with your actual credentials.

Load the environment variables:
```bash
source /etc/profile.d/stream.sh
```

**Make environment available in all shells:**

```bash
# Source in all bash shells (not just login)
echo '[ -f /etc/profile.d/stream.sh ] && . /etc/profile.d/stream.sh' >> /etc/bash.bashrc

# Preserve environment with sudo
echo 'Defaults env_keep += "FQDN MYSQL_* TWITCH_* HAPROXY_VERSION MYSQL_VERSION NGINX_HTTP_VERSION NGINX_RTMP_VERSION PHP_FPM_VERSION DOCKER_USERNAME REGISTRY_URL DISCORD_*"' | sudo EDITOR='tee -a' visudo
```

**Verify environment is loaded:**
```bash
# Test in new shell
bash -c 'echo $FQDN'
# Should output your domain name

# Test with sudo
sudo bash -c 'echo $MYSQL_ROOT_PASSWORD'
# Should output your password
```

### Step 3: Build Docker Images

The system uses custom Docker images for each component.

```bash
cd tools
./build_all_images.sh v1.6

# Optional: Set custom timezone (defaults to UTC)
./build_all_images.sh v1.6 "--build-arg TZ=Europe/Helsinki"
```

**What this does:**
- Builds images for haproxy, mysql, nginx-http, nginx-rtmp, php-fpm
- Tags images with version number
- Pushes to your container registry (GitLab by default)

**Notes:**
- If not using GitLab registry, edit `build_all_images.sh` to change the registry URL
- Containers default to UTC timezone. See [Building Images](Building-Images.md#configuring-timezone) for timezone options

### Step 4: Initialize Database

Start the MySQL container:
```bash
./containermod --start --name mysql
```

**The database schema is automatically initialized on first start.** Wait ~10 seconds for MySQL to complete initialization.

**Verify database:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e "SHOW TABLES;"
```

You should see: `broadcasts`, `broadcast_channels`, `casters`, `channels`, `games`, `streams`.

### Step 5: Add Platform Channels

Channels are reusable platform destinations (Twitch, Instagram, YouTube, Facebook). Create channels using `channelmod`.

**Twitch (with API for auto-fetch):**
```bash
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"
./channelmod --set my_twitch display_name "My Twitch Channel"
```

**Instagram (manual key only):**
```bash
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./channelmod --set my_instagram stream_key "<instagram_stream_key>"
./channelmod --set my_instagram display_name "My Instagram"
```

**YouTube (with API for auto-fetch):**
```bash
./channelmod --create my_youtube youtube rtmp://a.rtmp.youtube.com/live2
./channelmod --set my_youtube client_id "$YOUTUBE_CLIENT_ID"
./channelmod --set my_youtube client_secret "$YOUTUBE_CLIENT_SECRET"
./channelmod --set my_youtube refresh_token "$YOUTUBE_REFRESH_TOKEN"
./channelmod --set my_youtube display_name "My YouTube"
```

**Facebook (manual key only):**
```bash
./channelmod --create my_facebook facebook rtmps://live-api-s.facebook.com:443/rtmp
./channelmod --set my_facebook stream_key "<facebook_stream_key>"
./channelmod --set my_facebook display_name "My Facebook"
```

**View all channels:**
```bash
./channelmod --list
```

**Note:** Twitch and YouTube support API auto-fetch (keys fetched at container start). Instagram and Facebook require manual stream keys.

### Step 6: Create Broadcasts and Link Channels

Broadcasts are RTMP ingress points with ports (48001-48010). Link channels to broadcasts to create output streams.

**Create a broadcast:**
```bash
./broadcastmod --create main-show 48001 "Main Show"
```

**Link channels to the broadcast:**
```bash
./broadcastmod --link main-show my_twitch
./broadcastmod --link main-show my_instagram
./broadcastmod --link main-show my_youtube
```

**Create additional broadcasts:**
```bash
./broadcastmod --create evening-cast 48002 "Evening Cast"
./broadcastmod --link evening-cast my_twitch

./broadcastmod --create tournament 48003 "Tournament"
./broadcastmod --link tournament my_twitch
./broadcastmod --link tournament my_facebook
```

**View all broadcasts:**
```bash
./broadcastmod --list
```

**Port Assignment:**
- Main broadcasts: 48001-48010 (for normal streams)
- Proxy broadcasts: 48101-48110 (for internal relay, pre-configured)

### Step 7: Start Base Infrastructure

Start all base containers (haproxy, nginx-http, php-fpm):
```bash
./containermod --start --all
```

This will:
- Start HAProxy with Let's Encrypt SSL certificate provisioning
- Start nginx-http web server
- Start php-fpm for authentication
- MySQL is already running from Step 4

**Verify all containers are running:**
```bash
docker ps
```

You should see: `haproxy`, `nginx-http`, `php-fpm`, `mysql`.

### Step 8: Add Streamers (Casters)

Add each streamer who will use the system:

```bash
./castermod --add JohnDoe 123456789012345678
```

Where:
- `JohnDoe` is the streamer's nickname
- `123456789012345678` is their Discord user ID (optional, for notifications)

This will:
- Create a database entry
- Generate a unique stream key (e.g., `JohnDoe-abc123def456`)
- Output the full RTMP connection details

**View all casters:**
```bash
./castermod --list
```

### Step 9: Add Games

Add games that will be streamed:

```bash
./gamemod --add
```

Follow the interactive prompts:
- **Technical name**: Short identifier (e.g., `csgo`, `pubg`, `lol`)
- **Display name**: Must match Twitch exactly (e.g., `Counter-Strike: Global Offensive`)
- **Abbreviation**: Short form (e.g., `CS:GO`)
- **Delay**: Seconds (0 for instant, 480 for 8 minutes)

**Example games:**
```bash
# Counter-Strike with 8-minute delay
./gamemod --add csgo "Counter-Strike: Global Offensive" "CS:GO" 480

# League of Legends with no delay
./gamemod --add lol "League of Legends" "LoL" 0

# PUBG with 8-minute delay
./gamemod --add pubg "PlayerUnknown's Battlegrounds" "PUBG" 480
```

### Step 10: Schedule Streams

Schedule a stream:

```bash
./streammod --add
```

Follow the interactive prompts:
- **Caster**: Select from list
- **Channel**: Select from list (or use cocaster feature)
- **Game**: Select from list
- **Start time**: Format `DD.MM.YYYY HH:MM` (EU) or `MM/DD/YYYY HH:MM` (US)
- **End time**: Same format

**Important:**
- Containers automatically start **30 minutes before** scheduled time
- Containers automatically stop **30 minutes after** scheduled time
- Times are in server local time

**View scheduled streams:**
```bash
./streammod --upcoming   # Future streams
./streammod --live       # Currently active
```

### Step 11: Set Up Automation

Add cron job to automatically manage containers based on schedules:

```bash
sudo crontab -e
```

Add this line:
```cron
*/5 * * * * source /etc/profile.d/stream.sh && /opt/rtmp-proxy-server/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

This runs every 5 minutes and:
- Starts containers for upcoming streams
- Stops containers for finished streams
- Sends Discord notifications

**Monitor cron execution:**
```bash
tail -f /var/log/stream-cron.log
```

## Post-Installation

### Test Streaming

1. Start a test stream container:
```bash
cd tools
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
```

2. Configure OBS:
   - **Server:** `rtmp://stream.yourdomain.com:48001/JohnDoe/`
   - **Stream Key:** `JohnDoe-abc123def456` (get from castermod)

3. Start streaming in OBS

4. Check output on linked platform channels (Twitch, Instagram, etc.)

5. Stop container:
```bash
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

### Add Advertisements (Optional)

Place advertisement images in `nginx-http/html/ads/img/`:

```bash
cd nginx-http/html/ads/img

# Common ads (shown on all streams)
mkdir -p common
cp /path/to/ad1.png common/

# Game-specific ads
mkdir -p csgo pubg lol
cp /path/to/csgo-sponsor.jpg csgo/
cp /path/to/pubg-tournament.png pubg/
```

**Requirements:**
- File format: `.png` or `.jpg` (lowercase extensions only)
- Recommended size: 1920x1080 or 1280x720

**Rebuild nginx-http** after adding ads:
```bash
cd tools
./containermod --restart --name nginx-http
```

Ads are served at: `https://stream.yourdomain.com/ads/?game=csgo`

**Note:** Let's Encrypt certificates are automatically renewed by the HAProxy container (checks every 12 hours).

## Upgrading

### Database Schema Upgrades

When upgrading to a new version, apply any new schema changes:

```bash
cd mysql/db/upgrade/v1.X
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < upgrade.sql
```

### Container Updates

Update to new container versions:

```bash
# Update version in environment
export HAPROXY_VERSION="v1.7"
export NGINX_RTMP_VERSION="v1.7"
# ... update all versions

# Rebuild images
cd tools
./build_all_images.sh v1.7

# Restart all containers (ensure no active streams first)
./containermod --restart --all
```

## Next Steps

- Read [Architecture](Architecture) to understand how the system works
- Review [Configuration](Configuration) for advanced settings
- Check [Management Tools](Management-Tools) for all available commands
- Set up monitoring (see [Troubleshooting](Troubleshooting#monitoring))

---

[Back to Wiki Home](Home)
