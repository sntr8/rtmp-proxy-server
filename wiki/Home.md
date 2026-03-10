# RTMP Proxy Server - Wiki Home

Welcome to the RTMP Proxy Server documentation. This wiki provides comprehensive guides for installation, configuration, and troubleshooting.

## What is RTMP Proxy Server?

A Docker-based streaming proxy that sits between streamers and Twitch, providing:

- **Masked Credentials**: Streamers never see actual Twitch channel keys
- **Stream Delay**: Configurable per-game delays (e.g., 8 minutes for competitive gaming)
- **Centralized Management**: Schedule streams, manage access, automate workflows
- **Multi-Channel Support**: Route multiple streamers to different Twitch channels
- **Advertisement System**: Serve rotating ads via HTTP endpoints

## Documentation Structure

### Getting Started
- **[Installation](Installation)** - Complete setup guide from scratch
- **[Quick Start](Installation#quick-start)** - Fast track for experienced users

### Understanding the System
- **[Architecture](Architecture)** - How RTMP routing works (port-based, HAProxy, containers)
- **[FAQ](FAQ)** - Common questions about routing, ports, and design decisions

### Configuration & Management
- **[Configuration](Configuration)** - Set up games, channels, tokens, and advertisements
- **[Management Tools](Management-Tools)** - Complete reference for all CLI tools

### Operations
- **[Troubleshooting](Troubleshooting)** - Diagnose and fix common issues
- **[Monitoring](Troubleshooting#monitoring)** - Check system health and logs

## Key Concepts

### Port-Based Routing

Unlike typical RTMP servers, this proxy uses **dedicated ports per channel**:

- **48001-48010**: Regular streams (relay to Twitch)
- **48101-48110**: Proxy streams (internal relay only)

Why? HAProxy operates at Layer 4 (TCP) and cannot parse RTMP application names for routing. See [Architecture](Architecture#why-port-based-routing) for details.

### Container Architecture

**Base Infrastructure** (always running):
- **haproxy** - Front-end routing and SSL termination
- **mysql** - Database for casters, channels, games, schedules
- **nginx-http** - Web server for authentication and ads
- **php-fpm** - PHP processor

**Dynamic Stream Containers** (created per broadcast):
- **nginx-rtmp-\<caster\>** - RTMP relay with optional delay
- **nginx-rtmp-proxy-\<caster\>** - Internal proxy (no Twitch output)

### Authentication Flow

1. Streamer connects to `rtmp://server:48001/JohnDoe/<stream-key>`
2. HAProxy routes port 48001 → nginx-rtmp-JohnDoe container
3. nginx-rtmp calls `auth.php` with caster name and stream key
4. auth.php validates against MySQL database
5. If valid, stream is relayed to Twitch (with optional delay)

## Quick Links

- [Main Repository README](../README.md)
- [Administration Guide (admin.md)](../admin.md)
- [User Guide (userguide.md)](../userguide.md)
- [License](../LICENSE)

## Need Help?

1. Check [Troubleshooting](Troubleshooting) guide
2. Review [FAQ](FAQ) for common questions
3. Check container logs (see [Monitoring](Troubleshooting#monitoring))
4. Open an issue on GitHub

## Contributing

See the main [README](../README.md#contributing) for contribution guidelines.
