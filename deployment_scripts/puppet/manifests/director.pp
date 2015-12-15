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

$fuel_hash = hiera_hash('public_ssl', {})
$fuel_hostname = pick($fuel_hash['hostname'])

$metadata_hash = hiera_hash('quantum_settings', {})
$metadata = pick($metadata_hash['metadata']['metadata_proxy_shared_secret'], 'root')
$plumgrid_hash = hiera_hash('plumgrid', {})
$plumgrid_pkg_repo = pick($plumgrid_hash['plumgrid_package_repo'])
$plumgrid_lic = pick($plumgrid_hash['plumgrid_license'])
$plumgrid_vip = pick($plumgrid_hash['plumgrid_virtual_ip'])
$plumgrid_zone = pick($plumgrid_hash['plumgrid_zone'])

$network_metadata = hiera_hash('network_metadata')
$haproxy_vip = pick($network_metadata['vips']['public']['ipaddr'])
$controller_nodes = get_nodes_hash_by_roles($network_metadata, ['primary-controller', 'controller'])
$controller_address_map = get_node_to_ipaddr_map_by_network_role($controller_nodes, 'mgmt/vip')
$controller_ipaddresses = join(hiera_array('controller_ipaddresses', values($controller_address_map)), ',')
$mgmt_net = hiera('management_network_range')
$fabric_dev = hiera('fabric_dev')

# Add fuel node fqdn to /etc/hosts
host { 'fuel':
    ip           => $haproxy_vip,
    host_aliases => $fuel_hostname,
}

# Install Director Packages
$director_packages = [ 'plumgrid-puppet', 'python-pip', 'neutron-plugin-plumgrid', 'plumgrid-pythonlib', 'apparmor-utils' ]
package { $director_packages: 
    ensure => 'latest',
    require => Exec['apt-get update'], 
}

exec { 'aa-disable':
    command => 'aa-disable /sbin/dhclient',
    path    => ['/usr/sbin', '/bin/'],
    onlyif  => 'aa-status | grep /sbin/dhclient',
    subscribe => Package['apparmor-utils'],
}

package { 'networking-plumgrid':
    ensure  => latest,
    provider => pip,
    require => Exec['apt-get update'],
}

class { 'plumgrid':
  plumgrid_ip => $controller_ipaddresses,
  mgmt_dev => 'br-mgmt',
  fabric_dev => $fabric_dev,
  lvm_keypath => "/var/lib/plumgrid/zones/$plumgrid_zone/id_rsa.pub",
}

class { 'sal':
  plumgrid_ip => $controller_ipaddresses,
  virtual_ip => $plumgrid_vip,
}

class { plumgrid::firewall:
  source_net=> $mgmt_net,
  dest_net=> $mgmt_net,
}
