# Frequently Asked Questions

Common questions about RTMP Proxy Server.

## Architecture & Design

### Why use port-based routing instead of standard RTMP on port 1935?

**Technical reason:** HAProxy operates at Layer 4 (TCP mode) and cannot parse RTMP application names (e.g., `/JohnDoe/`) which are embedded in the Layer 7 protocol handshake. RTMP application routing requires parsing the actual protocol payload, which HAProxy doesn't support in TCP mode.

**Current approach:**
- Each channel gets a dedicated port (48001-48010 for streams, 48101-48110 for proxies)
- HAProxy routes based on destination port (Layer 4 decision)
- Simple, reliable, battle-tested in production
- Streamer needs to know their channel's port

**Alternative (not implemented):**
Add an nginx-rtmp dispatcher on port 1935 that parses application names and proxies to backend containers. This adds an extra network hop but provides standard RTMP behavior (single port for all streams).

### Can Traefik do RTMP routing better than HAProxy?

No. Traefik also operates at Layer 4 for TCP routing and has the same limitation—it cannot parse RTMP application names for routing decisions. You would need the same multi-port approach or an nginx-rtmp dispatcher frontend.

### Why not use a single nginx-rtmp container for all streams?

**Isolation:** Each streamer gets their own container with isolated resources and configuration.

**Flexibility:** Different games require different configurations (delay vs. instant streaming).

**Reliability:** If one container crashes, it doesn't affect other streams.

**Security:** Streamers are isolated from each other at the container level.

**Scheduling:** Containers can be automatically started/stopped based on schedules without affecting others.

### How does the delay system work?

1. Streamer publishes to nginx-rtmp container
2. nginx-rtmp records stream to `.flv` file with Unix timestamp in filename (e.g., `stream-1710345678.flv`)
3. `stream_delayer.py` watches the directory for new files
4. Extracts timestamp from filename, calculates delay target time
5. Waits until delay period expires
6. Pipes file contents to FFmpeg, which publishes to Twitch
7. Deletes file after successful publish and file stops growing

