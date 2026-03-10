# RTMP Proxy Server - Administration Guide

This RTMP proxy server acts as a central gateway between streamers and Twitch. The server provides centralized stream management, configurable broadcast delays, and advertisement rotation. The proxy masks Twitch channel stream keys from streamers—each streamer receives a personal authentication key for accessing the system, while the actual Twitch credentials remain securely stored on the server.

## Key Features

- **Centralized Authentication**: Manage streamer access without sharing Twitch credentials
- **Configurable Delay**: Apply per-game stream delays (e.g., 8 minutes for competitive games)
- **Scheduled Streams**: Automatic container startup/shutdown based on schedules
- **Multi-Channel Support**: Route multiple streamers to different Twitch channels
- **Discord Integration**: Automated notifications for stream events
- **Advertisement Management**: Serve rotating ads via HTTP endpoint

# Service Architecture

The service is built on Docker and consists of multiple containers.

## Container Hierarchy

The **base containers** essential for the service's operation are: **haproxy**, **mysql**, **php-fpm**, and **nginx-http**. All four of these containers must be running for the service to function correctly.

**Stream containers** are created dynamically per caster as needed. For each caster, the following can be created:
- **nginx-rtmp-\<caster\>**: A game stream container that sends the stream to Twitch with or without a delay.
- **nginx-rtmp-proxy-\<caster\>**: A proxy container that does not send to Twitch, but only acts as an internal proxy server.

Containers are downloaded from GitLab's container registry using the container version number from environment variables. Versions are set with Ansible or manually as server environment variables.

### haproxy

HAProxy acts as the service frontend and DMZ. Only HAProxy (and the SSH port) is open from the server to the outside world. HAProxy routes RTMP traffic to the correct nginx-rtmp containers based on the port.

Each channel is assigned its own port (48001-48010 for game streams, 48101-48110 for proxy streams). HAProxy's configuration is updated dynamically when containers are started or stopped via the `haproxy_configmod` script.

**NOTE:** HAProxy supports graceful reloads (HUP signal), which moves old connections to a new process before shutting down the old one. Therefore, configuration changes do not disconnect running streams.

### mysql

The MySQL container provides the service's database. There are four main tables in the database: **casters**, **channels**, **games**, and **streams**.

#### casters

This table contains all casters who have the right to use the service. Additionally, the table has two internal technical users:
- **internal_technical_user**: Used for internal communication of containers operating with a delay.
- **vlc_viewer**: Used when a viewer wants to watch the stream via VLC without delay.

| Field | Type | Description | Example |
|-|-|-|-|
| id | bigint | Automatically generated ID | 1 |
| nick | varchar(255) | Caster's nickname | JohnDoe |
| stream_key | varchar(255) | Caster's personal stream key. Automatically generated when creating a caster. | JohnDoe-02785da33388 |
| discord_id | varchar(255) | Caster's Discord ID (long string of numbers, not nick#1234). Obtained by right-clicking the user in Discord Developer Mode. | 818954266525433916 |
| active | boolean | Whether the caster has the right to broadcast. Automatically set to true when the container starts, false when the container is stopped. | true |
| internal | boolean | Whether this is an internal technical user. | false |
| date_added | datetime | Date when the user was added. | 2021-06-15 14:25:00 |

#### channels

This table contains the channels to which broadcasts can be routed. Channels are divided into two types:
- **Twitch channels** (johndoe, etc.): Real Twitch channels that can be broadcasted to.
- **Proxy channels** (johndoe-proxy, etc.): Internal proxy channels that do not broadcast to Twitch.

| Field | Type | Description | Example |
|-|-|-|-|
| id | bigint | Automatically generated ID | 1 |
| name | varchar(255) | Technical name of the channel. For Twitch channels, the same as the login name. | johndoe |
| display_name | varchar(255) | Display name of the channel | John Doe's Channel |
| access_token | varchar(255) | Twitch Helix API access token (Twitch channels only). | WOYkPWbdf1sMgdAUxhti7dhET6wWPS7 |
| client_id | varchar(255) | Twitch API client ID (Twitch channels only). | gp762nuuoqcoxypju8c569th9wz7q5 |
| refresh_token | varchar(255) | Token used to refresh the access_token via twitchtokengenerator.com API. | lM6aMXactcfUxf0jXViNfzrHX6URxkbdbanBTLEqgIFuNDnHqPv |
| access_token_expires | datetime | When the access_token expires (max 60 days). | 2021-06-15 14:25:00 |
| port | int | Channel's HAProxy port (48001-48010 streams, 48101-48110 proxy). | 48001 |
| url | varchar(255) | Channel's Twitch URL | https://www.twitch.tv/johndoe |

