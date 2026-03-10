# Building Docker Images

Guide for building and distributing Docker images for RTMP Proxy Server.

## Overview

The project includes build scripts in `tools/images/` for all components:
- **haproxy** - Front-end routing and SSL
- **mysql** - Database
- **nginx-http** - HTTP server
- **nginx-rtmp** - RTMP relay
- **php-fpm** - PHP processor

## Build Modes

### 1. Local-Only (Default)

Build images locally without pushing to any registry. Best for development and testing.

```bash
cd tools
./build_all_images.sh v1.6
```

**Images created:**
- `haproxy:latest`
- `mysql:latest`
- `nginx-http:latest`
- `nginx-rtmp:latest`
- `php-fpm:latest`

**Use case:**
- Local development
- Testing changes
- No need for image distribution

### 2. Docker Hub

Build and push to Docker Hub for easy distribution.

```bash
export DOCKER_USERNAME="yourdockerhubusername"
docker login
cd tools
./build_all_images.sh v1.6
```

**Images pushed:**
- `yourdockerhubusername/haproxy:v1.6`
- `yourdockerhubusername/mysql:v1.6`
- `yourdockerhubusername/nginx-http:v1.6`
- `yourdockerhubusername/nginx-rtmp:v1.6`
- `yourdockerhubusername/php-fpm:v1.6`

**Use case:**
- Public or private distribution
- Multiple servers pulling same images
- Team deployment

**Prerequisites:**
1. Docker Hub account
2. Logged in: `docker login`

### 3. Custom Registry

Build and push to a custom registry (GitLab, private registry, etc.).

```bash
export REGISTRY_URL="registry.gitlab.com/youruser/yourproject"
docker login registry.gitlab.com
cd tools
./build_all_images.sh v1.6
```

**Images pushed:**
- `registry.gitlab.com/youruser/yourproject/haproxy:v1.6`
- `registry.gitlab.com/youruser/yourproject/mysql:v1.6`
- etc.

**Use case:**
- Private hosting
- GitLab CI/CD integration
- Corporate registry

**Prerequisites:**
1. Registry access
2. Logged in: `docker login <registry-url>`

## Environment Variables

Configure build behavior with environment variables:

| Variable | Purpose | Example |
|----------|---------|---------|
| `DOCKER_USERNAME` | Docker Hub username | `export DOCKER_USERNAME="myuser"` |
| `REGISTRY_URL` | Custom registry URL | `export REGISTRY_URL="registry.example.com/project"` |
| Neither set | Local build only | No export needed |

**Priority:** If both are set, `REGISTRY_URL` takes precedence.

## Version Tags

Specify version tag as first argument:

```bash
# Production release
./build_all_images.sh v1.7

# Development build
./build_all_images.sh dev

# Default to "devel" if omitted
./build_all_images.sh
```

## Build Options

Pass Docker build options as second parameter:

```bash
# No cache
./build_all_images.sh v1.6 --no-cache

# Plain progress output
./build_all_images.sh v1.6 --progress=plain

# Multiple options (quote them)
./build_all_images.sh v1.6 "--no-cache --progress=plain"
```

Common options:
- `--no-cache` - Build from scratch, ignore cache
- `--progress=plain` - Verbose output
- `--pull` - Always pull base images
- `--platform linux/amd64` - Specific platform

### Configuring Timezone

All containers default to UTC timezone. Override with `--build-arg TZ`:

```bash
# Use Europe/Helsinki timezone
./build_all_images.sh v1.6 "--build-arg TZ=Europe/Helsinki"

# Use builder's current timezone
./build_all_images.sh v1.6 "--build-arg TZ=$(cat /etc/timezone)"

# Or with additional options
./build_all_images.sh v1.6 "--no-cache --build-arg TZ=America/New_York"
```

**Supported timezones:** Any valid IANA timezone (e.g., `America/New_York`, `Asia/Tokyo`, `Europe/London`)

**Note:** Timezone is set at build time. Changing timezone requires rebuilding images.

## Building Individual Components

Build one component at a time:

```bash
cd tools/images

# HAProxy
./build_haproxy.sh v1.6

# MySQL
./build_mysql.sh v1.6

# nginx-http
./build_nginx-http.sh v1.6

# nginx-rtmp
./build_nginx-rtmp.sh v1.6

# php-fpm
./build_php-fpm.sh v1.6
```

Same environment variables apply.

## Complete Workflows

### Development Workflow

Build and test locally without any registry:

```bash
# Ensure no registry variables are set
unset DOCKER_USERNAME
unset REGISTRY_URL

cd tools

# Build latest changes locally
./build_all_images.sh dev

# Start containers with local images
./containermod --start --all

# Test...

# Rebuild after changes
./build_all_images.sh dev --no-cache

# Restart containers
./containermod --restart --all
```

