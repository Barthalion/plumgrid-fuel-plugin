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

notice('MODULAR: plumgrid/pre_node.pp')

$fuel_hash = hiera_hash('public_ssl', {})
$fuel_hostname = pick($fuel_hash['hostname'])

$metadata_hash = hiera_hash('quantum_settings', {})
$metadata = pick($metadata_hash['metadata']['metadata_proxy_shared_secret'], 'root')

$plumgrid_hash = hiera_hash('plumgrid', {})
$plumgrid_pkg_repo = pick($plumgrid_hash['plumgrid_package_repo'])
$plumgrid_lic = pick($plumgrid_hash['plumgrid_license'])
$plumgrid_vip = pick($plumgrid_hash['plumgrid_virtual_ip'])
$plumgrid_zone = pick($plumgrid_hash['plumgrid_zone'])
$fabric_network = pick($plumgrid_hash['plumgrid_fabric_network'])

$network_metadata = hiera_hash('network_metadata')
$haproxy_vip = pick($network_metadata['vips']['public']['ipaddr'])
$controller_nodes = get_nodes_hash_by_roles($network_metadata, ['primary-controller', 'controller'])
$controller_address_map = get_node_to_ipaddr_map_by_network_role($controller_nodes, 'mgmt/vip')
$controller_ipaddresses = join(hiera_array('controller_ipaddresses', values($controller_address_map)), ',')

file { '/tmp/plumgrid_config':
  ensure  => file,
  content => "fuel_hostname=$fuel_hostname\nhaproxy_vip=$haproxy_vip\ndirector_ip=$controller_ipaddresses\nedge_ip=$compute_ipaddresses\nmetadata_secret=$metadata\nlicense=$plumgrid_lic\nvip=$plumgrid_vip\npg_repo=$plumgrid_pkg_repo\nzone_name=$plumgrid_zone\nfabric_network=$fabric_network",
}
