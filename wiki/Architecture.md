# Architecture

Understanding how RTMP Proxy Server works under the hood.

## System Overview

```
┌─────────────┐
│  Streamers  │ (OBS, XSplit, etc.)
└──────┬──────┘
       │ RTMP (ports 48001-48110)
       ▼
┌─────────────────┐
│    HAProxy      │ Layer 4 TCP routing
└────────┬────────┘
         │
    ┌────┴────┬──────────┬──────────┐
    ▼         ▼          ▼          ▼
┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│nginx-rtmp│ │nginx-  │ │nginx-  │ │nginx-  │
│-JohnDoe │ │rtmp-   │ │rtmp-   │ │rtmp-   │
│         │ │JaneDoe │ │proxy-  │ │proxy-  │
│         │ │        │ │Mike    │ │Sara    │
└────┬────┘ └───┬────┘ └───┬────┘ └───┬────┘
     │          │           │          │
     │ auth     │ auth      │ auth     │ auth
     ▼          ▼           ▼          ▼
┌──────────────────────────────────────────┐
│            nginx-http + php-fpm          │
│         (auth.php, ads, API)             │
└────────────────┬─────────────────────────┘
                 │
                 ▼
         ┌──────────────┐
         │    MySQL     │
         │  (database)  │
         └──────────────┘
```

## Container Architecture

### Base Infrastructure

These containers run continuously and provide core services:

#### **haproxy**
- **Purpose:** Front-end routing and SSL termination
- **Responsibilities:**
  - Routes RTMP traffic to nginx-rtmp containers based on destination port
  - Provides HTTPS with Let's Encrypt SSL certificates
  - Exposes HAProxy stats dashboard (port 8404)
  - Supports graceful reloads (no stream interruption)
- **Configuration:** `/opt/haproxy/haproxy.cfg`
- **Dynamic updates:** Managed by `haproxy_configmod` script

#### **mysql**
- **Purpose:** Database for all service data
- **Tables:**
  - `casters` - Streamers with authentication credentials
  - `channels` - Twitch channels with API tokens
  - `games` - Games with delay settings
  - `streams` - Scheduled streams
- **Persistence:** Data stored in Docker volume
- **Backup:** Recommend daily mysqldump

#### **nginx-http**
- **Purpose:** HTTP server for authentication and ads
- **Endpoints:**
  - `/rtmp/auth.php` - RTMP authentication (called by nginx-rtmp)
  - `/ads/` - Advertisement rotation page
  - `/ads/api/` - API endpoints for ad management
- **Port:** 443 (HTTPS via HAProxy)

#### **php-fpm**
- **Purpose:** PHP processor for nginx-http
- **Handles:** Database queries, authentication logic, ad rotation
- **Connection:** Unix socket shared with nginx-http

### Dynamic Stream Containers

Created and destroyed automatically based on schedules:

#### **nginx-rtmp-\<caster\>**
- **Purpose:** RTMP relay for a specific caster's stream
- **Created when:** Scheduled stream starts (30 min before)
- **Destroyed when:** Scheduled stream ends (30 min after)
- **Configuration modes:**
  - **With delay:** Records to disk, `stream_delayer.py` publishes with offset
  - **Without delay:** Direct relay to Twitch using FFmpeg exec_push
- **Authentication:** Calls `auth.php` on publish/play
- **Port:** Dynamically assigned based on channel (from database)

#### **nginx-rtmp-proxy-\<caster\>**
- **Purpose:** Internal RTMP relay (no Twitch output)
- **Use cases:**
  - Multiple streamers sharing a main channel via cocaster setup
  - Internal stream redistribution
  - Testing without Twitch output
- **Configuration:** Records stream, no exec_push to Twitch
- **Ports:** 48101-48110 range

## RTMP Routing Architecture

### Why Port-Based Routing?

**The Challenge:** RTMP application names (e.g., `/JohnDoe/`) are embedded in the Layer 7 protocol handshake. HAProxy operates at Layer 4 (TCP mode) and cannot parse these application names for routing decisions.

**The Solution:** Use dedicated ports per channel. HAProxy routes based on destination port, which is a Layer 4 decision.

**Port Assignment:**
- **48001-48010:** Regular stream channels (output to Twitch)
- **48101-48110:** Proxy channels (internal relay only)

