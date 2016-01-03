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

notice('MODULAR: plumgrid/director.pp')

# Fuel settings
$fuel_hash              = hiera_hash('public_ssl', {})
$fuel_hostname          = pick($fuel_hash['hostname'])
$haproxy_vip            = pick($network_metadata['vips']['public']['ipaddr'])

# PLUMgrid settings
$plumgrid_hash          = hiera_hash('plumgrid', {})
$plumgrid_pkg_repo      = pick($plumgrid_hash['plumgrid_package_repo'])
$plumgrid_lic           = pick($plumgrid_hash['plumgrid_license'])
$plumgrid_vip           = pick($plumgrid_hash['plumgrid_virtual_ip'])
$plumgrid_zone          = pick($plumgrid_hash['plumgrid_zone'])

# PLUMgrid Zone settings
$network_metadata       = hiera_hash('network_metadata')
$controller_nodes       = get_nodes_hash_by_roles($network_metadata, ['primary-controller', 'controller'])
$controller_address_map = get_node_to_ipaddr_map_by_network_role($controller_nodes, 'mgmt/vip')
$controller_ipaddresses = join(hiera_array('controller_ipaddresses', values($controller_address_map)), ',')
$mgmt_net               = hiera('management_network_range')
$fabric_dev             = hiera('fabric_dev')

# Neutron settings
$neutron_config         = hiera_hash('quantum_settings', {})
$metadata_secret        = pick($neutron_config['metadata']['metadata_proxy_shared_secret'], 'root')
$service_endpoint       = hiera('service_endpoint')

# Neutron Keystone settings
$neutron_user_password  = $neutron_config['keystone']['admin_password']
$keystone_user          = pick($neutron_config['keystone']['admin_user'], 'neutron')
$keystone_tenant        = pick($neutron_config['keystone']['admin_tenant'], 'services')

# Neutron DB settings
$neutron_db_password    = $neutron_config['database']['passwd']
$neutron_db_user        = pick($neutron_config['database']['user'], 'neutron')
$neutron_db_name        = pick($neutron_config['database']['name'], 'neutron')
$neutron_db_host        = pick($neutron_config['database']['host'], hiera('database_vip'))

$neutron_db_uri = "mysql://${neutron_db_user}:${neutron_db_password}@${neutron_db_host}/${neutron_db_name}?&read_timeout=60"

# Add fuel node fqdn to /etc/hosts
host { 'fuel':
    ip => $haproxy_vip,
    host_aliases => $fuel_hostname,
}

package { 'neutron-server':
  ensure => 'present',
  name   => 'neutron-server',
}

service { 'neutron-server':
  ensure     => 'running',
  name       => 'neutron-server',
  enable     => true,
}

exec { "apt-get update":
  command => "/usr/bin/apt-get update",
}

package { 'networking-plumgrid':
  ensure   => latest,
  provider => pip,
  notify   => Service['neutron-server'],
  require  => [ Exec['apt-get update'], Package['neutron-server'] ]
}

class { 'plumgrid':
  plumgrid_ip  => $controller_ipaddresses,
  mgmt_dev     => 'br-mgmt',
  fabric_dev   => $fabric_dev,
  lvm_keypath   => "/var/lib/plumgrid/zones/$plumgrid_zone/id_rsa.pub",
}

class { 'sal':
  plumgrid_ip => $controller_ipaddresses,
  virtual_ip  => $plumgrid_vip,
}

class { plumgrid::firewall:
  source_net => $mgmt_net,
  dest_net   => $mgmt_net,
}

# Setup PLUMgrid Configurations

file_line { '/etc/default/neutron-server':
  path    => '/etc/default/neutron-server',
  line    => 'NEUTRON_PLUGIN_CONFIG="/etc/neutron/plugins/plumgrid/plumgrid.ini"',
  match   => '^NEUTRON_PLUGIN_CONFIG=(.*)$',
  require => [ Package['neutron-server'], Package['neutron-plugin-plumgrid'] ],
  notify  => Service['neutron-server'],
}