### Production Release to Docker Hub

```bash
# Set Docker Hub username
export DOCKER_USERNAME="mycompany"

# Log in to Docker Hub
docker login

# Build and push all images
cd tools
./build_all_images.sh v1.7

# Verify images are available
docker search mycompany/haproxy
```

**Update deployment:**
```bash
# On production server
export DOCKER_USERNAME="mycompany"

# Update version in environment
export HAPROXY_VERSION="v1.7"
export MYSQL_VERSION="v1.7"
export NGINX_HTTP_VERSION="v1.7"
export NGINX_RTMP_VERSION="v1.7"
export PHP_FPM_VERSION="v1.7"

# Pull new images
docker pull $DOCKER_USERNAME/haproxy:$HAPROXY_VERSION
docker pull $DOCKER_USERNAME/mysql:$MYSQL_VERSION
# etc.

# Restart containers
cd tools
./containermod --restart --all
```

### GitLab Registry Workflow

```bash
# Set registry URL
export REGISTRY_URL="registry.gitlab.com/mycompany/rtmp-proxy"

# Log in to GitLab registry
docker login registry.gitlab.com

# Build and push
cd tools
./build_all_images.sh v1.7

# Images now at:
# registry.gitlab.com/mycompany/rtmp-proxy/haproxy:v1.7
# registry.gitlab.com/mycompany/rtmp-proxy/mysql:v1.7
# etc.
```

**GitLab CI/CD Integration:**

Create `.gitlab-ci.yml`:
```yaml
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - export REGISTRY_URL=$CI_REGISTRY_IMAGE
    - cd tools
    - ./build_all_images.sh $CI_COMMIT_TAG
  only:
    - tags
```

### Mixed Approach

Build locally, then push manually:

```bash
# Build locally
cd tools
./build_all_images.sh v1.7

# Test locally...

# Later, manually tag and push to Docker Hub
export DOCKER_USERNAME="mycompany"
docker login

docker tag haproxy:latest $DOCKER_USERNAME/haproxy:v1.7
docker push $DOCKER_USERNAME/haproxy:v1.7

docker tag mysql:latest $DOCKER_USERNAME/mysql:v1.7
docker push $DOCKER_USERNAME/mysql:v1.7

# etc. for all images
```

## Using Built Images

After building images, `containermod` automatically detects and uses them based on environment configuration.

### Environment Configuration

Edit `/etc/profile.d/stream.sh`:

**For local images only:**
```bash
# No DOCKER_USERNAME or REGISTRY_URL needed
export HAPROXY_VERSION="v1.7"
export MYSQL_VERSION="v1.7"
export NGINX_HTTP_VERSION="v1.7"
export NGINX_RTMP_VERSION="v1.7"
export PHP_FPM_VERSION="v1.7"
```

**For Docker Hub:**
```bash
export DOCKER_USERNAME="yourusername"
export HAPROXY_VERSION="v1.7"
export MYSQL_VERSION="v1.7"
export NGINX_HTTP_VERSION="v1.7"
export NGINX_RTMP_VERSION="v1.7"
export PHP_FPM_VERSION="v1.7"
```

**For custom registry:**
```bash
export REGISTRY_URL="registry.gitlab.com/youruser/yourproject"
export HAPROXY_VERSION="v1.7"
export MYSQL_VERSION="v1.7"
export NGINX_HTTP_VERSION="v1.7"
export NGINX_RTMP_VERSION="v1.7"
export PHP_FPM_VERSION="v1.7"
```

Reload environment:
```bash
source /etc/profile.d/stream.sh
```

### How containermod Uses Images

The `containermod` script automatically constructs image names based on your configuration:

**Local mode** (no registry vars):
```bash
# Uses: haproxy:latest, mysql:latest, etc.
containermod --start --all
```

**Docker Hub mode** (`DOCKER_USERNAME` set):
```bash
# Uses: yourusername/haproxy:v1.7, yourusername/mysql:v1.7, etc.
# Automatically pulls from Docker Hub
containermod --start --all
```

**Custom registry mode** (`REGISTRY_URL` set):
```bash
# Uses: registry.example.com/project/haproxy:v1.7, etc.
# Automatically pulls from custom registry
containermod --start --all
```

**No manual script editing required** - everything is controlled by environment variables.

## Troubleshooting

### Build Fails with Permission Error

**Error:** `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in (or use newgrp)
newgrp docker

# Verify
docker ps
```

### Push Fails with "unauthorized"

