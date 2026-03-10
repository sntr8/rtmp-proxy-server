# Ansible Deployment

Automated deployment and configuration management using Ansible.

## Prerequisites

- Ansible 2.9+ installed on your local machine
- SSH access to target server(s)
- Root or sudo access on target servers
- Target servers running Debian 11+ or Ubuntu 20.04+

## Installation

### Install Ansible

**macOS:**
```bash
brew install ansible
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ansible
```

**Python pip:**
```bash
pip3 install ansible
```

### Install Required Collections

```bash
ansible-galaxy collection install community.docker
```

## Configuration

### 1. Create Inventory File

Copy the example inventory and customize:

```bash
cd ansible
cp inventory.example inventory
vi inventory
```

**Example inventory:**
```ini
[stream]
stream.example.com ansible_user=root

[stream:vars]
# Domain configuration
fqdn=stream.example.com
admin_email=admin@example.com

# MySQL configuration
mysql_user=stream_user
mysql_password=secure_password_here
mysql_root_password=secure_root_password_here
mysql_database=stream

# Twitch API credentials
twitch_client_id=your_client_id
twitch_access_token=your_access_token
twitch_refresh_token=your_refresh_token

# Container versions
haproxy_version=v1.6
mysql_version=v1.6
nginx_http_version=v1.6
nginx_rtmp_version=v1.6
php_fpm_version=v1.6
```

See `ansible/inventory.example` for complete configuration options.

### 2. Configure Docker Registry (Choose One)

**Option A: Local Images Only** (Default)
```ini
# Leave docker_username and registry_url undefined
# Build images locally on server after deployment
```

**Option B: Docker Hub**
```ini
docker_username=your_dockerhub_username
docker_password=your_dockerhub_token
```

**Option C: Custom Registry**
```ini
registry_url=registry.gitlab.com/youruser/yourproject
registry_username=your_username
registry_password=your_token
```

## Usage

### Initial Deployment

Deploy to a fresh server:

```bash
cd ansible
ansible-playbook -i inventory playbook.yml
```

**What it does:**
1. Installs Docker and prerequisites
2. Clones RTMP Proxy Server repository to `/opt/rtmp-proxy-server`
3. Configures environment variables in `/etc/profile.d/stream.sh`
4. Sets up directory structure
5. Configures cron jobs for automation
6. Logs into Docker registry (if configured)

### Updating Deployment

Update an existing server:

```bash
ansible-playbook -i inventory playbook.yml --tags=upgrade
```

**What it does:**
1. Pulls latest code from git repository
2. Updates environment variables
3. Updates tools permissions

### Specific Tasks

**Only provision (skip Docker):**
```bash
ansible-playbook -i inventory playbook.yml --tags=provision
```

**Only Docker setup:**
```bash
ansible-playbook -i inventory playbook.yml --tags=docker
```

**Dry run (check what would change):**
```bash
ansible-playbook -i inventory playbook.yml --check
```

## Post-Deployment Steps

After Ansible completes, environment variables are automatically available in all shells.

**Complete the setup by following the Installation Guide:**

SSH to your server:
```bash
ssh root@stream.example.com
cd /opt/rtmp-proxy-server
```

