# Ansible Deployment

Automated deployment configuration for RTMP Proxy Server.

## Documentation

Complete Ansible deployment guide is available in the wiki:

**[Ansible Deployment Guide](../wiki/Ansible-Deployment.md)**

## Quick Start

```bash
# 1. Install Ansible and dependencies
ansible-galaxy collection install community.docker

# 2. Configure inventory
cp inventory.example inventory
vi inventory

# 3. Deploy
ansible-playbook -i inventory playbook.yml
```

See the [wiki documentation](../wiki/Ansible-Deployment.md) for detailed instructions.