file { '/etc/neutron/neutron.conf':
  ensure => present,
  notify => Service['neutron-server']
}

file_line { 'Enable PLUMgrid core plugin':
  path => '/etc/neutron/neutron.conf',
  line => 'core_plugin=neutron.plugins.plumgrid.plumgrid_plugin.plumgrid_plugin.NeutronPluginPLUMgridV2',
  match => '^core_plugin.*$',
  require => File['/etc/neutron/neutron.conf']
}

file_line { 'Disable service plugins':
  path => '/etc/neutron/neutron.conf',
  line => 'service_plugins = ""',
  match => '^service_plugins.*$',
  require => File['/etc/neutron/neutron.conf']
}

file { '/etc/nova/nova.conf':
  ensure => present,
  notify => Service['neutron-server']
}

file_line { 'Set libvirt vif':
  path => '/etc/nova/nova.conf',
  line => 'libvirt_vif_type=ethernet',
  match => '^libvirt_vif_type.*$',
  require => File['/etc/nova/nova.conf']
}

file_line { 'Set libvirt cpu mode':
  path => '/etc/nova/nova.conf',
  line => 'libvirt_cpu_mode=none',
  match => '^libvirt_cpu_mode.*$',
  require => File['/etc/nova/nova.conf']
}

file { '/etc/apache2/ports.conf':
  ensure => present
}

file_line { 'ensure no port conflict between apache and keystone':
  path    => '/etc/apache2/ports.conf',
  line   => 'NameVirtualHost *:35357',
  ensure  => 'absent',
  require => File['/etc/apache2/ports.conf']
}

file_line { 'ensure no port conflict between apache-keystone':
  path    => '/etc/apache2/ports.conf',
  line   => 'NameVirtualHost *:5000',
  ensure  => 'absent',
  require => File['/etc/apache2/ports.conf']
}

# Setting PLUMgrid Config Files

Neutron_plugin_plumgrid<||> ~> Service['neutron-server']
Neutron_plumlib_plumgrid<||> ~> Service['neutron-server']

ensure_resource('file', '/etc/neutron/plugins/plumgrid', {
  ensure => directory,
  owner  => 'root',
  group  => 'neutron',
  mode   => '0640'}
)

Package['neutron-server'] -> Neutron_plugin_plumgrid<||>
Package['neutron-server'] -> Neutron_plumlib_plumgrid<||>

package { 'neutron-plugin-plumgrid':
  name   => 'neutron-plugin-plumgrid',
  ensure => latest,
  require => Exec['apt-get update']
}

package { 'neutron-plumlib-plumgrid':
  name   => 'plumgrid-pythonlib',
  ensure => latest,
  require => Exec['apt-get update']
}

neutron_plugin_plumgrid {
   'PLUMgridDirector/director_server':      value => $plumgrid_vip;
   'PLUMgridDirector/director_server_port': value => '443';
   'PLUMgridDirector/username':             value => 'plumgrid';
   'PLUMgridDirector/password':             value => 'plumgrid', secret =>true;
   'PLUMgridDirector/servertimeout':        value => '70';
   'database/connection':                   value => $neutron_db_uri;
}

neutron_plumlib_plumgrid {
  'keystone_authtoken/admin_user' :                value => $keystone_user;
  'keystone_authtoken/admin_password':             value => $neutron_user_password, secret =>true;
  'keystone_authtoken/auth_uri':                   value => "http://${service_endpoint}:35357/v2.0";
  'keystone_authtoken/admin_tenant_name':          value => $keystone_tenant;
  'PLUMgridMetadata/enable_pg_metadata' :          value => 'True';
  'PLUMgridMetadata/metadata_mode':                value => 'local';
  'PLUMgridMetadata/nova_metadata_ip':             value => '169.254.169.254';
  'PLUMgridMetadata/nova_metadata_port':           value => '8775';
  'PLUMgridMetadata/metadata_proxy_shared_secret': value => $metadata_secret;
}
