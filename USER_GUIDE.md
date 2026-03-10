# Streamer User Guide

This guide is for streamers who have been given access to an RTMP Proxy Server.

## What You'll Need

Your server administrator will provide:
- **Your nickname** (e.g., JohnDoe)
- **Your stream key** (e.g., JohnDoe-abc123def456)
- **Server address** (e.g., stream.example.com)
- **Port number** (e.g., 48001) - This is specific to your assigned channel

**Important:** Each streaming channel uses a dedicated port. The port is assigned based on which Twitch channel you're streaming to, not your individual nickname.

## Setting up OBS Studio

1. Open **OBS Studio**
2. Go to **Settings > Stream**
3. Configure as follows:

```
Service:     Custom...
Server:      rtmp://stream.example.com:PORT/<your-nickname>/
Stream Key:  <your-stream-key>
```

**Example:**
```
Service:     Custom...
Server:      rtmp://stream.example.com:48001/JohnDoe/
Stream Key:  JohnDoe-abc123def456
```

### Understanding Ports

The port number (e.g., `48001`) corresponds to the **Twitch channel** you're streaming to:
- **48001-48010**: Main streaming channels (sent to Twitch)
- **48101-48110**: Proxy channels (internal relay, not sent to Twitch)

**Why ports?**
- Each Twitch channel has a dedicated port for technical reasons
- The server uses port-based routing to direct your stream to the correct destination
- Multiple streamers can use the same port if they're scheduled at different times
- Your admin assigns you a port based on your scheduled stream

**Finding your port:**
- Check your scheduled stream details (Discord notification or admin)
- Ask your admin: "Which channel am I streaming to?"
- Common: Main channel = 48001, Secondary channel = 48002, etc.

### Important Settings

- **DO NOT enable delay in OBS** - The server handles delay automatically
- Use your normal OBS encoding settings (resolution, bitrate, etc.)
- The server will relay your stream to Twitch automatically

### Delays

The server may apply automatic delays based on the game being played:
- **Competitive games** (PUBG, CS:GO, etc.): Usually 8-minute delay
- **Non-competitive games** (Rocket League, etc.): No delay (instant)

This prevents stream sniping in competitive scenarios while allowing real-time interaction for casual games.

## Scheduled Streams

Your streams are typically scheduled in advance by administrators. You'll receive notifications:
- **30 minutes before**: Container starts, you can connect OBS
- **At start time**: Begin streaming
- **30 minutes after end time**: Container stops automatically

Connect to OBS a few minutes before your scheduled time to verify everything works.

## Monitoring Your Stream (VLC)

If you or a co-caster need to monitor the live stream without delay (for coordination), use VLC Media Player:

1. Open **VLC Media Player**
2. Press **CTRL+N** (or Media > Open Network Stream)
3. Enter the URL (with the same port as your OBS):
   ```
   rtmp://stream.example.com:PORT/<your-nickname>/<your-stream-key>
   ```
4. Check **Show more options**
5. Set **Caching** to **500ms**
6. Click **Play**

**Example:**
```
URL:      rtmp://stream.example.com:48001/JohnDoe/JohnDoe-abc123def456
Caching:  500ms
```

**Note:** Use the same port number as in your OBS settings.

### VLC Tips

- Delay should be less than 1 second
- Mute the audio to avoid echo if you're streaming yourself
- This is for monitoring only - viewers should watch on Twitch

## Troubleshooting

### OBS says "Failed to connect to server"

**Possible causes:**
1. Wrong server URL or stream key
2. Your scheduled stream hasn't started yet (container not running)
3. Network/firewall blocking port 1935

**Solutions:**
1. Double-check your server URL and stream key
2. Verify your stream is scheduled (check with admin or Discord notifications)
3. Try connecting a few minutes early if scheduled
4. Contact your server administrator

### Stream connects but doesn't appear on Twitch

**Possible causes:**
1. Server routing issue
2. Twitch API token expired
3. Wrong Twitch channel configuration

**Solutions:**
1. Verify you're actually streaming in OBS (recording indicator should be active)
2. Check OBS output settings (1080p @ 6000kbps or lower recommended)
3. Wait 10-15 seconds for stream to appear on Twitch
4. Contact your server administrator

### Audio but no video (or vice versa)

**Possible causes:**
1. OBS encoding settings
2. Firewall/network dropping packets

**Solutions:**
1. Check OBS > Settings > Output > Video Encoder (use x264 or hardware encoder)
2. Verify Audio bitrate is reasonable (128-160kbps)
3. Try lowering bitrate temporarily
4. Check OBS logs for errors

### Stream is laggy or pixelated

**Possible causes:**
1. Bitrate too high for your upload speed
2. Encoding settings too demanding

**Solutions:**
1. Lower bitrate in OBS (start at 3000kbps, increase if stable)
2. Lower resolution (try 720p instead of 1080p)
3. Use faster encoding preset (veryfast or superfast)
4. Check your upload speed: https://speedtest.net

## Best Practices

1. **Test before your scheduled time** - Connect 5-10 minutes early
2. **Use stable internet** - Wired connection is always better than WiFi
3. **Monitor your bitrate** - OBS shows dropped frames if connection is bad
4. **Keep OBS updated** - Use the latest stable version
5. **Have a backup plan** - Know how to contact admin if issues arise

## Getting Help

Contact your server administrator through the designated communication channel (Discord, email, etc.).

When reporting issues, include:
- Your nickname
- Time of the issue
- OBS log file (Help > Log Files > Upload Current Log File)
- Screenshot of error message (if any)

---

## Server Information

This RTMP Proxy Server provides:
- ✅ Centralized authentication (no need to share Twitch keys)
- ✅ Automatic delay management
- ✅ Scheduled stream management
- ✅ Multi-channel routing
- ✅ Professional relay infrastructure
