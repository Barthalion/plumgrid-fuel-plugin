notice('MODULAR: plumgrid/pre_node.pp')

$metadata_hash = hiera_hash('quantum_settings', {})
$metadata = pick($metadata_hash['metadata']['metadata_proxy_shared_secret'], 'root')
$plumgrid_hash = hiera_hash('plumgrid', {})
$plumgrid_pkg_repo = pick($plumgrid_hash['plumgrid_package_repo'])
$plumgrid_lic = pick($plumgrid_hash['plumgrid_license'])
$plumgrid_vip = pick($plumgrid_hash['plumgrid_virtual_ip'])
$network_metadata = hiera_hash('network_metadata')
$controller_nodes = get_nodes_hash_by_roles($network_metadata, ['primary-controller', 'controller'])
$controller_address_map = get_node_to_ipaddr_map_by_network_role($controller_nodes, 'mgmt/vip')
$controller_ipaddresses = join(hiera_array('controller_ipaddresses', values($controller_address_map)), ',')
$plumgrid_zone = pick($plumgrid_hash['plumgrid_zone'])
$fabric_network = pick($plumgrid_hash['plumgrid_fabric_network'])

file { '/tmp/plumgrid_config':
  ensure  => file,
  content => "director_ip=$controller_ipaddresses\nedge_ip=$compute_ipaddresses\nmetadata_secret=$metadata\nlicense=$plumgrid_lic\nvip=$plumgrid_vip\npg_repo=$plumgrid_pkg_repo\nzone_name=$plumgrid_zone\nfabric_network=$fabric_network",
}
