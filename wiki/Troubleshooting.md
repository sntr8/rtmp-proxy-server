# Troubleshooting Guide

Common issues and solutions for RTMP Proxy Server.

## Table of Contents

- [Monitoring](#monitoring)
- [Connection Issues](#connection-issues)
- [Container Issues](#container-issues)
- [HAProxy Issues](#haproxy-issues)
- [Database Issues](#database-issues)
- [Twitch API Issues](#twitch-api-issues)
- [Stream Quality Issues](#stream-quality-issues)
- [Delay Issues](#delay-issues)
- [SSL Certificate Issues](#ssl-certificate-issues)

---

## Monitoring

### Check System Status

**All containers running:**
```bash
docker ps
```

Should see: `haproxy`, `mysql`, `nginx-http`, `php-fpm`, plus any active `nginx-rtmp-*` containers.

**Container not listed?**
```bash
docker ps -a  # Show stopped containers
docker logs <container_name>  # Check why it stopped
```

**Check container logs:**
```bash
# Follow logs in real-time
docker logs -f haproxy
docker logs -f nginx-rtmp-JohnDoe
docker logs -f mysql

# Last 100 lines
docker logs --tail 100 nginx-http
```

**Check system resources:**
```bash
# CPU and memory
docker stats

# Disk space
df -h

# Disk usage by container
docker system df
```

### Log Locations

**HAProxy:**
- Container logs: `docker logs haproxy`
- Access logs: Stdout (visible in `docker logs`)

**nginx-rtmp:**
- All logs forwarded to `docker logs nginx-rtmp-<caster>`
- Includes: nginx errors, FFmpeg output
- Log files in container: `/opt/nginx/logs/error.log`, `/opt/nginx/logs/ffmpeg*.log`

```bash
docker logs -f nginx-rtmp-JohnDoe
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/error.log
```

**nginx-http:**
- Error log: `/var/log/nginx/error.log` (in container)
- Access log: `/var/log/nginx/access.log`

```bash
docker exec nginx-http tail -f /var/log/nginx/error.log
```

**MySQL:**
- Error log: `/var/log/mysql/error.log` (in container)
- Slow query log: `/var/log/mysql/slow.log` (if enabled)

```bash
docker logs mysql
docker exec mysql tail -f /var/log/mysql/error.log
```

**Cron worker:**
```bash
tail -f /var/log/stream-cron.log
```

---

## Connection Issues

### Streamer Cannot Connect

**Symptom:** OBS shows "Failed to connect to server" or "Connection timed out"

**Diagnosis:**

1. **Check port is open:**
```bash
# From external machine
telnet stream.yourdomain.com 48001

# From server
netstat -tlnp | grep 48001
```

2. **Check firewall:**
```bash
# Ubuntu/Debian
sudo ufw status
sudo ufw allow 48001/tcp

# CentOS/RHEL
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=48001/tcp --permanent
sudo firewall-cmd --reload
```

3. **Check cloud security groups:** (AWS, GCP, Azure)
   - Ensure ports 48001-48110 are open to 0.0.0.0/0

4. **Check HAProxy routing:**
```bash
docker exec haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep -A 10 "::JohnDoe::"
```

Should show frontend/backend for caster.

5. **Check container is running:**
```bash
docker ps | grep nginx-rtmp-JohnDoe
```

**Solutions:**

**Port not listening:**
```bash
cd tools
./containermod --start --name nginx-rtmp --caster JohnDoe --channel mainchannel --game csgo
```

**HAProxy routing missing:**
```bash
./haproxy_configmod --add --caster JohnDoe --port 48001
./haproxy_configmod --reload
```

**Wrong port:**
Check database for correct channel port:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, port FROM channels WHERE name = 'mainchannel'"
```

### Authentication Failure

**Symptom:** OBS connects but immediately disconnects, nginx-rtmp logs show "403 Forbidden"

**Diagnosis:**

```bash
docker exec nginx-rtmp-JohnDoe tail /opt/nginx/logs/error.log
```

Look for:
```
on_publish http://nginx-http/rtmp/auth.php returned 403
```

**Causes:**

1. **Wrong stream key:**
   - Verify key: `docker exec mysql mysql --defaults-extra-file=/creds.cnf -e "SELECT nick, stream_key FROM casters WHERE nick = 'JohnDoe'"`
   - Ensure OBS uses exact key (case-sensitive)

2. **Wrong application name:**
   - OBS server URL should be: `rtmp://server:48001/JohnDoe/` (not `/live/` or other)

3. **auth.php not responding:**
```bash
docker logs nginx-http
docker logs php-fpm
```

4. **Database connection issue:**
```bash
docker exec nginx-http curl http://localhost/rtmp/auth.php?name=JohnDoe&key=test
```

Should return HTTP 200 or 403 (not connection error).

**Solutions:**

**Regenerate stream key:**
```bash
cd tools
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE casters SET stream_key = 'JohnDoe-newkey123abc' WHERE nick = 'JohnDoe'"
```

**Restart nginx-http/php-fpm:**
```bash
./containermod --restart --name nginx-http
./containermod --restart --name php-fpm
```

### Stream Connects But Nothing on Twitch

**Symptom:** OBS shows "Live" but Twitch channel shows offline

**Diagnosis:**

1. **Check FFmpeg is running:**
```bash
docker exec nginx-rtmp-JohnDoe ps aux | grep ffmpeg
```

Should show FFmpeg process.

2. **Check FFmpeg logs:**
```bash
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/ffmpeg.log
```

Look for errors like:
- `Connection refused` - Twitch ingest server unreachable
- `401 Unauthorized` - Wrong Twitch stream key
- `Stream key does not match any live channel` - Invalid key

3. **Check Twitch stream key:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, stream_key FROM channels WHERE name = 'mainchannel'"
```

**Solutions:**

**Wrong Twitch key:**
1. Get correct key from Twitch dashboard
2. Update database:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE channels SET stream_key = 'live_123456789_abc...' WHERE name = 'mainchannel'"
```
3. Restart container:
```bash
cd tools
./containermod --stop --name nginx-rtmp --caster JohnDoe
./containermod --start --name nginx-rtmp --caster JohnDoe --channel mainchannel --game csgo
```

**FFmpeg crashed:**
Check `/opt/nginx/logs/error.log` for nginx-rtmp restart errors. May need to rebuild container with fixed config.

---

## Container Issues

### Container Won't Start

**Symptom:** `docker start <container>` fails or container immediately exits

**Diagnosis:**

```bash
docker logs <container_name>
docker inspect <container_name>
```

**Common causes:**

1. **Environment variables missing:**
```bash
echo $FQDN
echo $MYSQL_ROOT_PASSWORD
# Should output values, not empty
```

Solution:
```bash
source /etc/profile.d/stream.sh
```

2. **Port already in use:**
```bash
netstat -tlnp | grep <port>
# Or
sudo lsof -i :<port>
```

Solution: Stop conflicting service or change port.

3. **Docker network issue:**
```bash
docker network ls
docker network inspect stream_network
```

Solution:
```bash
docker network create stream_network
```

4. **Volume mount missing:**
```bash
ls -la /opt/haproxy
ls -la /opt/rtmp
```

Solution: Create directories or check permissions.

**Generic restart:**
```bash
cd tools
./containermod --stop --name <container>
./containermod --start --name <container>
```

### Container Constantly Restarting

**Symptom:** Container status shows "Restarting"

**Diagnosis:**

```bash
docker ps -a
docker logs <container_name>
```

**Common causes:**

1. **Application crash loop** - Check logs for errors
2. **Health check failing** - Application not responding
3. **Resource exhaustion** - Out of memory

**Solutions:**

**Stop restart loop:**
```bash
docker update --restart=no <container_name>
docker stop <container_name>
```

**Fix issue, then:**
```bash
cd tools
./containermod --start --name <container>
```

### Out of Disk Space

**Symptom:** Containers fail, errors about "no space left on device"

**Diagnosis:**

```bash
df -h
docker system df
```

**Solutions:**

**Clean up Docker resources:**
```bash
# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Remove everything unused
docker system prune -a --volumes -f
```

**Clean up stream delay files:**
```bash
# Check size
du -sh /opt/rtmp/workdir

# Remove old files
find /opt/rtmp/workdir -name "*.flv" -mtime +1 -delete
```

**Expand disk:**
- Resize VM disk in cloud provider
- Extend filesystem

---

## HAProxy Issues

### HAProxy Won't Start

**Diagnosis:**

```bash
docker logs haproxy
```

**Common causes:**

1. **Configuration syntax error:**
```bash
docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

Solution: Fix syntax in `/opt/haproxy/haproxy.cfg`

2. **SSL certificate missing:**
```bash
docker exec haproxy ls -la /etc/haproxy/certs/live/$FQDN/
```

Solution: Generate certificate:
```bash
docker exec haproxy /usr/local/bin/certbot certonly --standalone -d stream.yourdomain.com
```

3. **Port conflict:**
```bash
sudo lsof -i :443
sudo lsof -i :48001
```

Solution: Stop conflicting service.

### HAProxy Not Routing Traffic

**Diagnosis:**

```bash
# Check routing config
docker exec haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep "::.*::"
```

**Solutions:**

**Missing route:**
```bash
cd tools
./haproxy_configmod --add --caster JohnDoe --port 48001
./haproxy_configmod --reload
```

**Backend down:**
```bash
docker ps | grep nginx-rtmp-JohnDoe
# If not running, start it:
./containermod --start --name nginx-rtmp --caster JohnDoe --channel mainchannel --game csgo
```

### HAProxy Reload Fails

**Symptom:** Changes not taking effect, or HAProxy crashes

**Diagnosis:**

```bash
docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

**Solution:**

**Syntax error:** Fix `/opt/haproxy/haproxy.cfg`, then:
```bash
docker exec haproxy killall -HUP haproxy
```

**Reload stuck:**
```bash
docker restart haproxy
```

---

## Database Issues

### MySQL Not Responding

**Symptom:** Tools fail with "Can't connect to MySQL server"

**Diagnosis:**

```bash
docker ps | grep mysql
docker logs mysql
```

**Solutions:**

**MySQL not running:**
```bash
cd tools
./containermod --start --name mysql
```

**MySQL crashed:**
```bash
docker logs mysql | tail -50
```

Look for:
- Out of memory
- Corrupted tables
- Wrong password

**Restart MySQL:**
```bash
./containermod --restart --name mysql
```

**Reset MySQL password:**
```bash
docker exec -it mysql mysql -uroot
# Inside MySQL:
ALTER USER 'root'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

Update environment:
```bash
export MYSQL_ROOT_PASSWORD="new_password"
```

### Database Corruption

**Symptom:** Queries fail, tables unreadable

**Diagnosis:**

```bash
docker exec mysql mysqlcheck -uroot -p$MYSQL_ROOT_PASSWORD --all-databases
```

**Solution:**

**Repair tables:**
```bash
docker exec mysql mysqlcheck -uroot -p$MYSQL_ROOT_PASSWORD --repair --all-databases
```

**Restore from backup:**
```bash
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < backup.sql
```

---

## Twitch API Issues

### Token Expired

**Symptom:** Twitch API calls fail with 401 Unauthorized

**Solution:**

```bash
cd tools
./channelmod --refresh-tokens mainchannel
```

If refresh fails, get new tokens from [twitchtokengenerator.com](https://twitchtokengenerator.com):
```bash
./channelmod --set mainchannel access_token "new_token"
./channelmod --set mainchannel refresh_token "new_refresh_token"
```

### Wrong Twitch Category

**Symptom:** Stream shows wrong game on Twitch

**Cause:** Game display name doesn't match Twitch exactly

**Solution:**

Update game display name to match Twitch:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE games SET display_name = 'Counter-Strike: Global Offensive' WHERE technical = 'csgo'"
```

Check Twitch for exact spelling and capitalization.

---

## Stream Quality Issues

### Pixelated or Low-Quality Stream

**Causes:**

1. **OBS encoding settings too low**
2. **Server bandwidth limited**
3. **FFmpeg transcoding** (if enabled)

**Solutions:**

**Check OBS settings:**
- Bitrate: 6000 Kbps recommended
- Encoder: x264 or NVENC
- Preset: veryfast or faster

**Check server bandwidth:**
```bash
# Install iftop
sudo apt install iftop

# Monitor bandwidth
sudo iftop -i eth0
```

**Disable transcoding:**
Edit nginx-rtmp config to use `-c copy` (copy codecs, no transcode).

### Stream Buffering or Stuttering

**Causes:**

1. **Network issues (streamer → server)**
2. **Server CPU overload**
3. **Twitch ingest issues**

**Diagnosis:**

**Check server CPU:**
```bash
top
docker stats
```

**Check network:**
```bash
# Packet loss test
ping -c 100 stream.yourdomain.com

# Bandwidth test
iperf3 -c stream.yourdomain.com
```

**Check FFmpeg:**
```bash
docker exec nginx-rtmp-JohnDoe tail -f /opt/nginx/logs/ffmpeg.log
```

Look for:
- `frame drops`
- `speed < 1.0x` (encoding slower than realtime)

**Solutions:**

**Reduce concurrent streams:**
Stop unused containers to free CPU.

**Upgrade server:**
More CPU cores, RAM.

**Change Twitch ingest:**
Try different Twitch server (automatic with `live.twitch.tv`).

---

## Delay Issues

### Delay Not Working

**Symptom:** Stream appears on Twitch immediately, no delay

**Diagnosis:**

1. **Check game delay setting:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT technical, delay FROM games WHERE technical = 'csgo'"
```

2. **Check container type:**
```bash
docker ps | grep nginx-rtmp-JohnDoe
docker exec nginx-rtmp-JohnDoe cat /opt/nginx/conf/nginx.conf
```

Should show `record all` (delay mode), not `exec_push` (instant mode).

**Solutions:**

**Wrong container type:**
Restart with correct game:
```bash
cd tools
./containermod --stop --name nginx-rtmp --caster JohnDoe
./containermod --start --name nginx-rtmp --caster JohnDoe --channel mainchannel --game csgo
```

**Game delay set to 0:**
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE games SET delay = 480 WHERE technical = 'csgo'"
```

### Delay Too Long or Too Short

**Diagnosis:**

```bash
# Check game setting
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT technical, delay FROM games WHERE technical = 'csgo'"

# Check stream_delayer.py settings
docker exec nginx-rtmp-JohnDoe cat /opt/rtmp/delayer_settings.py
```

**Solution:**

Update delay:
```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE games SET delay = 600 WHERE technical = 'csgo'"
```

Restart container to apply.

### stream_delayer.py Not Running

**Symptom:** Recording files accumulate in `/opt/rtmp/workdir`, never published

**Diagnosis:**

```bash
# Check if running
docker exec nginx-rtmp-JohnDoe ps aux | grep stream_delayer

# Check logs
docker exec nginx-rtmp-JohnDoe tail -f /opt/rtmp/stream_delayer.log
```

**Solution:**

```bash
# Restart container
cd tools
./containermod --restart --name nginx-rtmp --caster JohnDoe
```

---

## SSL Certificate Issues

### Let's Encrypt Validation Fails

**Symptom:** HAProxy fails to start, no SSL certificate

**Causes:**

1. **Port 80 not accessible**
2. **DNS not pointing to server**
3. **Domain ownership verification failed**

**Diagnosis:**

```bash
docker logs haproxy | grep certbot
```

**Solutions:**

**Check DNS:**
```bash
nslookup stream.yourdomain.com
# Should resolve to server IP
```

**Check port 80:**
```bash
curl http://stream.yourdomain.com
# Should respond (even if redirects)
```

**Manual certificate request:**
```bash
docker exec -it haproxy /usr/local/bin/certbot certonly --standalone -d stream.yourdomain.com -d www.stream.yourdomain.com
```

### Certificate Expired

**Symptom:** HTTPS connections fail with "certificate expired"

**Note:** The HAProxy container automatically renews certificates every 12 hours. If expired, the automatic renewal may have failed.

**Solution - Force fresh certificate:**
```bash
# Delete old certificates
sudo rm -rf /opt/letsencrypt/*

# Restart HAProxy (fetches new certificate automatically)
docker restart haproxy
```

**Check certificate provisioning:**
```bash
docker logs -f haproxy
# Watch for certbot messages during startup
```

---

## General Debugging Tips

### Enable Debug Logging

**nginx-rtmp:**
Edit `nginx.conf`, change:
```nginx
error_log /opt/nginx/logs/error.log debug;
```

Rebuild container.

**HAProxy:**
Edit `haproxy.cfg`, add to global:
```haproxy
global
    log stdout local0 debug
```

Restart HAProxy.

### Test Connectivity

**RTMP test:**
```bash
ffmpeg -re -i test.mp4 -c copy -f flv rtmp://stream.yourdomain.com:48001/JohnDoe/JohnDoe-abc123def456
```

**HTTP test:**
```bash
curl -I https://stream.yourdomain.com
curl http://localhost/rtmp/auth.php?name=JohnDoe&key=test
```

### Network Packet Capture

```bash
# Install tcpdump
sudo apt install tcpdump

# Capture RTMP traffic
sudo tcpdump -i eth0 -w rtmp-capture.pcap port 48001

# Analyze with Wireshark
```

### Emergency Recovery

**Stop everything:**
```bash
docker stop $(docker ps -q)
```

**Start base infrastructure only:**
```bash
cd tools
./containermod --start --name mysql
./containermod --start --name nginx-http
./containermod --start --name php-fpm
./containermod --start --name haproxy
```

**Check each service individually:**
```bash
docker logs <container>
```

---

[Back to Wiki Home](Home)
