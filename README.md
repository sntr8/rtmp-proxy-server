# RTMP Proxy Server

A Docker-based RTMP streaming proxy service that sits between streamers and Twitch, providing centralized stream management, authentication, configurable delays, and automated scheduling.

## Features

- **Centralized Authentication**: Manage streamer access without sharing Twitch stream keys
- **Configurable Delay**: Apply per-game stream delays (e.g., 8 minutes for competitive games)
- **Multi-Channel Support**: Route multiple streamers to different Twitch channels
- **Scheduled Streams**: Automate container startup/shutdown based on schedules
- **Discord Integration**: Automated notifications for stream events
- **Web-Based Ads**: Serve rotating advertisements via HTTP endpoint
- **HAProxy Routing**: Dynamic RTMP traffic routing with graceful reloads
- **Database-Driven**: MySQL backend for casters, channels, games, and schedules

## Architecture

The service consists of several Docker containers:

**Base Infrastructure:**
- **HAProxy**: Front-end proxy handling RTMP traffic routing and HTTPS
- **MySQL**: Database storing casters, channels, games, and stream schedules
- **nginx-http**: HTTP server for authentication (auth.php) and ad serving (/ads/)
- **php-fpm**: PHP processor for authentication and ad rotation scripts

**Per-Stream Containers (created dynamically):**
- **nginx-rtmp-\<caster\>**: RTMP relay for game streams (with or without delay)
- **nginx-rtmp-proxy-\<caster\>**: Internal proxy containers (no Twitch output)

### RTMP Routing Architecture

**Important:** RTMP traffic routing is based on dedicated ports per channel, not dynamic application parsing.

```
Streamers → HAProxy → nginx-rtmp containers → Twitch

Port Ranges:
- 48001-48010: Regular stream channels (to Twitch)
- 48101-48110: Proxy-only channels (internal relay)
```

**How it works:**
1. Each Twitch channel is assigned a dedicated port (e.g., 48001 for main channel)
2. HAProxy routes traffic from that port to the appropriate nginx-rtmp-\<caster\> container
3. Streamers connect to: `rtmp://stream.example.com:48001/<caster>/<stream-key>`
4. The nginx-rtmp container authenticates via auth.php and relays to Twitch

**Why port-based routing?**
- RTMP is a Layer 7 protocol with application names embedded in the handshake
- HAProxy in TCP mode cannot parse RTMP application names for routing decisions
- Port-based routing is simple, reliable, and requires no protocol inspection
- Each channel gets its own port, HAProxy routes based on destination port

**Dynamic Configuration:**
- When a container starts, `haproxy_configmod` adds routing rules to HAProxy
- HAProxy reloads gracefully (HUP signal) without interrupting existing streams
- When a container stops, routing rules are removed and HAProxy reloads again

## Prerequisites

