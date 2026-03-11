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
     │ Multi-platform FFmpeg output (per linked channel)
     │          │           │          │
     ▼          ▼           ▼          ▼
   Twitch   Instagram   YouTube   Facebook
   Twitch   YouTube     Twitch    (etc.)
   (etc.)   (etc.)      (etc.)

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

## Many-to-Many Broadcast Architecture

### Conceptual Model

The system uses a **many-to-many** relationship between broadcasts and channels:

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│  Broadcasts │         │ Broadcast_       │         │  Channels   │
│             │         │ Channels         │         │             │
│  (Ingress)  │ ─────── │  (Junction)      │ ─────── │(Platforms)  │
└─────────────┘         └──────────────────┘         └─────────────┘
│                                                     │
│ - main-show (port 48001)                           │ - my_twitch
│ - evening-cast (port 48002)                        │ - my_instagram
│ - tournament (port 48003)                          │ - my_youtube
│                                                     │ - my_facebook
```

### Key Concepts

- **Channel**: A platform destination (reusable across broadcasts)
  - Example: `my_twitch`, `my_instagram`, `my_youtube`
  - Contains: platform type, stream URL, stream key, API credentials
  - One channel can be used in multiple broadcasts

- **Broadcast**: An RTMP ingress point with a port
  - Example: `main-show` on port 48001
  - Streamers connect to the broadcast port
  - One broadcast outputs to one or more channels

- **Broadcast_Channels**: Links channels to broadcasts
  - Junction table with enabled/priority flags
  - Allows enabling/disabling specific outputs without stopping stream

### Examples

**Scenario 1: Multi-platform streaming**
```
Broadcast: main-show (port 48001)
  ├─ my_twitch (enabled)
  ├─ my_instagram (enabled)
  └─ my_youtube (enabled)
→ Streamer connects to port 48001, outputs to all 3 platforms
```

**Scenario 2: Reusable channels**
```
Broadcast: morning-show (port 48001)
  ├─ my_twitch (enabled)
  └─ my_instagram (enabled)

Broadcast: evening-show (port 48002)
  ├─ my_twitch (enabled)
  └─ my_facebook (enabled)

→ my_twitch channel is reused across both broadcasts
```

**Scenario 3: Different platform combinations**
```
Broadcast: main-event (port 48001)
  ├─ my_twitch (enabled)
  ├─ my_instagram (enabled)
  ├─ my_youtube (enabled)
  └─ my_facebook (enabled)
→ Stream to ALL platforms simultaneously

Broadcast: test-stream (port 48002)
  └─ my_twitch (enabled)
→ Stream to Twitch only for testing
```

### Database Schema

```sql
-- Platform destinations (reusable)
CREATE TABLE channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    platform ENUM('twitch', 'instagram', 'facebook', 'youtube') DEFAULT 'twitch',
    stream_url VARCHAR(512),
    stream_key VARCHAR(512),
    display_name VARCHAR(255),
    access_token TEXT,
    client_id VARCHAR(255),
    client_secret VARCHAR(512),
    refresh_token TEXT
);

-- RTMP ingress points
CREATE TABLE broadcasts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    port INT UNIQUE NOT NULL,
    display_name VARCHAR(255)
);

-- Many-to-many junction
CREATE TABLE broadcast_channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    broadcast_id INT NOT NULL,
    channel_id INT NOT NULL,
    enabled TINYINT(1) DEFAULT 1,
    priority INT DEFAULT 0,
    FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id) ON DELETE CASCADE,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    UNIQUE KEY unique_broadcast_channel (broadcast_id, channel_id)
);