### Routing Flow

1. **Streamer connects:** `rtmp://stream.yourdomain.com:48001/JohnDoe/<stream-key>`

2. **HAProxy receives:** TCP connection on port 48001

3. **HAProxy routes:** Based on port 48001, routes to `nginx-rtmp-JohnDoe` container

4. **nginx-rtmp authenticates:**
   - Extracts caster name (`JohnDoe`) and stream key from RTMP handshake
   - Calls `http://nginx-http/rtmp/auth.php?name=JohnDoe&key=<stream-key>`
   - auth.php queries MySQL database
   - Returns 200 (accept) or 403 (reject)

5. **Stream relay:**
   - If authenticated, stream is accepted
   - For delay games: Record to `/opt/rtmp/workdir/stream-<timestamp>.flv`
   - For no-delay games: Direct exec_push to Twitch via FFmpeg

### HAProxy Configuration Structure

```haproxy
# Static configuration
global
    maxconn 4096
    user haproxy
    group haproxy

defaults
    mode tcp
    timeout connect 5s
    timeout client 300s
    timeout server 300s

# Statistics dashboard
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats

# HTTPS frontend (for nginx-http)
frontend https-in
    bind *:443 ssl crt /etc/haproxy/certs/
    mode http
    default_backend nginx-http

backend nginx-http
    mode http
    server nginx nginx-http:443 check ssl verify none

# Dynamic RTMP routing (managed by haproxy_configmod)
# ::JohnDoe::start
frontend rtmp-mainchannel
    bind *:48001
    mode tcp
    default_backend JohnDoe

backend JohnDoe
    server nginx-rtmp-JohnDoe nginx-rtmp-JohnDoe:1935 check
# ::JohnDoe::end
```

**Dynamic blocks** are inserted/removed by `haproxy_configmod`:
- Markers: `# ::CasterName::start` and `# ::CasterName::end`
- When container starts: Block is added, HAProxy reloads (HUP signal)
- When container stops: Block is removed, HAProxy reloads
- **Graceful reload:** Existing connections continue on old process, new connections use new config

### Port Mapping Example

Database configuration:
```sql
SELECT name, port FROM channels;
+------------------+-------+
| name             | port  |
+------------------+-------+
| mainchannel      | 48001 |
| secondchannel    | 48002 |
| tournamentchannel| 48003 |
| only1-proxy      | 48101 |
| only2-proxy      | 48102 |
+------------------+-------+
```

Stream routing:
- JohnDoe streams to `mainchannel` → Port 48001 → nginx-rtmp-JohnDoe (relays to Twitch)
- JaneDoe streams to `secondchannel` → Port 48002 → nginx-rtmp-JaneDoe (relays to Twitch)
- Mike streams to `only1-proxy` → Port 48101 → nginx-rtmp-proxy-Mike (internal only)

## Stream Delay Implementation

For games requiring delay (e.g., competitive gaming to prevent stream sniping):

### Configuration

nginx-rtmp configuration (`nginx_delayer.conf.template`):
```nginx
application ${CASTER}-publish {
    # Internal application for initial recording
    live on;
    record all;
    record_suffix .flv;
    record_unique on;  # Embeds Unix timestamp in filename
    record_path /opt/rtmp/workdir;
}

application ${CASTER} {
    # Public application for playback (for VLC viewers)
    live on;
    record all;
    record_suffix .flv;
    record_unique on;
    record_path /opt/rtmp/workdir;
}
```

### Delay Process

1. **Streamer publishes:** `rtmp://server:48001/JohnDoe/stream-key`

2. **nginx-rtmp records:** Stream saved to `/opt/rtmp/workdir/stream-1710345678.flv`
   - Filename contains Unix timestamp of recording start
   - File grows as stream continues

3. **stream_delayer.py runs:**
   - Watches `/opt/rtmp/workdir/` for `.flv` files
   - Extracts timestamp from filename: `stream-1710345678.flv` → `1710345678`
   - Calculates delay: `target_time = timestamp + delay_seconds`
   - Waits until `target_time` is reached
   - Starts FFmpeg: Pipes file contents to FFmpeg stdin
   - FFmpeg publishes to Twitch: `rtmp://live.twitch.tv/app/<TWITCH_KEY>`