**Error:** `unauthorized: authentication required`

**Solution:**
```bash
# Docker Hub
docker login

# GitLab
docker login registry.gitlab.com

# Custom registry
docker login your-registry.com
```

Ensure your account has push permissions.

### HAProxy Syntax Check Fails

**Error:** `HAProxy config didn't pass validation. Won't push`

**Cause:** HAProxy configuration has syntax errors.

**Solution:**
```bash
# Check configuration manually
docker run --rm -v /path/to/haproxy.cfg:/test.cfg haproxy:latest haproxy -c -f /test.cfg

# Common issues:
# - Missing environment variables in template
# - Invalid frontend/backend configuration
# - Port conflicts
```

Edit `haproxy/haproxy.cfg` or templates, then rebuild.

### Wrong Registry Used

**Problem:** Images pushed to wrong registry.

**Check environment:**
```bash
echo $DOCKER_USERNAME
echo $REGISTRY_URL
```

**Clear and set correctly:**
```bash
# Clear
unset DOCKER_USERNAME
unset REGISTRY_URL

# Set correct one
export DOCKER_USERNAME="correct-username"
# OR
export REGISTRY_URL="correct-registry.com/project"
```

### Build Hangs or Runs Slowly

**Causes:**
1. Large base image downloads
2. No build cache
3. Network issues

**Solutions:**
```bash
# Use build cache (remove --no-cache if present)
./build_all_images.sh v1.7

# Pull base images first
docker pull nginx:latest
docker pull mysql:8.0
docker pull php:8.1-fpm

# Check network
ping registry-1.docker.io
```

### Disk Space Issues

**Error:** `no space left on device`

**Check space:**
```bash
df -h
docker system df
```

**Clean up:**
```bash
# Remove unused images
docker image prune -a

# Remove build cache
docker builder prune

# Full cleanup
docker system prune -a --volumes
```

### Image Not Found on Pull

**Problem:** `Error response from daemon: manifest for ... not found`

**Causes:**
1. Image not pushed to registry
2. Wrong tag/version
3. Registry authentication failed

**Verify:**
```bash
# Check if image exists locally
docker images | grep haproxy

# Check Docker Hub
docker search $DOCKER_USERNAME/haproxy

# Try manual pull
docker pull $DOCKER_USERNAME/haproxy:v1.7
```

### Local Image Not Found

**Error:** `ERROR: Local image haproxy:latest not found. Build it first`

**Cause:** Trying to use local images that haven't been built yet.

**Solution:**
```bash
# Build images locally first
cd tools
./build_all_images.sh v1.7

# Then start containers
./containermod --start --all
```

### Wrong Registry Mode

**Problem:** containermod pulling from wrong registry or using wrong images.

**Check current mode:**
```bash
echo "DOCKER_USERNAME: $DOCKER_USERNAME"
echo "REGISTRY_URL: $REGISTRY_URL"

# If both empty: local mode
# If DOCKER_USERNAME set: Docker Hub mode
# If REGISTRY_URL set: custom registry mode
```

**Fix:**
```bash
# Switch to local mode
unset DOCKER_USERNAME
unset REGISTRY_URL

# Switch to Docker Hub
export DOCKER_USERNAME="youruser"
unset REGISTRY_URL

# Switch to custom registry
export REGISTRY_URL="registry.example.com/project"
unset DOCKER_USERNAME

# Apply changes
source /etc/profile.d/stream.sh
```

## Best Practices

### Version Tagging

Use semantic versioning:
- `v1.0` - Major release
- `v1.1` - Minor release with new features
- `v1.1.1` - Patch release for bug fixes

Tag both specific version and `latest`:
```bash
./build_all_images.sh v1.7
docker tag $DOCKER_USERNAME/haproxy:v1.7 $DOCKER_USERNAME/haproxy:latest
docker push $DOCKER_USERNAME/haproxy:latest
```

### Security

**Don't include secrets in images:**
- Environment variables for passwords
- Volume mounts for config files
- Use Docker secrets or environment files

**Scan images:**
```bash
# Trivy scanner
trivy image haproxy:latest

# Docker scan
docker scan haproxy:latest
```

### Multi-Platform Builds

Build for multiple architectures:
```bash
# Enable buildx
docker buildx create --use

# Build for multiple platforms
./build_all_images.sh v1.7 "--platform linux/amd64,linux/arm64"
```

### Build Automation

**GitHub Actions:**
Create `.github/workflows/build-images.yml`:
```yaml
name: Build Docker Images

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        env:
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
        run: |
          cd tools
          ./build_all_images.sh ${{ github.ref_name }}
```

---

[Back to Wiki Home](Home)
