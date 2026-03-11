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
echo 'Defaults env_keep += "FQDN MYSQL_* HAPROXY_VERSION MYSQL_VERSION NGINX_HTTP_VERSION NGINX_RTMP_VERSION PHP_FPM_VERSION DOCKER_USERNAME REGISTRY_URL DISCORD_*"' | sudo EDITOR='tee -a' visudo

# Build and deploy
cd tools
./build_all_images.sh v1.6 "--build-arg TZ=Europe/Helsinki"  # Use your timezone
./containermod --start --name mysql
./containermod --start --all

# Set up automation
sudo crontab -e
# Add: */5 * * * * source /etc/profile.d/stream.sh && /opt/rtmp-proxy-server/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

**Next:** See [Configuration Guide](Configuration) to set up channels, broadcasts, casters, and streams.

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
echo 'Defaults env_keep += "FQDN MYSQL_* HAPROXY_VERSION MYSQL_VERSION NGINX_HTTP_VERSION NGINX_RTMP_VERSION PHP_FPM_VERSION DOCKER_USERNAME REGISTRY_URL DISCORD_*"' | sudo EDITOR='tee -a' visudo
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

# Build with your server's timezone (highly recommended)
./build_all_images.sh v1.6 "--build-arg TZ=Europe/Helsinki"

# Or build with default UTC
./build_all_images.sh v1.6
```

**What this does:**
- Builds images for haproxy, mysql, nginx-http, nginx-rtmp, php-fpm
- Tags images with version number
- Pushes to your container registry (GitLab by default)

**Timezone Configuration:**
- **Highly recommended:** Set `TZ` to match your server's timezone
- Without setting `TZ`, containers default to **UTC**
- If MySQL uses UTC and your server uses local time (e.g., `Europe/Helsinki`), scheduling streams becomes confusing:
  - Scheduling a stream for "19:30" will be interpreted as 19:30 UTC
  - If your timezone is UTC+2, the stream starts at 21:30 local time (2 hours late!)
- **To check your server timezone:** `timedatectl` or `date +%Z`
- Common timezones: `Europe/Helsinki`, `America/New_York`, `Asia/Tokyo`, `UTC`

**Notes:**
- If not using GitLab registry, edit `build_all_images.sh` to change the registry URL
- For advanced image building options see [Building Images](Building-Images.md)

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

### Step 5: Start Base Infrastructure

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

### Step 6: Set Up Automation

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

## Upgrading

### Database Schema Upgrades

When upgrading to a new version, apply any new schema changes:

```bash
cd mysql/db/upgrade/X
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

**Now configure your streaming setup:**
- **[Configuration Guide](Configuration)** - Set up channels, broadcasts, casters, and streams

**Additional resources:**
- [Architecture](Architecture) - Understand how the system works
- [Management Tools](Management-Tools) - All available commands
- [Troubleshooting](Troubleshooting) - Common issues and solutions

---

[Back to Wiki Home](Home)
