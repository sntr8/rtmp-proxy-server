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
  - Optional: Port 8404 (HAProxy stats dashboard)

### Twitch Requirements
- Twitch account(s) for channels you want to stream to
- Twitch API credentials (Client ID, Access Token, Refresh Token)
  - Get these from [twitchtokengenerator.com](https://twitchtokengenerator.com)
  - Requires: `channel:manage:broadcast`, `channel:read:stream_key` scopes

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
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ../mysql/db/schema.sql

# Add channel and start
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES ('yourchannel', 'YourChannel', '$TWITCH_ACCESS_TOKEN', '$TWITCH_CLIENT_ID',
   '$TWITCH_REFRESH_TOKEN', DATE_ADD(NOW(), INTERVAL 60 DAY), 48001, 'https://twitch.tv/yourchannel')"
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
export DISCORD_SUPPORT_GROUP="discord_role_or_user_id"

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
```

**What this does:**
- Builds images for haproxy, mysql, nginx-http, nginx-rtmp, php-fpm
- Tags images with version number
- Pushes to your container registry (GitLab by default)

**Note:** If not using GitLab registry, edit `build_all_images.sh` to change the registry URL.

### Step 4: Initialize Database

Start the MySQL container:
```bash
./containermod --start --name mysql
```

Wait 10 seconds for MySQL to initialize, then create the database schema:
```bash
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ../mysql/db/schema.sql
```

**Verify database:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e "SHOW TABLES;"
```

You should see: `casters`, `channels`, `games`, `streams`.

### Step 5: Add Twitch Channels

Add each Twitch channel you want to stream to.

**IMPORTANT:** Each Twitch channel requires **its own unique credentials** (access token, client ID, refresh token). You must obtain separate credentials from [twitchtokengenerator.com](https://twitchtokengenerator.com) for each channel.

**First channel** (using environment variables):
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES (
     'yourchannel',                    # Twitch channel name (lowercase)
     'YourChannel',                    # Display name (matches Twitch exactly)
     '$TWITCH_ACCESS_TOKEN',           # From environment variable
     '$TWITCH_CLIENT_ID',              # From environment variable
     '$TWITCH_REFRESH_TOKEN',          # From environment variable
     DATE_ADD(NOW(), INTERVAL 60 DAY), # Token expiry (60 days)
     48001,                            # Port for this channel (48001-48010)
     'https://twitch.tv/yourchannel'   # Channel URL
   )"
```

**Additional channels** (must use channel-specific credentials):
```bash
# Get credentials for second channel from twitchtokengenerator.com
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES (
     'secondchannel',                     # Different Twitch channel
     'SecondChannel',
     'second_channel_access_token_here',  # DIFFERENT credentials
     'second_channel_client_id_here',     # DIFFERENT credentials
     'second_channel_refresh_token_here', # DIFFERENT credentials
     DATE_ADD(NOW(), INTERVAL 60 DAY),
     48002,                               # Different port
     'https://twitch.tv/secondchannel'
   )"
```

**Port Assignment:**
- First channel: 48001
- Second channel: 48002
- Third channel: 48003
- etc.

**For proxy-only channels** (internal relay, no Twitch output):
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, port, url)
   VALUES ('only1-proxy', 'Proxy Channel 1', 48101, '')"
```

### Step 6: Start Base Infrastructure

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

**Check HAProxy stats:**
```
https://stream.yourdomain.com:8404/stats
```

### Step 7: Add Streamers (Casters)

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

### Step 8: Add Games

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

### Step 9: Schedule Streams

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

### Step 10: Set Up Automation

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
./containermod --start --name nginx-rtmp --caster JohnDoe --channel yourchannel --game csgo
```

2. Configure OBS:
   - **Server:** `rtmp://stream.yourdomain.com:48001/JohnDoe/`
   - **Stream Key:** `JohnDoe-abc123def456` (get from castermod)

3. Start streaming in OBS

4. Check Twitch channel for output

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

### Configure Let's Encrypt Auto-Renewal

Let's Encrypt certificates expire after 90 days. Add auto-renewal:

```bash
sudo crontab -e
```

Add:
```cron
0 3 * * * docker exec haproxy /usr/local/bin/certbot renew --quiet
```

This checks daily at 3 AM and renews if needed (certificates renew when <30 days remain).

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

# Restart containers (one at a time to minimize downtime)
./containermod --restart --name haproxy
./containermod --restart --name nginx-http
./containermod --restart --name php-fpm
# MySQL restart requires caution - ensure no active streams
```

## Troubleshooting Installation

### MySQL Won't Start

**Error:** `Can't connect to MySQL server`

**Solution:**
```bash
# Check logs
docker logs mysql

# Common issues:
# - Wrong root password in environment
# - Port 3306 already in use
# - Insufficient memory

# Restart with logs
docker stop mysql
docker rm mysql
./containermod --start --name mysql
docker logs -f mysql
```

### HAProxy SSL Errors

**Error:** Let's Encrypt validation fails

**Solution:**
```bash
# Ensure ports 80 and 443 are open in firewall
# Ensure DNS points to server IP
# Check HAProxy logs
docker logs haproxy

# Manual certificate request
docker exec -it haproxy /usr/local/bin/certbot certonly --standalone -d stream.yourdomain.com
```

### Build Script Fails

**Error:** Docker build fails or push fails

**Solution:**
```bash
# Check Docker is running
sudo systemctl status docker

# Check registry credentials
docker login registry.gitlab.com

# Build individual container for debugging
cd haproxy
docker build -t haproxy:test .
```

### Container Won't Start

**Error:** `containermod --start` fails

**Solution:**
```bash
# Check environment variables are loaded
echo $FQDN
echo $MYSQL_ROOT_PASSWORD

# Check Docker network
docker network ls

# Try starting manually
docker run -d --name test-container image-name
docker logs test-container
```

For more troubleshooting, see [Troubleshooting Guide](Troubleshooting).

## Next Steps

- Read [Architecture](Architecture) to understand how the system works
- Review [Configuration](Configuration) for advanced settings
- Check [Management Tools](Management-Tools) for all available commands
- Set up monitoring (see [Troubleshooting](Troubleshooting#monitoring))

---

[Back to Wiki Home](Home)
