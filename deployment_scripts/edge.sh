#!/bin/bash

. /tmp/plumgrid_config

touch /root/plumgrid

if [[ -f "/root/plumgrid" ]];then
  # Modifying nova.conf
  sed -i '/^libvirt_vif_type.*$/d' /etc/nova/nova.conf
  sed -i '/^libvirt_cpu_mode.*$/d' /etc/nova/nova.conf
  sed -i "s/^\[DEFAULT\]/\[DEFAULT\]\nlibvirt_vif_type=ethernet\nlibvirt_cpu_mode=none/" /etc/nova/nova.conf

  wget http://$pg_repo:81/plumgrid/GPG-KEY /tmp/
  apt-key add /tmp/GPG-KEY
  # Packages Installation
  apt-get update
  apt-get install -y apparmor-utils;aa-disable /sbin/dhclient
  apt-get install -y plumgrid-puppet
  apt-get install -y nova-api python-pip
  pip install python-memcached
  apt-get install -y iovisor-dkms

  fabric_ip=$fabric_prefix.$(ip addr show br-mgmt | awk '$1=="inet" {print $2}' | awk -F '/' '{print $1}' | awk -F '.' '{print $4}' | head -1)
  fabric_dev=$(brctl show br-mgmt | awk -F ' ' '{print $4}' | grep eth| awk -F '.' '{print $1}')
  brctl delif br-aux $fabric_dev
  brctl delbr br-aux
  ifconfig $fabric_dev 60.0.0$fabric_ip/24
  ifconfig $fabric_dev mtu 1580
  rm -f /etc/network/interfaces.d/ifcfg-br-aux
  echo "address 60.0.0$fabric_ip/24\nmtu 1580" >> /etc/network/interfaces.d/ifcfg-$fabric_dev
  echo "fabric_dev: $fabric_dev" >> /etc/astute.yaml

  # Add this file as a part of puppet module
  cp -f  /etc/puppet/modules/mellanox_openstack/files/network.filters /etc/nova/rootwrap.d/network.filters

  # Modifying Neutron Sudoers file for metadata
  echo "nova ALL=(root) NOPASSWD: /opt/pg/bin/ifc_ctl_pp *" > /etc/sudoers.d/ifc_ctl_sudoers
  chown root:root /etc/sudoers.d/ifc_ctl_sudoers
  chmod 644 /etc/sudoers.d/ifc_ctl_sudoers
  sysctl -w net.ipv4.ip_forward=1
  sed -i s/"#net.ipv4.ip_forward=1"/"net.ipv4.ip_forward=1"/g /etc/sysctl.conf
  echo 'cgroup_device_acl = ["/dev/null", "/dev/full", "/dev/zero", "/dev/random", "/dev/urandom", "/dev/ptmx", "/dev/kvm", "/dev/kqemu", "/dev/rtc", "/dev/hpet", "/dev/net/tun"]' >> /etc/libvirt/qemu.conf

  pkill -9 -f libvirtd
  service libvirt-bin restart
  service nova-api restart
else
  echo "PLUMgrid plugin has been run before."
fi