**Why timestamp in filename?**
File modification time (`st_mtime`) constantly updates while file is being written. Filename timestamp (from nginx-rtmp's `record_unique` directive) provides stable reference point.

**How does it handle growing files?**
Python threads continuously read the file and pipe data to FFmpeg stdin. This allows publishing a file that's still being written to, ensuring smooth transition from recording to delayed playback.

## Capacity & Scaling

### How many concurrent streams can the system handle?

Depends on server resources:

**Per nginx-rtmp container:**
- ~100-200 MB RAM
- CPU: 20-50% of one core (varies with resolution/bitrate)
- Bandwidth: ~5 Mbps upload per stream

**Example capacity:**
- **8 GB RAM, 4 cores, 100 Mbps:** ~15-20 concurrent streams
- **16 GB RAM, 8 cores, 500 Mbps:** ~40-50 concurrent streams

**Bottlenecks:**
1. CPU (FFmpeg encoding/transcoding)
2. Upload bandwidth
3. Disk I/O (if using delay/recording)

### How many channels can I add?

**Current limits:**
- Regular channels: 10 (ports 48001-48010)
- Proxy channels: 10 (ports 48101-48110)

**To expand:**
1. Add more port ranges in HAProxy configuration
2. Expose ports in firewall
3. Add channels to database with new ports

Example extending to 20 regular channels:
```haproxy
# In haproxy.cfg
EXPOSE 48001-48020
```

Then assign ports 48011-48020 to new channels in database.

### Can I run multiple RTMP Proxy servers?

Yes, but with considerations:

**Horizontal scaling:**
- Each server handles its own channels
- Share a common external MySQL database
- Each server has unique port ranges (Server 1: 48001-48010, Server 2: 48011-48020)
- DNS round-robin or manual assignment of streamers to servers

**Not recommended:**
- Load balancing RTMP traffic (stateful protocol, requires sticky sessions)
- Sharing disk storage for delay files (latency, locking issues)

### What about stream delay files filling disk?

**Disk usage:**
- 1 hour of 1080p60 stream: ~2-3 GB
- 8-minute delay buffer: ~400 MB

**Cleanup:**
- Files are automatically deleted after successful publish
- If stream crashes, files may accumulate
- Add cron job to clean old files:

```bash
# Daily cleanup of files older than 1 day
0 2 * * * find /opt/rtmp/workdir -name "*.flv" -mtime +1 -delete
```

## Security & Access

### Are Twitch stream keys secure?

Yes:
- Streamers never see actual Twitch channel stream keys
- Each streamer has a personal authentication key (`<nick>-<random>`)
- Actual Twitch keys stored securely in MySQL database
- Only nginx-rtmp containers (server-side) use real Twitch keys

**Compromise scenario:**
If a streamer's personal key is compromised, revoke it by removing the caster from database. Twitch channel key remains secure.

### How do I revoke a streamer's access?

```bash
cd tools
./castermod --remove <nickname>
```

Or directly in database:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "DELETE FROM casters WHERE nick = 'BadActor'"
```

Streamer immediately loses access. Does not affect other streamers or Twitch channel keys.

### Can streamers see each other's streams?

**By default: No.** Each nginx-rtmp container is isolated.

**With VLC viewer:** Yes, if you expose the internal RTMP application:
```
rtmp://server:48001/JohnDoe-vlc/vlc-view
```

This is intentional for viewers to watch with minimal delay. Use `vlc_viewer` caster credentials (different stream key).

### Should I change default passwords?

**Yes, immediately:**

1. **MySQL root password:** Set in `/etc/profile.d/stream.sh`
2. **MySQL user password:** Set in same file
3. **HAProxy stats:** Add password protection to stats dashboard

Never commit passwords to Git. Use environment variables only.

## Operations & Maintenance

### How often do Twitch tokens expire?

Twitch OAuth tokens typically expire after **60 days**.

**Automated refresh:**
```bash
# Add to crontab
0 2 * * 0 /path/to/tools/channelmod --refresh-tokens-all >> /var/log/token-refresh.log 2>&1
```

Runs weekly on Sundays at 2 AM, uses refresh token to get new access token.

**Manual refresh:**
```bash
cd tools
./channelmod --refresh-tokens <channel_name>
```

**Monitor expiry:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, access_token_expires FROM channels"
```

### What happens if a stream goes overtime?

**With automation (cron_worker.sh):**
- Container stops 30 minutes after scheduled end time
- Stream is forcibly disconnected
- Streamer's OBS shows "disconnected"

**Prevention:**
```bash
cd tools
./streammod --extend <stream_id>
```

Extends end time by 1 hour. Can be done multiple times.

**Manual control:**
If container was started manually, it runs indefinitely until manually stopped.

### Can I manually start/stop containers?

Yes:

**Manual start:**
```bash
cd tools
./containermod --start --name nginx-rtmp --caster JohnDoe --channel mainchannel --game csgo
```

**Manual stop:**
```bash
./containermod --stop --name nginx-rtmp --caster JohnDoe
```

**Coexistence with automation:**
Manually started containers won't be stopped by cron_worker.sh (unless also scheduled). Scheduled containers will start/stop automatically regardless of manual intervention.

### How do I upgrade to a new version?

1. **Backup database:**
```bash
docker exec mysql mysqldump -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE > backup.sql
```

2. **Pull latest code:**
```bash
git pull origin main
```

3. **Apply database migrations:**
```bash
cd mysql/db/upgrade/v1.X
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < upgrade.sql
```

4. **Update version environment variables:**
```bash
sudo nano /etc/profile.d/stream.sh
# Update version numbers
source /etc/profile.d/stream.sh
```

5. **Rebuild images:**
```bash
cd tools
./build_all_images.sh v1.7
```

6. **Restart containers (minimize downtime):**
```bash
./containermod --restart --name haproxy
./containermod --restart --name nginx-http
./containermod --restart --name php-fpm
# MySQL restart requires caution—ensure no active streams
```

### What happens during maintenance?

**Base container restart:**
- HAProxy: Graceful reload, existing RTMP streams continue
- nginx-http: Brief HTTP downtime (~5 seconds)
- php-fpm: Minimal impact
- MySQL: **Impacts all services—do during off-hours**

**Stream container restart:**
- Streamer's connection drops
- Twitch stream goes offline
- Streamer must reconnect

**Best practice:**
Schedule maintenance during off-peak hours. Notify streamers in advance.

## Troubleshooting Scenarios

### Streams work locally but not from OBS

**Likely cause:** Firewall blocking RTMP ports.

**Test:**
```bash
# From streamer's machine
telnet stream.yourdomain.com 48001
```

If it times out, firewall is blocking.

**Solution:**
Open ports in cloud security groups (AWS/GCP/Azure) or local firewall (ufw/firewalld).

### Stream connects but Twitch shows "Offline"

**Likely cause:** Wrong Twitch stream key or FFmpeg relay failure.

**Diagnosis:**
```bash
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/ffmpeg.log
```

Look for:
- `401 Unauthorized` → Wrong Twitch key
- `Connection refused` → Twitch ingest server issue

**Solution:**
1. Get correct Twitch key from Twitch dashboard
2. Update database:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE channels SET stream_key = 'live_123...' WHERE name = 'mainchannel'"
```
3. Restart container

### Advertisements not showing in OBS

**Checklist:**
1. Images are `.png` or `.jpg` (lowercase extension)
2. Images are in correct directory (`common/` or `<game>/`)
3. nginx-http container restarted after adding images
4. OBS browser source URL correct:
   ```
   https://stream.yourdomain.com/ads/?game=csgo
   ```

**Test in browser:**
Open the ads URL directly. If images don't show, check:
```bash
docker exec nginx-http ls -la /usr/share/nginx/html/ads/img/csgo/
```

### Delay is inconsistent

**Causes:**
1. Server clock drift
2. Disk I/O lag
3. FFmpeg processing delays

**Check server time:**
```bash
date
timedatectl status
```

**Sync with NTP:**
```bash
sudo timedatectl set-ntp true
```

**Monitor disk I/O:**
```bash
iostat -x 1
```

High `%util` indicates disk bottleneck. Consider faster disk or less concurrent streams.

## Technical Details

### What RTMP library does this use?

**nginx-rtmp-module** by arut (https://github.com/arut/nginx-rtmp-module)

This is a mature, production-ready RTMP module for nginx. It handles:
- RTMP protocol parsing
- Recording to FLV files
- Authentication callbacks
- HLS/DASH output (not used in this project)

### Why Python for stream_delayer.py?

**Reasons:**
1. Simple threading model (stdin/stderr non-blocking I/O)
2. Pathlib for file handling
3. Easy integration with Docker
4. No compilation needed (vs. C/C++)

**Alternatives considered:**
- Go: Better performance, but more complex deployment
- Node.js: Good async I/O, but heavier runtime
- Bash: Too limited for complex logic

### How is authentication implemented?

**nginx-rtmp hooks:**
```nginx
on_publish http://nginx-http/rtmp/auth.php;
on_play http://nginx-http/rtmp/auth.php;
```

**auth.php logic:**
1. Receives GET request: `?name=JohnDoe&key=abc123def456&app=JohnDoe`
2. Queries MySQL: `SELECT id FROM casters WHERE nick = ? AND stream_key = ?`
3. Returns HTTP 200 (accept) or 403 (reject)
4. nginx-rtmp allows/denies based on response

**Security:**
- auth.php only accessible from internal Docker network
- No direct external access to MySQL
- Stream keys are random, high-entropy

### What's the latency impact of delay?

**With delay:**
- **Recording latency:** ~0-2 seconds (nginx-rtmp to disk)
- **Processing latency:** ~0-1 second (reading file, piping to FFmpeg)
- **FFmpeg latency:** ~1-3 seconds (encoding/muxing)
- **Twitch ingest:** ~5-10 seconds (Twitch transcoding/CDN)
- **Total:** ~7-16 seconds + configured delay

**Without delay:**
- Direct FFmpeg relay: ~5-15 seconds total

### Can I stream to multiple platforms?

Yes, with FFmpeg multi-output:

Edit `nginx_proxy.conf.template`:
```nginx
exec_push /usr/bin/ffmpeg -re -i rtmp://127.0.0.1/${app}/${name}
          -c copy -f flv rtmp://live.twitch.tv/app/${TWITCH_KEY}
          -c copy -f flv rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY};
