#!/bin/bash

. /tmp/plumgrid_config

touch /root/plumgrid

if [[ -f "/root/plumgrid" ]];then
  wget http://$pg_repo:81/plumgrid/GPG-KEY /tmp/
  apt-key add /tmp/GPG-KEY
  # Packages Installation
  apt-get update
  apt-get install -y apparmor-utils;aa-disable /sbin/dhclient
  apt-get install -y plumgrid-puppet
  apt-get install -y iovisor-dkms
  apt-get install -y iptables-persistent

  fabric_ip=$fabric_prefix.$(ip addr show br-mgmt | awk '$1=="inet" {print $2}' | awk -F '/' '{print $1}' | awk -F '.' '{print $4}' | head -1)
  fabric_dev=$(brctl show br-mgmt | awk -F ' ' '{print $4}' | grep eth| awk -F '.' '{print $1}')
  brctl delif br-aux $fabric_dev
  brctl delbr br-aux
  ifconfig $fabric_dev 60.0.0$fabric_ip/24
  ifconfig $fabric_dev mtu 1580
  rm -f /etc/network/interfaces.d/ifcfg-br-aux
  echo "address 60.0.0$fabric_ip/24\nmtu 1580" >> /etc/network/interfaces.d/ifcfg-$fabric_dev
  echo "fabric_dev: $fabric_dev" >> /etc/astute.yaml

  sysctl -w net.ipv4.ip_forward=1
  sed -i s/"#net.ipv4.ip_forward=1"/"net.ipv4.ip_forward=1"/g /etc/sysctl.conf
else
  echo "PLUMgrid plugin has been run before."
fi
