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

class sal ($plumgrid_ip = '',
           $virtual_ip = '',
           $rest_port = '9180',
           $mgmt_dev = '%AUTO_DEV%',
           ) {
  $lxc_root_path = '/var/lib/libvirt/filesystems/plumgrid'
  $lxc_data_path = '/var/lib/libvirt/filesystems/plumgrid-data'

  firewall { '001 allow PG Console access':
    destination => $virtual_ip,
    dport  => 443,
    proto  => tcp,
    action => accept,
    before => [ Class['sal::nginx'], Class['sal::keepalived'] ],
  }

  class { 'sal::nginx':
    plumgrid_ip => $plumgrid_ip,
    virtual_ip => $virtual_ip,
  }
  class { 'sal::keepalived':
    virtual_ip => $virtual_ip,
    mgmt_dev => $mgmt_dev,
  }
}