```

Requires YouTube stream key in database and container environment.

## Miscellaneous

### Why PolyForm Noncommercial License?

**Intent:** Allow free use for personal projects, communities, education while preventing commercial exploitation without permission.

**Permitted:**
- Personal streaming setup
- Esports team/community use
- Academic research
- Hobbyist projects

**Prohibited:**
- Selling the software
- Running a paid streaming service
- Incorporating into commercial products

**Want commercial license?** Contact the author.

### Can I contribute?

Yes! Contributions welcome:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Test thoroughly
5. Submit a pull request

See [README - Contributing](../README.md#contributing).

### Is there a hosted/managed version?

No, this is self-hosted only. You need your own server and Twitch credentials.

**Why self-hosted?**
- Full control over infrastructure
- No recurring costs beyond server
- Privacy (stream data never leaves your server)
- Customizable for specific needs

### Where can I get help?

1. Check [Troubleshooting Guide](Troubleshooting)
2. Review [Architecture](Architecture) to understand the system
3. Search [GitHub Issues](https://github.com/sntr8/rtmp-proxy-server/issues)
4. Open a new issue with:
   - Problem description
   - Steps to reproduce
   - Relevant logs (`docker logs`)
   - System info (OS, Docker version)

---

[Back to Wiki Home](Home)