- Linux server with Docker installed
- Domain name pointing to your server
- Twitch account(s) with API credentials (from [twitchtokengenerator.com](https://twitchtokengenerator.com))
- At least 2GB RAM, 10GB disk space
- **Open ports (firewall/cloud security groups):**
  - `80` - HTTP (Let's Encrypt, redirects to HTTPS)
  - `443` - HTTPS (nginx-http web interface)
  - `48001-48010` - RTMP stream channels (Twitch output)
  - `48101-48110` - RTMP proxy channels (internal relay)
  - Optional: `8404` - HAProxy stats dashboard

**Note on RTMP ports:** Port 1935 (standard RTMP) is NOT used. Each channel requires a dedicated port in the 48001+ range for technical routing reasons (HAProxy cannot parse RTMP application names in TCP mode).

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/sntr8/rtmp-proxy-server.git
cd rtmp-proxy-server
```

### 2. Set Environment Variables

Create `/etc/profile.d/stream.sh` with required environment variables:

```bash
export FQDN="stream.yourdomain.com"
export ADMIN_EMAIL="admin@yourdomain.com"

# MySQL Configuration
export MYSQL_ROOT_PASSWORD="your_secure_root_password"
export MYSQL_USER="stream_user"
export MYSQL_PASSWORD="your_secure_password"
export MYSQL_DATABASE="stream"

# Twitch API (get from twitchtokengenerator.com)
export TWITCH_CLIENT_ID="your_client_id"
export TWITCH_ACCESS_TOKEN="your_access_token"
export TWITCH_REFRESH_TOKEN="your_refresh_token"

# GitLab for HAProxy config (optional)
export GIT_USER="your_gitlab_user"
export GIT_TOKEN="your_gitlab_token"
export CONFIG_BRANCH="master"

# Discord Webhooks (optional)
export DISCORD_WEBHOOK="your_discord_webhook_url"
export DISCORD_SUPPORT_GROUP="your_discord_tech_support_group_id"

# Container Versions
export HAPROXY_VERSION="v1.6"
export MYSQL_VERSION="v1.6"
export NGINX_HTTP_VERSION="v1.6"
export NGINX_RTMP_VERSION="v1.6"
export PHP_FPM_VERSION="v1.6"
```

Then load it:
```bash
source /etc/profile.d/stream.sh
```

### 3. Build Docker Images

```bash
cd tools
./build_all_images.sh v1.6
```

This builds and pushes images to your registry. Update the registry URL in the script if not using GitLab.

### 4. Initialize Database

```bash
# Start MySQL container
./containermod --start --name mysql

# Import schema
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < mysql/db/create/stream_mysql_create.sql

# Apply upgrades (if any)
for sql in mysql/db/upgrade/*/**.sql; do
    docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < "$sql"
done
```

### 5. Add Twitch Channels

```bash
# Add your Twitch channel(s) to database
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES ('yourchannel', 'YourChannel', '$TWITCH_ACCESS_TOKEN', '$TWITCH_CLIENT_ID',
   '$TWITCH_REFRESH_TOKEN', DATE_ADD(NOW(), INTERVAL 60 DAY), 48001, 'https://twitch.tv/yourchannel')"
```

### 6. Start Base Containers

```bash
./containermod --start --all
```

This starts:
- HAProxy (with Let's Encrypt SSL)
- nginx-http
- php-fpm
- MySQL (already started)

### 7. Add Casters

```bash
./castermod --add JohnDoe 123456789012345678
```

Where `123456789012345678` is the Discord user ID for notifications.

### 8. Schedule Streams

```bash
./streammod --add
```

Follow the interactive prompts to schedule streams. Containers will automatically start 30 minutes before and stop 30 minutes after scheduled times.

## Configuration

### Adding Games

```bash
./gamemod --add
```

Configure:
- **Technical name**: Short lowercase identifier (e.g., `pubg`, `csgo`)
- **Display name**: Must match Twitch exactly (e.g., `PlayerUnknown's Battlegrounds`)
- **Abbreviation**: Short form (e.g., `PUBG`)
- **Delay**: Seconds (0 for instant, 480 for 8 minutes)

### Managing Twitch Tokens

Tokens expire after 60 days. Refresh them:

```bash
./channelmod --refresh-tokens yourchannel
```

Or manually update:

```bash
./channelmod --set yourchannel access_token "new_token"
./channelmod --set yourchannel refresh_token "new_refresh_token"
```

### Adding Advertisements

Place images in `nginx-http/html/ads/img/`:
- `common/` - Shown on all streams
- `pubg/`, `csgo/`, `rl/` - Game-specific ads

Images must be `.png` or `.jpg` (lowercase). Rebuild nginx-http container after adding ads.

### Understanding HAProxy Port Routing

**Channel → Port Mapping:**

When you add a channel to the database, you assign it a port:

```sql
INSERT INTO channels (name, display_name, port, url)
VALUES ('mainchannel', 'MainChannel', 48001, 'https://twitch.tv/mainchannel');
```

**HAProxy Configuration:**

When a stream container starts, `haproxy_configmod` adds a configuration block:

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

**What happens:**
1. HAProxy listens on port 48001
2. All traffic to port 48001 → `nginx-rtmp-JohnDoe` container on internal port 1935
3. Container authenticates and relays to Twitch

**Multiple streamers, same channel:**
- If JaneDoe streams later to the same channel (48001), her container also uses port 48001
- Only one container per channel can run at a time (enforced by scheduling)
- HAProxy config is updated when containers start/stop (graceful reload)

**Checking current routing:**

```bash
# View HAProxy configuration
cat /opt/haproxy/haproxy.cfg | grep "::.*::"

# List active routes
docker exec haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep -A 6 "frontend rtmp-"
```

## Usage

### For Streamers

Streamers connect their OBS to HAProxy with a channel-specific port:

```
Server:      rtmp://stream.yourdomain.com:PORT/<nickname>/
Stream Key:  <nickname>-<stream-key>
```

**Example:**
```
Server:      rtmp://stream.yourdomain.com:48001/JohnDoe/
Stream Key:  JohnDoe-abc123def456
```

**Port Assignment:**
- **48001-48010**: Regular channels (streams to Twitch)
- **48101-48110**: Proxy channels (internal relay only)

Each Twitch channel in your database has a pre-assigned port. Query with:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, port FROM channels WHERE name NOT LIKE '%proxy%'"
```

For detailed streamer instructions, see [USER_GUIDE.md](USER_GUIDE.md).

### Manual Container Management

```bash
# Start a stream container manually
./containermod --start --name nginx-rtmp --caster JohnDoe --channel yourchannel --game pubg

# Stop a stream container
./containermod --stop --name nginx-rtmp --caster JohnDoe

# List running containers
./containermod --list

# Restart base infrastructure
./containermod --restart --all
```

### View Scheduled Streams

```bash
# Upcoming streams
./streammod --upcoming

# Currently live
./streammod --live

# Extend a stream
./streammod --extend <stream_id>
```

## Automation

The service uses cron to automatically start/stop containers based on schedules. Add to crontab:

```bash
*/5 * * * * /path/to/tools/cron_worker.sh >> /var/log/stream-cron.log 2>&1
```

## Management Tools

Comprehensive management scripts in `tools/`:

- **containermod**: Start/stop/restart containers
- **streammod**: Schedule and manage streams
- **castermod**: Add/remove/manage streamers
- **channelmod**: Manage Twitch channels and API tokens
- **gamemod**: Add/list games
- **haproxy_configmod**: Manage HAProxy routing (usually automatic)
- **discordmod**: Send Discord notifications (usually automatic)

Run `<tool> --help` for detailed usage.

## Documentation

- **[admin.md](admin.md)**: Comprehensive administration guide (Finnish)
- **tools/*/--help**: Built-in help for each management script
- **[USER_GUIDE.md](USER_GUIDE.md)**: Guide for streamers (create this for your users)

## Troubleshooting

See [admin.md](admin.md) for detailed troubleshooting, including:
- Connection failures
- HAProxy configuration issues
- Twitch API token problems
- Container startup failures
- SSL certificate renewal

### Common Questions

**Q: Why not use port 1935 (standard RTMP port) for all streams?**

A: HAProxy operates at Layer 4 (TCP) and cannot parse RTMP application names (e.g., `/JohnDoe/`) to route traffic. RTMP is a Layer 7 protocol where the application name is embedded in the handshake payload.

**Current approach:** One port per channel (48001-48110)
- ✅ Simple and reliable
- ✅ No protocol parsing needed
- ✅ Battle-tested in production
- ❌ Requires streamers to know their port

**Alternative (future consideration):** nginx-rtmp dispatcher
- Add a single nginx-rtmp frontend on port 1935
- Parse RTMP application names and proxy to backend containers
- ✅ Single port 1935 for all streamers
- ✅ Standard RTMP behavior
- ❌ Extra network hop (minimal latency)
- ❌ Dispatcher config must be updated when adding/removing casters

**Q: Can Traefik do RTMP routing better than HAProxy?**

A: No. Traefik also operates at Layer 4 for TCP routing and has the same limitation - it cannot parse RTMP application names. You would need the same multi-port approach or an nginx-rtmp dispatcher.

**Q: How do I add more channels beyond 48010?**

A: Add more ports to HAProxy configuration. The range 48001-48110 provides 20 stream ports and 10 proxy ports. Extend as needed:

```bash
# In haproxy/Dockerfile or runtime config
# Expose additional ports
EXPOSE 48011-48020
```

Then update channel database entries with new port assignments.

## Security Considerations

- Keep environment variables secure (never commit to Git)
- Use strong MySQL passwords
- Restrict SSH access to trusted IPs
- Keep Docker and base system updated
- Review HAProxy config for proper port restrictions
- Use Let's Encrypt for SSL (auto-configured by HAProxy container)

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**. 

You are free to use, modify, and share this software for noncommercial purposes (such as personal projects, academic research, or hobbyist communities). You may **not** use this software for commercial purposes, including selling it, using it to run a paid service, or incorporating it into a commercial product.

To view the full legal text of the license, see the [LICENSE](LICENSE) file or visit [https://polyformproject.org/licenses/noncommercial/1.0.0/](https://polyformproject.org/licenses/noncommercial/1.0.0/).

## Credits

sntr8

Originally developed for managing multiple game casters streaming to Twitch channels with competitive delay requirements for Kanaliiga.