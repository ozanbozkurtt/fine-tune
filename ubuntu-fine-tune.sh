#!/bin/bash

systemctl stop apt-daily.timer apt-daily-upgrade.timer
systemctl disable apt-daily.timer apt-daily-upgrade.timer
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades

# APT otomatik güncellemelerini devre dışı bırak
cat << 'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF


TIMEZONE="Europe/Istanbul"
timedatectl set-timezone $TIMEZONE
timedatectl set-ntp true

apt update -y && apt upgrade -y
apt autoremove -y

NET_INTERFACE="ens160"
RING_BUFFER_SIZE=4096

# tx off
ethtool -K $NET_INTERFACE tx off
# tx-checksum-ip-generic off
ethtool -K $NET_INTERFACE tx-checksum-ip-generic off

ethtool -G $NET_INTERFACE rx $RING_BUFFER_SIZE tx $RING_BUFFER_SIZE

SYSCTL_CONF="/etc/sysctl.conf"
cp $SYSCTL_CONF ${SYSCTL_CONF}.bak.$(date +%F)

cat << EOF >> $SYSCTL_CONF

vm.swappiness = 10 

vm.vfs_cache_pressure = 50

# Connection tracking table size
net.netfilter.nf_conntrack_max = 262144

# File descriptor ve inotify limitleri
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Shared memory
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# Ağ (Yüksek trafik için)
net.core.netdev_max_backlog = 16384
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

# Bash history ayarları
BASHRC="/etc/bash.bashrc"
cp $BASHRC ${BASHRC}.bak.$(date +%F)

cat << 'EOF' >> $BASHRC

# History ayarları
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF

# Journald log ayarları (disk kullanımını sınırla)
JOURNALD_CONF="/etc/systemd/journald.conf"
cp $JOURNALD_CONF ${JOURNALD_CONF}.bak.$(date +%F)

sed -i 's/#SystemMaxUse=/SystemMaxUse=500M/' $JOURNALD_CONF
sed -i 's/#SystemMaxFileSize=/SystemMaxFileSize=50M/' $JOURNALD_CONF
sed -i 's/#MaxRetentionSec=/MaxRetentionSec=1month/' $JOURNALD_CONF

systemctl restart systemd-journald

# Monitoring araçları
apt install -y htop iotop nethogs ncdu dstat

# Disk I/O scheduler optimizasyonu (SSD için)
echo "none" > /sys/block/sda/queue/scheduler 2>/dev/null || echo "noop" > /sys/block/sda/queue/scheduler 2>/dev/null

# Persistent scheduler ayarı
cat << 'EOF' > /etc/udev/rules.d/60-scheduler.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"
EOF
