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
  # Remove OVS kernel module and related packages
  service neutron-server stop
  rmmod openvswitch
  apt-get purge -y openvswitch-*

  # Packages Installation
  curl -Lks http://$pg_repo:81/plumgrid/GPG-KEY -o /tmp/GPG-KEY
  apt-key add /tmp/GPG-KEY
  apt-get update
  apt-get install -y apparmor-utils;aa-disable /sbin/dhclient
  apt-get install -y plumgrid-puppet python-pip
  pip install networking-plumgrid
  apt-get install -y neutron-plugin-plumgrid
  apt-get install -y plumgrid-pythonlib
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

  auth=$(grep "^auth_uri*" /etc/neutron/neutron.conf | awk -F '=' '{print $2}')
  auth_passwd="admin"

  # Configure nova and neutron with PLUMgrid specific configs
  sed -i 's/^core_plugin.*$/core_plugin = neutron.plugins.plumgrid.plumgrid_plugin.plumgrid_plugin.NeutronPluginPLUMgridV2/' /etc/neutron/neutron.conf
  sed -i 's/^service_plugins.*$/service_plugins = ""/' /etc/neutron/neutron.conf
  sed -i '/^libvirt_vif_type.*$/d' /etc/nova/nova.conf
  sed -i '/^libvirt_cpu_mode.*$/d' /etc/nova/nova.conf
  sed -i "s/^\[DEFAULT\]/\[DEFAULT\]\nlibvirt_vif_type=ethernet\nlibvirt_cpu_mode=none/" /etc/nova/nova.conf

  # Configure neutron with the details of PLUMgrid Platform
  sed -i 's/^.*director_server=.*$/director_server='$vip'/' /etc/neutron/plugins/plumgrid/plumgrid.ini
  sed -i 's/^.*director_server_port.*$/director_server_port=443/' /etc/neutron/plugins/plumgrid/plumgrid.ini
  sed -i 's/^.*username.*$/username=plumgrid/' /etc/neutron/plugins/plumgrid/plumgrid.ini
  sed -i 's/^.*password.*$/password=plumgrid/' /etc/neutron/plugins/plumgrid/plumgrid.ini
  sed -i 's/^.*servertimeout.*$/servertimeout=70/' /etc/neutron/plugins/plumgrid/plumgrid.ini
  database_connection=$(cat /etc/neutron/neutron.conf | grep "^connection.*$")
  sed -i '/^connection.*$/d' /etc/neutron/plugins/plumgrid/plumgrid.ini
  echo $database_connection >> /etc/neutron/plugins/plumgrid/plumgrid.ini

  # Configure default plugin and enable metadata support
  echo "NEUTRON_PLUGIN_CONFIG=\"/etc/neutron/plugins/plumgrid/plumgrid.ini\"" > /etc/default/neutron-server
  sed -i s/"enable_pg_metadata = False"/"enable_pg_metadata = True"/g /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i "s/nova_metadata_ip = .*/nova_metadata_ip = 169.254.169.254/g" /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i "s/nova_metadata_port = .*/nova_metadata_port = 8775/g" /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i "s/metadata_proxy_shared_secret = .*/metadata_proxy_shared_secret = $metadata_secret/g" /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i s/"metadata_mode = tunnel"/"metadata_mode = local"/g /etc/neutron/plugins/plumgrid/plumlib.ini
  chmod 770 /etc/sudoers.d/neutron_sudoers
  echo "neutron ALL = (ALL) NOPASSWD:ALL" > /etc/sudoers.d/neutron_sudoers
  chmod 440 /etc/sudoers.d/neutron_sudoers
  sed -i '/.*\[keystone_authtoken\].*$/d' /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i '/.*admin_.*$/d' /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i '/.*auth_uri.*$/d' /etc/neutron/plugins/plumgrid/plumlib.ini
  sed -i "\$a[keystone_authtoken]\nadmin_user = admin\nadmin_password = $auth_passwd\nauth_uri = $auth\nadmin_tenant_name = admin" /etc/neutron/plugins/plumgrid/plumlib.ini

  service neutron-server start

  # Stop apache from using ports conflicting with keystone service ports
  sed -i s/".*NameVirtualHost \*:35357"/"#NameVirtualHost \*:35357"/g /etc/apache2/ports.conf
  sed -i s/".*NameVirtualHost \*:5000"/"#NameVirtualHost \*:5000"/g /etc/apache2/ports.conf

  # Add fuel node fqdn to /etc/hosts
  echo "$haproxy_vip $fuel_hostname" >> /etc/hosts

  touch /root/plumgrid

else
  echo "This Director has already been configured, skipping."
fi
