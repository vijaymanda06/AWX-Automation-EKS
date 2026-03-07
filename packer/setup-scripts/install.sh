#!/bin/bash
set -euo pipefail

echo ">>> Starting Golden AMI Hardening & Setup"

# 1. System Updates
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# 2. Install Essentials
apt-get install -y \
    curl \
    wget \
    unzip \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    gnupg

# 3. Install Docker (Required by user spec)
echo ">>> Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker

# 4. Install AWS SSM Agent (Critical for Zero-Trust access)
echo ">>> Installing AWS SSM Agent"
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# 5. HARDENING: Completely remove SSH (Zero-Trust)
echo ">>> Removing SSH Server (Zero-Trust Model)"
systemctl stop ssh || true
systemctl disable ssh || true
apt-get purge -y openssh-server
apt-get autoremove -y

# 6. Cleanup to reduce AMI size
echo ">>> Cleaning up"
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

echo ">>> Golden AMI Setup Complete!"