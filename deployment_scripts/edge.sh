#
# Copyright (c) 2015, PLUMgrid Inc, http://plumgrid.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/bin/bash

. /tmp/plumgrid_config

if [[ ! -f "/root/plumgrid" ]];then
  # Modifying nova.conf
  sed -i '/^libvirt_vif_type.*$/d' /etc/nova/nova.conf
  sed -i '/^libvirt_cpu_mode.*$/d' /etc/nova/nova.conf
  sed -i "s/^\[DEFAULT\]/\[DEFAULT\]\nlibvirt_vif_type=ethernet\nlibvirt_cpu_mode=none/" /etc/nova/nova.conf

  curl -Lks http://$pg_repo:81/plumgrid/GPG-KEY -o /tmp/GPG-KEY
  apt-key add /tmp/GPG-KEY
  # Packages Installation
  apt-get update
  apt-get install -y apparmor-utils;aa-disable /sbin/dhclient
  apt-get install -y plumgrid-puppet
  apt-get install -y nova-api python-pip
  pip install python-memcached
  apt-get install -y iovisor-dkms

  fabric_ip=$(ip addr show br-mgmt | awk '$1=="inet" {print $2}' | awk -F '/' '{print $1}' | awk -F '.' '{print $4}' | head -1)
  fabric_dev=$(brctl show br-mgmt | awk -F ' ' '{print $4}' | awk 'FNR == 2 {print}' | awk -F '.' '{print $1}')
  brctl delif br-aux $fabric_dev
  ifconfig br-aux down
  brctl delbr br-aux
  rm -f /etc/network/interfaces.d/ifcfg-br-aux

  fabric_netmask=$(ifconfig br-mgmt | grep Mask | sed s/^.*Mask://)
  fabric_net=$(echo $fabric_network | cut -f2 -d: | cut -f1-3 -d.)
  ifconfig $fabric_dev $fabric_net.$fabric_ip netmask $fabric_netmask
  ifconfig $fabric_dev mtu 1580
  echo -e "address $fabric_net.$fabric_ip/24\nmtu 1580" >> /etc/network/interfaces.d/ifcfg-$fabric_dev
  echo "fabric_dev: $fabric_dev" >> /etc/astute.yaml
  sed -i 's/manual/static/g' /etc/network/interfaces.d/ifcfg-$fabric_dev

  # Copy over the LCM key
  curl -Lks http://$pg_repo:81/files/ssh_keys/zones/$zone_name/id_rsa.pub -o /tmp/id_rsa.pub
  mkdir -p /var/lib/plumgrid/zones/$zone_name
  mv /tmp/id_rsa.pub /var/lib/plumgrid/zones/$zone_name/id_rsa.pub

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

  touch /root/plumgrid

else
  echo "This Edge has already been configured, skipping."
fi
