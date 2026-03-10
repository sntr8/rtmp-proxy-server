# RTMP Proxy Server

A Docker-based RTMP streaming proxy service that sits between streamers and Twitch, providing centralized stream management, authentication, configurable delays, and automated scheduling.

## Features

- **Centralized Authentication**: Manage streamer access—masks Twitch channel keys from streamers
- **Configurable Delay**: Apply per-game stream delays (e.g., 8 minutes for competitive games)
- **Multi-Channel Support**: Route multiple streamers to different Twitch channels
- **Scheduled Streams**: Automate container startup/shutdown based on schedules
- **Discord Integration**: Automated notifications for stream events
- **Web-Based Ads**: Serve rotating advertisements via HTTP endpoint
- **HAProxy Routing**: Dynamic RTMP traffic routing with graceful reloads
- **Database-Driven**: MySQL backend for casters, channels, games, and schedules

## Quick Start

### Prerequisites

- Linux server with Docker installed
- Domain name pointing to your server
- Twitch account(s) with API credentials
- At least 2GB RAM, 10GB disk space
- **Open ports:** 80, 443, 48001-48010 (RTMP streams), 48101-48110 (RTMP proxies)

### Installation

```bash
# 1. Clone repository
git clone https://github.com/sntr8/rtmp-proxy-server.git
cd rtmp-proxy-server

# 2. Configure environment variables
sudo nano /etc/profile.d/stream.sh
# Set: FQDN, ADMIN_EMAIL, MYSQL credentials, TWITCH tokens, container versions
source /etc/profile.d/stream.sh

# 3. Build images
cd tools
./build_all_images.sh v1.6

# 4. Initialize database
./containermod --start --name mysql
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ../mysql/db/schema.sql

# 5. Add Twitch channel
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
   VALUES ('yourchannel', 'YourChannel', '$TWITCH_ACCESS_TOKEN', '$TWITCH_CLIENT_ID',
   '$TWITCH_REFRESH_TOKEN', DATE_ADD(NOW(), INTERVAL 60 DAY), 48001, 'https://twitch.tv/yourchannel')"

# 6. Start base infrastructure
./containermod --start --all

# 7. Add streamers
./castermod --add JohnDoe 123456789012345678

# 8. Schedule streams
./streammod --add
```

### Usage

Streamers connect to your proxy:
```
Server:      rtmp://stream.yourdomain.com:48001/JohnDoe/
Stream Key:  JohnDoe-abc123def456
```

Port mapping: **48001-48010** for regular streams, **48101-48110** for proxy-only channels.

## Documentation

- **[Wiki](../../wiki)** - Detailed documentation, architecture, configuration, troubleshooting
- **[admin.md](admin.md)** - Comprehensive administration guide
- **[userguide.md](userguide.md)** - Guide for streamers

### Wiki Pages

- [Home](../../wiki/Home) - Overview and getting started
- [Installation](../../wiki/Installation) - Step-by-step setup guide
- [Architecture](../../wiki/Architecture) - How the system works
- [Configuration](../../wiki/Configuration) - Games, channels, tokens, ads
- [Management Tools](../../wiki/Management-Tools) - Command reference
- [Troubleshooting](../../wiki/Troubleshooting) - Common issues and solutions
- [FAQ](../../wiki/FAQ) - Frequently asked questions

## Management Tools

Comprehensive scripts in `tools/`:

- **containermod** - Start/stop/restart containers
- **streammod** - Schedule and manage streams
- **castermod** - Add/remove/manage streamers
- **channelmod** - Manage Twitch channels and API tokens
- **gamemod** - Add/list games
- **haproxy_configmod** - Manage HAProxy routing
- **discordmod** - Send Discord notifications

Run `<tool> --help` for usage.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**.

You are free to use, modify, and share this software for noncommercial purposes (personal projects, academic research, hobbyist communities). Commercial use is prohibited.

See the [LICENSE](LICENSE) file or visit [polyformproject.org/licenses/noncommercial/1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/).

## Credits

**sntr8**

Originally developed for managing multiple game casters streaming to Twitch channels with competitive delay requirements for Kanaliiga.
