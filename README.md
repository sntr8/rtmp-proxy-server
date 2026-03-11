# RTMP Proxy Server

A Docker-based RTMP streaming proxy service that sits between streamers and multiple platforms (Twitch, Instagram, Facebook, YouTube), providing centralized stream management, authentication, configurable delays, and automated scheduling.

## Features

- **Multi-Platform Support**: Stream to Twitch, Instagram Live, Facebook Live, and YouTube simultaneously or independently
- **Centralized Authentication**: Manage streamer access—masks channel keys from streamers
- **Configurable Delay**: Apply per-game stream delays (e.g., 8 minutes for competitive games)
- **Multi-Channel Support**: Route multiple streamers to different channels across platforms
- **Scheduled Streams**: Automate container startup/shutdown based on schedules
- **Discord Integration**: Automated notifications for stream events
- **Web-Based Ads**: Serve rotating advertisements via HTTP endpoint
- **HAProxy Routing**: Dynamic RTMP traffic routing with graceful reloads
- **Database-Driven**: MySQL backend for casters, channels, games, and schedules

## Quick Start

### Prerequisites

- Linux server with Docker installed
- Domain name pointing to your server
- Platform account(s):
  - **Twitch**: API credentials (client_id, access_token, refresh_token)
  - **Instagram/Facebook/YouTube**: Stream keys from platform
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

# 5. Add platform channels (destinations)
# Twitch channel
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --set my_twitch access_token "$TWITCH_ACCESS_TOKEN"
./channelmod --set my_twitch client_id "$TWITCH_CLIENT_ID"
./channelmod --set my_twitch refresh_token "$TWITCH_REFRESH_TOKEN"

# Optional: Add other platforms
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp

# 6. Create broadcast (RTMP ingress point)
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch

# 7. Start base infrastructure
./containermod --start --all

# 8. Add streamers
./castermod --add JohnDoe 123456789012345678

# 9. Schedule streams
./streammod --add
```

### Usage

Streamers connect to your broadcast:
```
Server:      rtmp://stream.yourdomain.com:48001/JohnDoe/
Stream Key:  JohnDoe-abc123def456
```

Port mapping: **48001-48010** for broadcasts, **48101-48110** for proxy broadcasts.

The broadcast (port 48001) outputs to all linked channels (Twitch, Instagram, YouTube, etc.).

## Documentation

- **[Wiki](../../wiki)** - Detailed documentation, architecture, configuration, troubleshooting
- **[USER_GUIDE.md](USER_GUIDE.md)** - Guide for streamers

### Wiki Pages

- [Home](../../wiki/Home) - Overview and getting started
- [Installation](../../wiki/Installation) - Step-by-step setup guide
- [Ansible Deployment](../../wiki/Ansible-Deployment) - Automated deployment
- [Architecture](../../wiki/Architecture) - How the system works
- [Configuration](../../wiki/Configuration) - Games, channels, tokens, ads
- [Management Tools](../../wiki/Management-Tools) - Command reference
- [Building Images](../../wiki/Building-Images) - Build and distribute Docker images
- [Troubleshooting](../../wiki/Troubleshooting) - Common issues and solutions
- [FAQ](../../wiki/FAQ) - Frequently asked questions

## Management Tools

Comprehensive scripts in `tools/`:

- **containermod** - Start/stop/restart containers
- **streammod** - Schedule and manage streams
- **broadcastmod** - Manage broadcasts (RTMP ingress points)
- **channelmod** - Manage platform channels (Twitch, Instagram, YouTube, Facebook)
- **castermod** - Add/remove/manage streamers
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

Copyright (c) 2026 sntr8

**This project's original code** (shell scripts, configurations, Dockerfiles, and custom applications) is licensed under the **PolyForm Noncommercial License 1.0.0**.

You are free to use, modify, and share this software for noncommercial purposes (personal projects, academic research, hobbyist communities). Commercial use is prohibited.

See the [LICENSE](LICENSE) file or visit [polyformproject.org/licenses/noncommercial/1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/).

### Third-Party Components

This project uses the following open-source software in Docker images:

- **nginx** - BSD-2-Clause License ([nginx.org/LICENSE](https://nginx.org/LICENSE))
- **nginx-rtmp-module** - BSD-2-Clause License ([GitHub](https://github.com/arut/nginx-rtmp-module))
- **HAProxy** - GPL v2 ([haproxy.org](https://www.haproxy.org/))
- **MySQL** - GPL v2 ([mysql.com](https://www.mysql.com/))
- **PHP** - PHP License v3.01 ([php.net/license](https://www.php.net/license/3_01.txt))
- **Alpine Linux** - Various licenses ([alpinelinux.org/about](https://alpinelinux.org/about))

Each component retains its original license. The project's code works with these components but does not modify or redistribute their source code.

## Credits

**sntr8**

Originally developed for managing multiple game casters streaming to Twitch channels with competitive delay requirements for Kanaliiga.
