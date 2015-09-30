# Copyright (c) 2013, PLUMgrid, http://plumgrid.com
#
# This source is subject to the PLUMgrid License.
# All rights reserved.
#
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF
# ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE.
#
# PLUMgrid confidential information, delete if you are not the
# intended recipient.

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