4. **Threading architecture:**
   - **Main thread:** Watchdog loop monitoring for stalls
   - **Stdin thread:** Reads file, pipes to FFmpeg (handles growing files)
   - **Stderr thread:** Drains FFmpeg output (prevents deadlock)

5. **Cleanup:** File deleted after successful publish and file stops growing

### No-Delay Configuration

For instant streaming (no delay):

nginx-rtmp configuration (`nginx_proxy.conf.template`):
```nginx
application ${CASTER} {
    live on;
    record off;  # No recording
    exec_push /usr/bin/ffmpeg -re -rtmp_live live -i rtmp://127.0.0.1/${app}/${name}
              -codec copy -f flv rtmp://live.twitch.tv/app/${TWITCH_STREAM_KEY};
}
```

FFmpeg relay starts immediately when stream is published.

## Authentication System

### auth.php Flow

1. **nginx-rtmp calls:** `http://nginx-http/rtmp/auth.php?name=JohnDoe&key=abc123def456&app=JohnDoe`

2. **auth.php validates:**
```php
// Query database
SELECT id FROM casters
WHERE nick = ? AND stream_key = ?

// If match found: HTTP 200
// If no match: HTTP 403
```

3. **nginx-rtmp action:**
   - 200 response: Stream accepted
   - 403 response: Stream rejected, connection closed

### Security Features

- **Stream keys:** Generated per caster (format: `<nick>-<random12chars>`)
- **No Twitch key exposure:** Streamers never see actual Twitch channel keys
- **Database-driven:** Easy to revoke access (delete caster from database)
- **Per-stream authentication:** Both `on_publish` and `on_play` hooks

## Network Architecture

### Internal Docker Network

All containers communicate via Docker network `stream_network`:

```
nginx-rtmp-JohnDoe → nginx-http:80 → php-fpm (Unix socket) → mysql:3306
```

DNS resolution:
- Containers resolve by name (e.g., `nginx-http`, `mysql`)
- No need for IP addresses in config files

### External Access

Only HAProxy is exposed to external network:
```
Internet → HAProxy:48001-48110 (RTMP)
Internet → HAProxy:443 (HTTPS)
Internet → HAProxy:8404 (stats, optional)
```

All other containers are isolated on internal network.

## Scalability Considerations

### Current Limits

- **Channels:** 20 total (10 regular + 10 proxy)
- **Concurrent streams:** Limited by server resources (CPU, RAM, bandwidth)
- **Database:** MySQL handles thousands of scheduled streams easily

### Scaling Up

**More channels:**
- Extend port range (48011-48020, etc.)
- Add ports to HAProxy and firewall
- Update channel database entries

**More concurrent streams:**
- Increase server resources
- Each nginx-rtmp container uses ~100-200MB RAM + CPU for FFmpeg
- Bandwidth: ~5 Mbps upload per stream

**Horizontal scaling:**
- Run multiple servers, each with own channels
- Use external MySQL server shared across servers
- Load balance HTTPS, but RTMP is direct per-server (port-based)

## Alternative Architectures (Not Implemented)

### Option 1: nginx-rtmp Dispatcher

```
Internet:1935 → nginx-rtmp-dispatcher → Parse app name → Route to nginx-rtmp-JohnDoe
```

**Pros:**
- Single port 1935 for all streamers
- Standard RTMP behavior

**Cons:**
- Extra network hop (minimal latency impact)
- Dispatcher config must be updated when adding/removing casters
- More complex than port-based routing

### Option 2: HAProxy with RTMP Parsing

Not possible - HAProxy doesn't support RTMP application parsing in TCP mode.

### Option 3: Traefik

Traefik also operates at Layer 4 for TCP routing and has same limitation as HAProxy. Would require same port-based approach or nginx-rtmp dispatcher.

## Monitoring Points

Key areas to monitor:

1. **HAProxy:** Connection counts, backend status (`http://server:8404/stats`)
2. **nginx-rtmp containers:** FFmpeg process status, log errors
3. **MySQL:** Connection count, slow queries
4. **Disk space:** `/opt/rtmp/workdir` for delay recordings
5. **System resources:** CPU, RAM, network bandwidth

See [Troubleshooting - Monitoring](Troubleshooting#monitoring) for details.

---

[Back to Wiki Home](Home)