-- Scheduled streams now reference broadcasts
CREATE TABLE streams (
    id INT AUTO_INCREMENT PRIMARY KEY,
    caster_id INT NOT NULL,
    broadcast_id INT NOT NULL,  -- Changed from channel_id
    game_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id)
);
```

## Container Architecture

### Base Infrastructure

These containers run continuously and provide core services:

#### **haproxy**
- **Purpose:** Front-end routing and SSL termination
- **Responsibilities:**
  - Routes RTMP traffic to nginx-rtmp containers based on destination port
  - Provides HTTPS with Let's Encrypt SSL certificates
  - Supports graceful reloads (no stream interruption)
- **Configuration:** `/opt/haproxy/haproxy.cfg`
- **Dynamic updates:** Managed by `haproxy_configmod` script

#### **mysql**
- **Purpose:** Database for all service data
- **Tables:**
  - `casters` - Streamers with authentication credentials
  - `channels` - Platform destinations (Twitch, Instagram, YouTube, Facebook)
  - `broadcasts` - RTMP ingress points with ports
  - `broadcast_channels` - Many-to-many junction table
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

**The Solution:** Use dedicated ports per broadcast. HAProxy routes based on destination port, which is a Layer 4 decision.

**Port Assignment:**
- **48001-48010:** Regular broadcasts (output to platform channels)
- **48101-48110:** Proxy broadcasts (internal relay only)

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
   - Container queries database for all channels linked to the broadcast
   - For delay games: Record to `/opt/rtmp/workdir/stream-<timestamp>.flv`
   - For no-delay games: Generate multiple exec_push FFmpeg commands (one per linked channel)
   - Each platform gets its own FFmpeg process with platform-specific settings
   - Separate log files per platform: `ffmpeg-twitch.log`, `ffmpeg-instagram.log`, etc.

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
-- Broadcasts (RTMP ingress)
SELECT name, port FROM broadcasts;
+--------------+-------+
| name         | port  |
+--------------+-------+
| main-show    | 48001 |
| evening-cast | 48002 |
| tournament   | 48003 |
| proxy-1      | 48101 |
+--------------+-------+

-- Channels (Platform destinations)
SELECT name, platform FROM channels;
+--------------+-----------+
| name         | platform  |
+--------------+-----------+
| my_twitch    | twitch    |
| my_instagram | instagram |
| my_youtube   | youtube   |
+--------------+-----------+

-- Linked channels for main-show broadcast
SELECT c.name, c.platform
FROM broadcast_channels bc
JOIN channels c ON bc.channel_id = c.id
JOIN broadcasts b ON bc.broadcast_id = b.id
WHERE b.name = 'main-show';
+--------------+-----------+
| name         | platform  |
+--------------+-----------+
| my_twitch    | twitch    |
| my_instagram | instagram |
+--------------+-----------+
```

Stream routing:
- JohnDoe streams to `main-show` → Port 48001 → nginx-rtmp-JohnDoe → Outputs to my_twitch + my_instagram
- JaneDoe streams to `evening-cast` → Port 48002 → nginx-rtmp-JaneDoe → Outputs to linked channels
- Mike streams to `proxy-1` → Port 48101 → nginx-rtmp-proxy-Mike (internal only, no platform output)

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

    # Multiple exec_push lines generated dynamically (one per linked channel)
    # Example for broadcast linked to Twitch + Instagram:

    exec_push /usr/bin/ffmpeg -loglevel warning -re -rtmp_live live
              -i rtmp://127.0.0.1/${app}/${name}
              -codec copy -f flv rtmp://live.twitch.tv/app/live_123456789_abc
              2>>/opt/nginx/logs/ffmpeg-twitch.log;

    exec_push /usr/bin/ffmpeg -loglevel warning -re -rtmp_live live
              -i rtmp://127.0.0.1/${app}/${name}
              -codec copy -f flv rtmp://live-upload.instagram.com:80/rtmp/ig_key_here
              2>>/opt/nginx/logs/ffmpeg-instagram.log;
}
```

**How it works:**
- `entrypoint.sh` parses OUTPUTS environment variable at container start
- Generates one `exec_push` line per linked channel
- Each FFmpeg process reads the same input stream
- Separate logs per platform for debugging
- All use passthrough encoding (`-codec copy`) for efficiency

FFmpeg relays start immediately when stream is published.

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
```

All other containers are isolated on internal network.

## Scalability Considerations

### Current Limits

- **Broadcasts:** 20 total (10 regular + 10 proxy)
- **Channels (platforms):** Unlimited (database-driven, no port constraints)
- **Concurrent streams:** Limited by server resources (CPU, RAM, bandwidth)
- **Database:** MySQL handles thousands of scheduled streams easily

### Many-to-Many Flexibility

- One channel (e.g., `my_twitch`) can be reused across multiple broadcasts
- One broadcast can output to multiple channels simultaneously
- Mix and match platforms per broadcast:
  - Morning show → Twitch + Instagram
  - Evening show → Twitch + YouTube
  - Special event → Twitch + Instagram + YouTube + Facebook

### Scaling Up

**More broadcasts:**
- Extend port range (48011-48020, etc.)
- Add ports to HAProxy and firewall
- Create broadcasts with new ports

**More channels:**
- No limit - just create them in database
- Channels are reusable across broadcasts

**More concurrent streams:**
- Increase server resources
- Each nginx-rtmp container uses ~100-200MB RAM + CPU for FFmpeg
- Bandwidth: ~5 Mbps upload per stream × number of platforms
- Example: 3-platform broadcast needs ~15 Mbps upload

**Horizontal scaling:**
- Run multiple servers, each with own broadcasts
- Share channel definitions via external MySQL server
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

1. **HAProxy:** Check logs for connection status and backend health
2. **nginx-rtmp containers:** FFmpeg process status, log errors
3. **MySQL:** Connection count, slow queries
4. **Disk space:** `/opt/rtmp/workdir` for delay recordings
5. **System resources:** CPU, RAM, network bandwidth

See [Troubleshooting - Monitoring](Troubleshooting#monitoring) for details.

---

[Back to Wiki Home](Home)
