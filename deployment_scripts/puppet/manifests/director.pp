notice('MODULAR: plumgrid/director.pp')

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
$mgmt_net = hiera('management_network_range')
$fabric_dev = hiera('fabric_dev')
$plumgrid_zone = pick($plumgrid_hash['plumgrid_zone'])

class { 'plumgrid':
  plumgrid_ip => $controller_ipaddresses,
  license => $plumgrid_lic,
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