Then follow the [Installation Guide](Installation.md) starting from:
- **[Step 3: Build Docker Images](Installation.md#step-3-build-docker-images)**
- **[Step 4: Initialize Database](Installation.md#step-4-initialize-database)**
- **[Step 5: Add Twitch Channels](Installation.md#step-5-add-twitch-channels)**
- **[Step 6: Start Base Infrastructure](Installation.md#step-6-start-base-containers)**
- **[Step 7: Add Casters](Installation.md#step-7-add-streamers-casters)**
- **[Step 8: Schedule Streams](Installation.md#step-8-schedule-streams)**

All environment variables configured in your Ansible inventory are automatically available in all shells.

## Ansible Roles

### provision

Handles basic server setup:
- Creates optional admin user with sudo
- Installs required packages (git, vim, curl, jq)
- Clones RTMP Proxy repository
- Sets environment variables
- Configures cron jobs for automation

### docker

Installs and configures Docker:
- Adds Docker official repository
- Installs Docker CE 29.3.0 and containerd.io 2.2.1
- Logs into Docker registry (if configured)
- Ensures Docker service is running

## Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `fqdn` | Server domain name | `stream.example.com` |
| `admin_email` | Email for Let's Encrypt | `admin@example.com` |
| `mysql_user` | MySQL username | `stream_user` |
| `mysql_password` | MySQL user password | `secure_password` |
| `mysql_root_password` | MySQL root password | `root_password` |
| `mysql_database` | Database name | `stream` |
| `twitch_client_id` | Twitch API client ID | From twitchtokengenerator.com |
| `twitch_access_token` | Twitch access token | From twitchtokengenerator.com |
| `twitch_refresh_token` | Twitch refresh token | From twitchtokengenerator.com |
| `haproxy_version` | HAProxy image version | `v1.6` |
| `mysql_version` | MySQL image version | `v1.6` |
| `nginx_http_version` | nginx-http image version | `v1.6` |
| `nginx_rtmp_version` | nginx-rtmp image version | `v1.6` |
| `php_fpm_version` | php-fpm image version | `v1.6` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `system_user` | Admin username to create | undefined (not created) |
| `docker_username` | Docker Hub username | undefined (local images) |
| `docker_password` | Docker Hub password/token | undefined |
| `registry_url` | Custom registry URL | undefined |
| `registry_username` | Custom registry username | undefined |
| `registry_password` | Custom registry password | undefined |
| `git_repo` | Git repository URL | github.com/sntr8/rtmp-proxy-server.git |
| `git_branch` | Git branch to clone | `main` |
| `discord_webhook` | Discord webhook URL | undefined |
| `discord_support_group` | Discord role/user ID | undefined |
| `docker_version` | Docker CE version | `5:29.3.0-1~...` |
| `containerdio_version` | containerd.io version | `2.2.1-1` |

## Troubleshooting

### Test SSH Connection

```bash
ansible stream -i inventory -m ping
```

**Expected output:**
```
stream.example.com | SUCCESS => {
    "ping": "pong"
}
```

### Docker Installation Fails

**Error:** "Repository not found"

**Cause:** Unsupported OS version

**Solution:** Check your server's OS:
```bash
ansible stream -i inventory -m setup -a "filter=ansible_distribution*"
```

Ansible supports Debian 11+, Ubuntu 20.04+.

### Permission Denied

**Error:** "sudo: a password is required"

**Solution:** Ensure ansible_user has passwordless sudo:
```bash
# On server
echo "ansible_user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible_user
```

Or use `--ask-become-pass`:
```bash
ansible-playbook -i inventory playbook.yml --ask-become-pass
```

### Variables Not Applied

**Error:** Environment variables not set correctly

**Solution:**
1. Ensure variables are under `[stream:vars]` section in inventory
2. Check syntax (no spaces around `=`)
3. Run with verbose mode: `ansible-playbook -i inventory playbook.yml -vvv`

### Git Clone Fails

**Error:** "Permission denied (publickey)"

**Cause:** Private repository without SSH key

**Solution:** Use HTTPS with token:
```ini
git_repo=https://token@github.com/youruser/rtmp-proxy-server.git
```

## Security Best Practices

### Use Ansible Vault for Secrets

Encrypt sensitive variables:

```bash
# Create encrypted inventory
ansible-vault create inventory

# Or encrypt existing file
ansible-vault encrypt inventory

# Run with vault password
ansible-playbook -i inventory playbook.yml --ask-vault-pass
```

**Store vault password in file:**
```bash
echo "your_vault_password" > .vault_password
chmod 600 .vault_password

# Add to .gitignore
echo ".vault_password" >> .gitignore

# Run without prompting
ansible-playbook -i inventory playbook.yml --vault-password-file .vault_password
```

### Use SSH Keys

Don't use passwords for SSH:

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "ansible@local"

# Copy to server
ssh-copy-id root@stream.example.com

# Test
ssh root@stream.example.com
```

### Limit Root Access

After initial setup, use a non-root user:

```ini
[stream:vars]
ansible_user=admin
ansible_become=yes
ansible_become_method=sudo
```

## Workflows

### Complete Deployment

```bash
# 1. Initial deployment
cd ansible
ansible-playbook -i inventory playbook.yml

# 2. SSH to server and complete setup
ssh root@stream.example.com

# 3. Build images
cd /opt/rtmp-proxy-server/tools
./build_all_images.sh v1.6

# 4. Initialize database
./containermod --start --name mysql
docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE < ../mysql/db/schema.sql

# 5. Start infrastructure
./containermod --start --all

# 6. Add channels, casters, games
# (See Installation guide)
```

### Updating Production

```bash
# 1. Update code
cd ansible
ansible-playbook -i inventory playbook.yml --tags=upgrade

# 2. Rebuild images (if needed)
ssh root@stream.example.com
cd /opt/rtmp-proxy-server/tools
./build_all_images.sh v1.7

# 3. Restart containers
./containermod --restart --all
```

### Rolling Back

```bash
# SSH to server
ssh root@stream.example.com

# Checkout previous version
cd /opt/rtmp-proxy-server
git log --oneline
git checkout <commit-hash>

# Rebuild images
cd tools
./build_all_images.sh v1.6

# Restart
./containermod --restart --all
```

## See Also

- [Installation Guide](Installation.md) - Manual installation steps
- [Building Images](Building-Images.md) - Docker image management
- [Management Tools](Management-Tools.md) - Server management commands
- [Configuration](Configuration.md) - System configuration

---

[Back to Wiki Home](Home)