#### games

This table contains all the games that can be broadcasted to Twitch. The game's `display_name` must perfectly match the Twitch Helix API in order to set the game successfully.

| Field | Type | Description | Example |
|-|-|-|-|
| id | bigint | Automatically generated ID | 1 |
| name | varchar(255) | Technical name of the game (short, lowercase). | pubg |
| display_name | varchar(255) | Official name of the game on Twitch (must match exactly). | PlayerUnknown's Battlegrounds |
| abbreviation | varchar(255) | Official abbreviation of the game | PUBG |
| delay | int | Broadcast delay in seconds (0 = no delay). | 480 |

#### streams

This table contains scheduled broadcasts. Every broadcast must be scheduled in advance so that:
- Containers start and stop automatically.
- Casters receive Discord notifications about container startups.
- Channel overlaps can be checked.

| Field | Type | Description | Example |
|-|-|-|-|
| id | bigint | Automatically generated ID | 1 |
| caster_id | bigint | Primary caster's ID (foreign key to casters table). | 1 |
| cocaster_id | varchar(255) | Co-caster's ID (added in v1.6). | 2 |
| channel_id | bigint | Channel's ID (foreign key to channels table). | 1 |
| game_id | bigint | Game's ID (foreign key to games table). NULL for proxy streams. | 1 |
| title | varchar(255) | The stream title to be set on Twitch. | JohnDoe Plays Games  |
| description | text | Broadcast description (currently not in use). | |
| live | boolean | Whether the broadcast is currently live. | true |
| skip | boolean | Whether the broadcast is marked to be skipped due to an error. | false |
| start_time | datetime | Broadcast start time | 2021-06-15 14:25:00 |
| end_time | datetime | Broadcast end time (must be after start_time). | 2021-06-15 16:25:00 |

### nginx-http

