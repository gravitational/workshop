#!/bin/bash
set -exuo pipefail

# Setup friendly hostname.
hostname ${hostname}
echo ${hostname} > /etc/hostname
echo "127.0.0.1 ${hostname}" >> /etc/hosts

cat > /etc/apt/sources.list <<EOF
deb http://us.archive.ubuntu.com/ubuntu/ xenial main restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates main restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial universe
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates universe
deb http://us.archive.ubuntu.com/ubuntu/ xenial multiverse
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates multiverse
deb http://us.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu xenial-security main restricted
deb http://security.ubuntu.com/ubuntu xenial-security universe
deb http://security.ubuntu.com/ubuntu xenial-security multiverse
EOF

apt clean && apt update && apt -y purge sshguard && apt -y install \
    nano \
    emacs \
    vim \
    screen \
    git

etcd_disk=sdb
system_disk=sdc
modules="br_netfilter overlay ebtable_filter ip_tables iptable_filter iptable_nat"

mkfs.ext4 /dev/$etcd_disk
mkfs.ext4 /dev/$system_disk
mkdir -p /var/lib/gravity
echo -e "/dev/$system_disk\t/var/lib/gravity\text4\tdefaults\t0\t2" >> /etc/fstab
mount /var/lib/gravity
mkdir -p /var/lib/gravity/planet/etcd
echo -e "/dev/$etcd_disk\t/var/lib/gravity/planet/etcd\text4\tdefaults\t0\t2" >> /etc/fstab
mount /var/lib/gravity/planet/etcd

# Load required kernel modules
for module in $modules; do
  modprobe $module || true
done

# Make changes permanent
cat > /etc/sysctl.d/50-telekube.conf <<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
EOF

echo '' > /etc/modules-load.d/telekube.conf
for module in $modules; do
  echo $module >> /etc/modules-load.d/telekube.conf
done
sysctl -p /etc/sysctl.d/50-telekube.conf

real_user=${ssh_user}
service_uid=$(id $real_user -u)
service_gid=$(id $real_user -g)
chown -R $service_uid:$service_gid /var/lib/gravity /var/lib/gravity/planet/etcd

# Clone workshop repo.
workshop_path=/home/${ssh_user}/workshop
git clone https://github.com/gravitational/workshop.git $workshop_path
chown -R $service_uid:$service_gid $workshop_path
