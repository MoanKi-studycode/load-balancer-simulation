#!/usr/bin/env bash
set -e
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.56.10 to any port 5000 proto tcp
sudo ufw --force enable
sudo ufw status numbered