The nginx-http container serves two different contexts:
1. **/ads/** - Public, serves advertisements for use in broadcasts.
2. **/rtmp/** - Internal network, serves auth.php authentication for nginx-rtmp containers.

**Security:** Access to the /rtmp/ context from the external network is blocked in the HAProxy configuration.

#### /ads/ - Ad Context

The ad page serves an ad rotation to be added as an OBS source.

**Directory Structure:**
```
nginx-http/html/ads/
├── img/
│   ├── common/          # Common ads (in all streams)
│   ├── apex/            # Apex Legends ads
│   ├── csgo/            # CS:GO ads
│   ├── pubg/            # PUBG ads
│   └── rl/              # Rocket League ads
├── ads.php              # Main page
├── carousel.js          # Vanilla JavaScript carousel
└── style.css
```

**Functionality:**
- Uses a custom vanilla JavaScript carousel (no external dependencies).
- Each ad is displayed for 15 seconds.
- URL: `/ads/gamename.php` or `/ads/ads.php?game=gamename`
- Without the game parameter, only common ads are shown.
- Ads are shuffled randomly to ensure fair advertising time.

**Ad Image Requirements:**
- Format: `.png` or `.jpg` (lowercase letters!).
- Location: `img/common/` or `img/gamename/`

#### /rtmp/ - Authentication Context

Internal network authentication for nginx-rtmp containers. Serves the `auth.php` file.

**auth.php - RTMP Authentication:**

Every RTMP connection coming to the nginx-rtmp container is authenticated through this. Authentication requirements:
- The broadcast path matches an active caster in the database.
- The stream key matches the stream_key field of the caster.
- The call is of type: publish, play, or update.
- Internal users (internal=true) cannot use the publish call.

**HTTP Response Codes:**

| Code | Meaning |
|-|-|
| 200 | Authentication successful |
| 400 | RTMP call not allowed |
| 401 | Stream key is incorrect |
| 404 | Broadcast path is incorrect |
| 500 | Database error |

### php-fpm

The PHP-FPM container executes PHP code on behalf of the nginx-http container (ads.php and auth.php).

## Operational Scripts

The service is managed with Bash scripts located in the `tools/` directory:

| Script | Purpose |
|-|-|
| **containermod** | Container management (start, stop, restart) |
| **streammod** | Stream scheduling and management |
| **castermod** | Adding and listing casters |
| **channelmod** | Channel management |
| **gamemod** | Listing games |
| **haproxy_configmod** | HAProxy configuration |
| **discordmod** | Discord notifications |
| **cron_worker.sh** | Cron worker script for automatic stream start/stop |

### containermod - Container Management

The most important script for operating containers.

**Critical Security Mechanisms:**
- nginx-http and php-fpm **cannot be stopped** if any nginx-rtmp container is running.
- This is checked from `/var/lock/nginx-rtmp-*.lock` files.
- nginx-rtmp containers **cannot be restarted** automatically (use stop + start).

**Common Commands:**
```bash
# List all containers
containermod --list

# Start all base containers
containermod --start --all

# Stop all base containers (fails if streams are running!)
containermod --stop --all

# Restart all base containers (fails if streams are running!)
containermod --restart --all

# Restart a single base container
containermod --restart --name haproxy

# Start a stream container
containermod --start --name nginx-rtmp --caster JohnDoe --channel johndoe --game pubg

# Start a proxy container
containermod --start --name nginx-rtmp --caster JohnDoe --channel johndoe-proxy --proxy

# Stop a stream container
containermod --stop --name nginx-rtmp --caster JohnDoe

# Stop a proxy container
containermod --stop --name nginx-rtmp --caster JohnDoe --proxy
```

**NOTE:** If you want to restart everything, you must first stop all nginx-rtmp containers:
```bash
# First list running nginx-rtmp containers
docker ps | grep nginx-rtmp

# Stop each one individually
containermod --stop --name nginx-rtmp --caster JohnDoe
containermod --stop --name nginx-rtmp --caster JohnDoe --proxy

# Now you can restart the base containers
containermod --restart --all
```

### streammod - Stream Management

Scheduling and managing streams.

**Common Commands:**
```bash
# Add a new stream (interactive)
streammod --add

# List upcoming streams
streammod --upcoming

# List currently live streams
streammod --live

# Extend a stream's end time
streammod --extend <stream_id>

# Delete a stream
streammod --delete <stream_id>
```

**NOTE:** Streams should always be scheduled in advance! This ensures:
- Automatic start/stop via cron_worker.
- Discord notifications to casters.
- No overlapping reservations on the same channel.

### castermod - Caster Management

Adding and listing casters.

**Commands:**
```bash
# Add a new caster (generates an automatic stream key)
castermod --add <nick> <discord_id>

# Add a caster with a specific stream key
castermod --add <nick> <discord_id> --key <stream_key>

# List all casters
castermod --list

# List only nicks
castermod --list --nicks

# Activate caster (sets active=true)
castermod --activate <nick>

# Deactivate caster (sets active=false)
castermod --disable <nick>
```

**Obtaining a Discord ID:**
1. Discord > Settings > Advanced > Developer Mode (turn on)
2. Right-click user > Copy User ID
3. The ID is a long string of numbers, **not** in the format nick#1234.

### haproxy_configmod - HAProxy Configuration

Managing HAProxy container routing. **Usually used automatically** by the `containermod` script.

```bash
# Add routing for a caster
haproxy_configmod --add <caster> <channel>

# Remove routing
haproxy_configmod --remove <caster>
```

**NOTE:** Changes require a HAProxy reload, but a graceful reload does not disconnect running streams (HUP signal moves connections to a new process).

# Ansible

Server configuration is handled via Ansible. Ansible configurations define:
- Server environment variables (versions, passwords, API keys).
- Cron jobs for automatic stream startup.
- Permissions and security settings.

Ansible configurations are located in the `ansible/` directory.

---

# Daily Operations

## Scheduling a Stream

**Streams must ALWAYS be scheduled in advance!** This ensures automatic start/stop and Discord notifications.

```bash
streammod --add
```

The command prompts interactively for:
- **Caster:** Primary caster's nickname (nick)
- **Co-caster:** Second caster's nickname (optional, v1.6+)
- **Channel:** Twitch channel or proxy channel
- **Game:** Game name (not needed for proxy containers)
- **Title:** Stream title to be set on Twitch
- **Start Time:** Format `DD.MM.YYYY HH:MM` (EU) or `MM/DD/YYYY HH:MM` (US) - cannot be in the past
- **End Time:** Format `DD.MM.YYYY HH:MM` (EU) or `MM/DD/YYYY HH:MM` (US) - must be after start time

**NOTE:** The script does not automatically check for overlapping reservations! Check manually: `streammod --upcoming`

## Stream Management

```bash
# List upcoming streams
streammod --upcoming

# List live streams
streammod --live

# Extend a stream's end time
streammod --extend <stream_id>

# Delete an upcoming stream
streammod --delete <stream_id>
```

## Adding a Caster

```bash
castermod --add <nick> <discord_id>
```

**Obtaining a Discord ID:**
1. Discord > Settings > Advanced > Developer Mode (turn on)
2. Right-click user > Copy User ID
3. The ID is a long string of numbers (e.g., `818954266525433916`), **NOT** in the format nick#1234.

## Manual Emergency Startup

**WARNING:** Manually started containers are not accounted for in schedules! Use only in emergencies.

```bash
# First check the required values
castermod --list --nicks
channelmod --list
gamemod --list

# Start a stream container
containermod --start --name nginx-rtmp --caster <CASTER> --channel <CHANNEL> --game <GAME>

# Start a proxy container
containermod --start --name nginx-rtmp --caster <CASTER> --channel <PROXY_CHANNEL> --proxy
```

## Updating Advertisements

**WARNING:** nginx-http and php-fpm containers cannot be stopped during streams! Update ads before streams.

### 1. Add ad images to GitLab

```bash
git clone [https://gitlab.com/kanaliiga/stream-rtmp.git](https://gitlab.com/kanaliiga/stream-rtmp.git)
cd stream-rtmp
git checkout -b ads/company-name

# Copy .png or .jpg images to the correct directory:
# nginx-http/html/ads/img/common/ (common ads)
# nginx-http/html/ads/img/pubg/ (game-specific)
# nginx-http/html/ads/img/csgo/
# nginx-http/html/ads/img/rl/
# nginx-http/html/ads/img/apex/

git add nginx-http/html/ads/img/
git commit -m "Add ads for CompanyOy"
git push -u origin ads/company-name
```

### 2. Create a Merge Request in GitLab

Request a code review and wait for approval.

### 3. Build Docker Images (in master branch)

```bash
git checkout master
git pull
./tools/build_all_images.sh $IMAGE_VERSION
```

Building takes about 5-10 minutes depending on the internet connection.

### 4. Update containers on the server

**FIRST, check that no streams are running:**

```bash
# Check running nginx-rtmp containers
containermod --list

# If nginx-rtmp containers are visible, DO NOT proceed!
# Wait for streams to end or coordinate with the casters.

# If no nginx-rtmp containers are running, you can update:
containermod --stop --name nginx-http
containermod --stop --name php-fpm
containermod --start --name php-fpm
containermod --start --name nginx-http
```

# Troubleshooting

## "Connection failed to server" (OBS)

**Symptom:** OBS cannot connect to the RTMP server.

**Possible Causes:**

### 1. Check OBS Settings

```
Server: rtmp://stream.kanaliiga.fi/<caster>/
Stream Key: <caster>-<stream_key>
```

**Correct port:** OBS connects to HAProxy, which routes traffic to the correct port. **DO NOT** put a port in the OBS Server field.

### 2. Check that HAProxy is running

```bash
containermod --list | grep haproxy
```

If it doesn't appear, start it:
```bash
containermod --start --name haproxy
```

### 3. Check that the nginx-rtmp container is running

```bash
containermod --list | grep nginx-rtmp-<caster>
```

If it doesn't appear, check:
- Is the stream scheduled? `streammod --live`
- Start manually if necessary (see manual emergency startup).

### 4. Check that the caster is active

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT nick, active, stream_key FROM casters WHERE nick='<caster>'"
```

The `active` field should be `1`. If it is `0`:
```bash
castermod --activate <caster>
```

### 5. Test the connection to the server

```bash
# From your own computer
telnet stream.kanaliiga.fi 1935

# Should connect. If not, it's a network issue or HAProxy isn't listening.
```

## OBS broadcasts, but stream is not on Twitch

### 1. Check that the nginx-rtmp container is running

```bash
containermod --list
```

The listing should show `nginx-rtmp-<caster>` or `nginx-rtmp-proxy-<caster>`.

### 2. Check HAProxy configuration

```bash
cat /opt/haproxy/haproxy.cfg
```

There should be a distinct block for each caster:

```
# ::JohnDoe::start
frontend rtmp-johndoe
    bind *:48001
    mode tcp
    default_backend JohnDoe

backend JohnDoe
    server nginx-rtmp-JohnDoe nginx-rtmp-JohnDoe:1935 check
# ::JohnDoe::end
```

**Problems:**
- Multiple configuration definitions for the same caster.
- Incomplete blocks (only `::start` or only `::end`).
- Configuration exists for a caster that doesn't have a running container.

**Fix 1 - Edit manually (recommended):**

```bash
# Edit configuration manually
nano /opt/haproxy/haproxy.cfg

# Remove duplicates/incorrect blocks.
# Ensure every running container has a correct block.

# HAProxy reload (graceful, doesn't cut streams)
docker kill -s HUP haproxy
```

**Fix 2 - Regenerate configuration:**

```bash
# NOTE: This restart will briefly shut down HAProxy, which may cause a short interruption.
containermod --restart --name haproxy

# Add configuration for each running container.
haproxy_configmod --add <CASTER> <CHANNEL>
# Example:
haproxy_configmod --add JohnDoe johndoe
```

### 3. Check Twitch Stream Key

**What happens:** Upon container startup, the system retrieves the Twitch stream key from the Helix API and configures ffmpeg to push to it. If the retrieval fails, the key remains "Null" and the stream is not broadcast to Twitch.

**Check configuration:**

```bash
docker exec nginx-rtmp-<CASTER> cat /etc/nginx/nginx.conf | grep exec_push
```

**It should look like this:**
```
exec_push ffmpeg ... rtmp://live.twitch.tv/app/live_XXXXXXXXXXX;
```

(The system uses Twitch's automatic routing `live.twitch.tv`, which routes traffic to the nearest server).

**If `Null` appears in place of the stream key:**

This means the Twitch API call failed during container startup. Reasons for this could be:
- Twitch access token is expired (see point 4).
- Twitch API was down.
- There is an incorrect channel name in the database.

**Fix:**

```bash
# Stop and restart the container (the system will fetch the stream key again)
containermod --stop --name nginx-rtmp --caster <CASTER>
containermod --start --name nginx-rtmp --caster <CASTER> --channel <CHANNEL> --game <GAME>

# Check Docker logs if the problem persists:
docker logs nginx-rtmp-<CASTER> | grep -i "stream.*key\|twitch\|api"
```

### 4. Check Twitch API Tokens

Twitch access tokens expire every 60 days. The system automatically attempts to refresh the tokens using the `refresh_token` key.

**Check token status:**

```bash
# See when tokens expire
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, access_token_expires FROM channels WHERE name NOT LIKE '%proxy%'"
```

**If stream key retrieval fails:**

1. The system attempts to automatically refresh the tokens.
2. If the refresh fails, a Discord notification is sent to the casters.
3. **Manual fix is needed if:**
   - `refresh_token` is expired or invalid.
   - Twitch API credentials have changed.

**Fetch new tokens:**

1. Go to: https://twitchtokengenerator.com
2. Log in to the channel.
3. Get new keys: `access_token`, `refresh_token`, and `client_id`.
4. Update them in the database:

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE channels SET
   access_token='NEW_ACCESS_TOKEN',
   refresh_token='NEW_REFRESH_TOKEN',
   client_id='NEW_CLIENT_ID',
   access_token_expires=DATE_ADD(NOW(), INTERVAL 60 DAY)
   WHERE name='johndoe'"
```

## SSL/TLS Connection Error (HTTPS)

**Symptom:** Browser shows "Your connection is not private" or "SSL_ERROR_EXPIRED_CERT" when attempting to open https://stream.kanaliiga.fi

**Cause:** Let's Encrypt certificates expire every 90 days. HAProxy should renew them automatically, but sometimes the renewal fails.

### Check certificate expiration

```bash
# Check the validity of the current certificate
openssl x509 -in /opt/letsencrypt/live/stream.kanaliiga.fi/cert.pem -noout -dates

# Or from browser: Click the lock icon > Certificate > Valid from/to
```

### Fix expired certificates

```bash
# Remove old certificates
rm -rf /opt/letsencrypt/*

# Restart HAProxy - it will automatically fetch a new Let's Encrypt certificate
containermod --restart --name haproxy

# Wait a moment and check that certificates were created successfully
ls -la /opt/letsencrypt/live/stream.kanaliiga.fi/
```

## Containers won't stop (`containermod --restart --all` fails)

**Symptom:** Command `containermod --restart --all` or `--stop --all` fails with the error message "A stream container is running. Can't stop nginx-http/php-fpm at this time".

**Cause:** Security mechanism - nginx-http and php-fpm containers cannot be stopped when nginx-rtmp containers are running. This is because nginx-rtmp containers need them for authentication (auth.php) and displaying ads.

### Solution

```bash
# 1. List all running nginx-rtmp containers
containermod --list | grep nginx-rtmp

# Example output:
# nginx-rtmp-JohnDoe
# nginx-rtmp-proxy-DeSHa
# nginx-rtmp-Fettis

# 2. Stop each nginx-rtmp container individually
containermod --stop --name nginx-rtmp --caster JohnDoe
containermod --stop --name nginx-rtmp --caster DeSHa --proxy
containermod --stop --name nginx-rtmp --caster Fettis

# 3. Verify that all nginx-rtmp containers are stopped
containermod --list | grep nginx-rtmp
# Output should be empty.

# 4. Check that lock files have been removed
ls -la /var/lock/nginx-rtmp-*.lock 2>/dev/null
# Output should be empty or say "No such file".

# 5. Now you can restart the base containers
containermod --restart --all

# 6. Start the nginx-rtmp containers back up as needed
# (or let cron_worker handle it, if they are scheduled)
```

## Other Problems / General Debugging

If none of the above helps, go through these steps:

### 1. Check Docker Logs

```bash
# Check latest logs
docker logs --tail 100 <container_name>

# E.g., nginx-rtmp container logs
docker logs --tail 100 nginx-rtmp-JohnDoe

# Follow logs in real-time
docker logs -f nginx-rtmp-JohnDoe

# Search for errors
docker logs nginx-rtmp-JohnDoe | grep -i "error\|fail\|exception"
```

### 2. Check Container Status

```bash
# List all containers (including stopped ones)
docker ps -a

# Check container health
docker inspect haproxy | grep -A 10 "State"

# See when container started / stopped
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 3. Check Server Resources

```bash
# Disk space (should be at least 10% free)
df -h

# Memory (if swap is in use, memory is running out)
free -h

# CPU and memory per container
docker stats --no-stream

# System load
uptime
```

### 4. Check Network

```bash
# Docker network
docker network ls
docker network inspect stream

# Listening ports
netstat -tlnp | grep -E ":(80|443|1935|48[01][0-9][0-9])"

# Is HAProxy reachable?
curl -I http://localhost:80
```

### 5. As a Last Resort - Full Restart

**WARNING:** This disconnects ALL streams! Coordinate with other casters first.

```bash
# Stop all containers
docker stop $(docker ps -q)

# Restart Docker service
systemctl restart docker

# Start base containers
containermod --start --all

# Check that everything started
containermod --list
```

### 6. Document and Ask for Help

If the problem persists or you find a new fault condition:
- Keep the necessary logs.
- Document what you did and what happened.
- Update this wiki with a new solution.
- Ask a more experienced person for help.

---

## Best Practices

### Before streams
- **Always** schedule streams in advance: `streammod --add`
- **Check** that there are no overlaps: `streammod --upcoming`
- **Verify** that base containers are running: `containermod --list`

### During streams
- **DO NOT** restart nginx-http or php-fpm containers (authentication will break).
- **DO NOT** shut down HAProxy with a full restart (graceful reload is ok: `docker kill -s HUP haproxy`).
- **DO NOT** run the command `containermod --restart --all` (it will fail if streams are running).

### Maintenance operations
- **Always coordinate** with other streamers before making major changes.
- **Test** first in a staging environment if possible.
- **Document** all changes made and problems found.
- **Update** this wiki if you find a new solution.

### In an emergency
1. Check Docker logs first.
2. Google the error message.
3. Ask for help in Discord.
4. Last resort: full restart (cuts streams).