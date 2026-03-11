# Frequently Asked Questions

Quick answers to common questions. For technical deep-dives, see [Architecture](Architecture).

## Architecture & Design

### Why use port-based routing instead of standard RTMP on port 1935?

HAProxy operates at Layer 4 (TCP) and cannot parse RTMP application names embedded in Layer 7. Each broadcast gets a dedicated port for routing.

See [Architecture - Port-Based Routing](Architecture#why-port-based-routing) for details.

### Can Traefik do RTMP routing better than HAProxy?

No. Traefik has the same Layer 4 limitation—it cannot parse RTMP application names.

### Why not use a single nginx-rtmp container for all streams?

Isolation, flexibility, reliability, security, and independent scheduling. Each caster gets their own isolated container.

See [Architecture - Container Architecture](Architecture#container-architecture) for details.

### How does the delay system work?

nginx-rtmp records to timestamped files, Python script waits for delay period, then pipes file to FFmpeg for delayed publishing.

See [Architecture - Stream Delay Implementation](Architecture#stream-delay-implementation) for full explanation.

## Capacity & Scaling

### How many concurrent streams can the system handle?

Depends on server resources. Per stream: ~100-200 MB RAM, ~5-10% CPU (passthrough), ~5 Mbps upload bandwidth.

Example: 8GB RAM, 4 cores, 100 Mbps → ~15-20 concurrent streams.

See [Architecture - Scalability](Architecture#scalability-considerations) for details.

### How many broadcasts can I add?

Current: 10 regular (48001-48010) + 10 proxy (48101-48110). Channels have no limit.

To expand: Add port ranges in HAProxy, update firewall, create broadcasts with new ports.

### Can I run multiple RTMP Proxy servers?

Yes, with shared MySQL and unique port ranges per server. Not recommended: load balancing RTMP or shared delay storage.

See [Architecture - Scaling Up](Architecture#scaling-up) for details.

### What about stream delay files filling disk?

Files auto-deleted after publish. If crashes leave orphaned files, add cron cleanup:
```bash
0 2 * * * find /opt/rtmp/workdir -name "*.flv" -mtime +1 -delete
```

## Security & Access

### Are Twitch stream keys secure?

Yes. Streamers use personal auth keys (`<nick>-<random>`), never see actual platform keys. Platform keys stored in MySQL.

See [Architecture - Authentication System](Architecture#authentication-system) for details.

### How do I revoke a streamer's access?

```bash
cd tools
./castermod --remove <nickname>
```

Immediate revocation. Does not affect platform keys or other streamers.

### Can streamers see each other's streams?

No, containers are isolated. Optional VLC viewer for internal watching.

### Should I change default passwords?

Yes, immediately. Set MySQL root/user passwords in `/etc/profile.d/stream.sh`. Add HAProxy stats password. Never commit passwords to Git.

## Operations & Maintenance

### How often do Twitch tokens expire?

~60 days. Set up automated refresh via crontab:
```bash
0 2 * * 0 /path/to/tools/channelmod --refresh-tokens my_twitch >> /var/log/token-refresh.log 2>&1
```

See [Configuration - Twitch API Tokens](Configuration#twitch-api-tokens).

### What happens if a stream goes overtime?

Container stops 30 min after scheduled end. Extend with:
```bash
./streammod --extend <stream_id>
```

Manually started containers run indefinitely.

### Can I manually start/stop containers?

Yes:
```bash
cd tools
./containermod --start --name nginx-rtmp --caster JohnDoe --broadcast main-show --game csgo
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

Manual and automated scheduling coexist independently.

### How do I upgrade to a new version?

1. Backup database: `docker exec mysql mysqldump ... > backup.sql`
2. Pull code: `git pull origin main`
3. Apply migrations: `docker exec -i mysql mysql ... < upgrade.sql`
4. Update versions in `/etc/profile.d/stream.sh`
5. Rebuild: `cd tools && ./build_all_images.sh v1.X`
6. Restart containers (HAProxy is graceful, MySQL needs off-hours)

### What happens during maintenance?

- **HAProxy**: Graceful reload, streams continue
- **nginx-http/php-fpm**: Brief downtime (~5s)
- **MySQL**: Impacts all services (off-hours only)
- **Stream containers**: Drops connection, streamer must reconnect

## Troubleshooting Scenarios

### Streams work locally but not from OBS

Likely firewall blocking ports. Test: `telnet stream.yourdomain.com 48001`

Open ports in cloud security groups or local firewall.

### Stream connects but Twitch shows "Offline"

Wrong stream key or FFmpeg relay failure. Check logs:
```bash
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/ffmpeg-twitch.log
```

Update stream key in database, restart container.

### Advertisements not showing in OBS

Check: lowercase `.png`/`.jpg` extensions, correct directory, nginx-http restarted, correct OBS URL. Test in browser first.

### Delay is inconsistent

Server clock drift or disk I/O lag. Sync with NTP: `sudo timedatectl set-ntp true`

Check disk: `iostat -x 1`

See [Troubleshooting](Troubleshooting) guide for more.

## Technical Details

### What RTMP library does this use?

**nginx-rtmp-module** by arut. Mature, production-ready RTMP module for nginx.

### Why Python for stream_delayer.py?

Simple threading, easy Docker integration, no compilation needed.

### How is authentication implemented?

nginx-rtmp calls `auth.php` on publish/play → queries MySQL → returns 200 (accept) or 403 (reject).

See [Architecture - Authentication System](Architecture#authentication-system) for details.

### What's the latency impact of delay?

With delay: ~7-16s + configured delay
Without delay: ~5-15s total

See [Architecture - Stream Delay](Architecture#stream-delay-implementation) for breakdown.

### Can I stream to multiple platforms?

**Yes!** Create channels (platforms) → Create broadcast → Link channels to broadcast → Stream outputs to all platforms simultaneously.

**Supported:** Twitch, Instagram, Facebook, YouTube

**Quick setup:**
```bash
cd tools
./channelmod --create my_twitch twitch rtmp://live.twitch.tv/app
./channelmod --create my_instagram instagram rtmp://live-upload.instagram.com:80/rtmp
./broadcastmod --create main-show 48001 "Main Show"
./broadcastmod --link main-show my_twitch
./broadcastmod --link main-show my_instagram
# Streaming to port 48001 now outputs to both platforms
```

See [Configuration - Platform Configuration](Configuration#platform-configuration) and [Architecture - Many-to-Many Model](Architecture#many-to-many-broadcast-architecture).

## Platform-Specific Questions

### What are the differences between platforms?

| Platform | Auto-Fetch Keys | OBS Keyframes | Notes |
|----------|----------------|---------------|-------|
| **Twitch** | ✅ (with API) | Any | Full API support |
| **YouTube** | ✅ (with API) | 2-4s | OAuth2 required |
| **Instagram** | ❌ Manual only | 2s (required) | Keepalive pings critical |
| **Facebook** | ❌ Manual only | 2s (required) | Manual keys only |

See [Configuration - Platform Configuration](Configuration#platform-configuration).

### Why did my Instagram stream stop after 10 minutes?

Fixed! Added keepalive pings (`ping 30s`). Rebuild nginx-rtmp with latest templates.

### What OBS settings should I use for Instagram/Facebook?

**Critical:** Keyframe Interval: 2 seconds
Also: H.264, CBR, 3000-4000 kbps, AAC 44.1kHz

YouTube can use 2-4s keyframes.

### Can I use scheduled streams with Instagram/Facebook/YouTube?

**Yes!** Store stream keys in database via `channelmod --set <channel> stream_key`. Keys auto-loaded at container start.

Twitch/YouTube with API credentials auto-fetch keys. Instagram/Facebook always use stored keys (no API).

## Miscellaneous

### Why PolyForm Noncommercial License?

Allows free use for personal, community, academic, and hobbyist projects. Prohibits commercial exploitation. Contact author for commercial license.

### Can I contribute?

Yes! Fork → feature branch → test → pull request. See [README - Contributing](../README.md#contributing).

### Is there a hosted/managed version?

No, self-hosted only. Full control, no recurring costs, privacy, customizable.

### Where can I get help?

1. [Troubleshooting Guide](Troubleshooting)
2. [Architecture](Architecture) (understand how it works)
3. [GitHub Issues](https://github.com/sntr8/rtmp-proxy-server/issues)
4. Open issue with problem description, logs, system info

---

[Back to Wiki Home](Home)
