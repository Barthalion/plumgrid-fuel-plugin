#!/bin/bash

. /tmp/plumgrid_config

# Remove OVS kernel module and related packages
service neutron-server stop
rmmod openvswitch
apt-get purge -y openvswitch-*

# Packages Installation
wget http://$pg_repo:81/plumgrid/GPG-KEY /tmp/
apt-key add /tmp/GPG-KEY
apt-get update
apt-get install -y apparmor-utils;aa-disable /sbin/dhclient
apt-get install -y plumgrid-puppet python-pip
pip install networking-plumgrid
apt-get install -y neutron-plugin-plumgrid
apt-get install -y plumgrid-pythonlib
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
