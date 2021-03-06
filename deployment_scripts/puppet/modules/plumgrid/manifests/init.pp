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

class plumgrid (
  $plumgrid_ip = '',
  $plumgrid_port = 8001,
  $rest_ip = '0.0.0.0',
  $rest_port = '9180',
  $mgmt_dev = 'br-mgmt',
  $fabric_dev = 'eth2',
  $fabric_mode = 'host',
  $gateway_devs = [],
  $demux_devs = [],
  $license = '',
  $lvm_keypath = '',
  $mcollective = false,
  $manage_repo = $plumgrid::params::manage_repo,
  $repo_baseurl = '',
  $repo_component = '',
  $physical_location = '',
) inherits plumgrid::params {
  Exec { path => [ '/bin', '/sbin' , '/usr/bin', '/usr/sbin', '/usr/local/bin', ] }

  $pg_package = $plumgrid::params::plumgrid_package
  $lxc_root_path = '/var/lib/libvirt/filesystems/plumgrid'
  $lxc_data_path = '/var/lib/libvirt/filesystems/plumgrid-data'

  $ips = split($plumgrid_ip, ',')
  $firstip = $ips[0]
  $ips_awk = join($ips, '|')

  package { $pg_package:
    ensure => "latest",
  }
  if $lvm_keypath != ''  {
    ssh_authorized_key { "root@lvm":
      key => regsubst(chomp(file($lvm_keypath)), '^\S* (\S*) \S*$', '\1'),
      type => 'ssh-rsa',
      user => 'root',
      target => "${lxc_data_path}/root/.ssh/authorized_keys",
      require => Package[$pg_package],
      before => Service['plumgrid'],
    }
  }
  file { "${lxc_data_path}/conf/etc/hostname":
    content => $hostname,
    require => Package[$pg_package],
    before => Service['plumgrid'],
  }
  file { "${lxc_data_path}/conf/etc/hosts":
    content => template('plumgrid/hosts.erb'),
    require => Package[$pg_package],
    before => Service['plumgrid'],
  }
  exec { 'pick-fabric_dev-by-route':
    creates => "${lxc_data_path}/conf/pg/.auto_dev-fabric",
    command => "ip route get ${firstip} | awk 'NR==1 && \$2==\"dev\" {print \$3; exit 0} NR==1 && \$2==\"via\" {print \$5; exit 0} NR>1 { exit 1 }' > ${lxc_data_path}/conf/pg/.auto_dev-fabric || ip addr show | awk '/(${ips_awk})\\// {print \$NF}' > ${lxc_data_path}/conf/pg/.auto_dev-fabric",
    require => Package[$pg_package],
  }->
  exec { 'check-fabric_dev-by-route':
    command => 'echo "Please provide \"mgmt_dev\" and \"fabric_dev\" parameters for \"plumgrid\" class using foreman UI" && exit 1',
    unless => "test -s ${lxc_data_path}/conf/pg/.auto_dev-fabric",
  }
  file { "${lxc_data_path}/conf/pg/.plumgrid.conf":
    ensure => file,
    content => template('plumgrid/plumgrid.conf.erb'),
    require => Package[$pg_package],
  }~>
  exec { 'generate-plumgrid.conf':
    refreshonly => true,
    command => "sed \"s/%AUTO_DEV%/`head -n1 ${lxc_data_path}/conf/pg/.auto_dev-fabric`/g\" ${lxc_data_path}/conf/pg/.plumgrid.conf > ${lxc_data_path}/conf/pg/plumgrid.conf",
    subscribe => Exec['pick-fabric_dev-by-route'],
    notify => Service['plumgrid'],
  }
  file { "${lxc_data_path}/conf/pg/.ifcs.conf":
    content => template("${module_name}/ifcs.conf.erb"),
    require => Package[$pg_package],
  }~>
  exec { 'generate-ifcs.conf':
    refreshonly => true,
    command => "sed \"s/%AUTO_DEV%/`head -n1 ${lxc_data_path}/conf/pg/.auto_dev-fabric`/g\" ${lxc_data_path}/conf/pg/.ifcs.conf > ${lxc_data_path}/conf/pg/ifcs.conf",
    subscribe => Exec['pick-fabric_dev-by-route'],
    notify => Service['plumgrid'],
  }

  service { 'plumgrid':
    ensure => running,
    enable => true,
  }
}
