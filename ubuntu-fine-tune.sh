#!/bin/bash

systemctl stop apt-daily.timer apt-daily-upgrade.timer
systemctl disable apt-daily.timer apt-daily-upgrade.timer
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades


TIMEZONE="Europe/Istanbul"
timedatectl set-timezone $TIMEZONE
timedatectl set-ntp true

apt update -y && apt upgrade -y
apt autoremove -y

NET_INTERFACE="ens160"

# tx off
ethtool -K $NET_INTERFACE tx off
# tx-checksum-ip-generic off
ethtool -K $NET_INTERFACE tx-checksum-ip-generic off

SYSCTL_CONF="/etc/sysctl.conf"
cp $SYSCTL_CONF ${SYSCTL_CONF}.bak.$(date +%F)

cat << EOF >> $SYSCTL_CONF

vm.swappiness = 10 

vm.vfs_cache_pressure = 50

# Ağ (Yüksek trafik için)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p

LIMITS_CONF="/etc/security/limits.conf"

cat << EOF >> $LIMITS_CONF
* soft nofile 65535
* hard nofile 65535
EOF

