# Copyright (c) 2014, PLUMgrid, http://plumgrid.com
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

class plumgrid::firewall (
  $source_net = undef,
  $dest_net = undef,
) {

  if $source_net != undef {
    firewall { '001 plumgrid udp':
      proto       => 'udp',
      action      => 'accept',
      state       => ['NEW'],
      destination => $dest_net,
      source      => $source_net,
      before      => Class['plumgrid'],
    }
    firewall { '001 plumgrid rpc':
      proto       => 'tcp',
      action      => 'accept',
      state       => ['NEW'],
      destination => $dest_net,
      source      => $source_net,
      before      => Class['plumgrid'],
    }
    firewall { '040 allow vrrp':
      proto       => 'vrrp',
      action      => 'accept',
      before      => Class['plumgrid'],
    }
    firewall { '040 keepalived':
      proto       => 'all',
      action      => 'accept',
      destination => '224.0.0.18/32',
      source      => $source_net,
      before      => Class['plumgrid'],
    }
  }
}
