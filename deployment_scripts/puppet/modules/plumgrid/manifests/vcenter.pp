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

class plumgrid::vcenter ($vcenter_ip = '',
                         $vcenter_username = '',
                         $vcenter_password = '',
                         $encoded = false,
                        ) {
  Exec { path => [ '/bin', '/sbin' , '/usr/bin', '/usr/sbin', '/usr/local/bin', ] }

  $curl_options = "-H 'Accept: application/json' -Lks http://127.0.0.1:80"
  $curl_put_options = "-XPUT -H 'Content-Type: application/json' ${curl_options}"
  $grep1 = '?level=1 | jq "{\"'
  $grep2 = '\"}[] != null" | grep -q true'

  $vmw_server_json = template('plumgrid/cdb-vmw_agent.json.erb')

  exec { 'curl-vmw_agent/server/0':
    unless => "curl ${curl_options}/0/vmw_agent/server${grep1}0${grep2}",
    command => "curl ${curl_put_options}/0/vmw_agent/server/0 -d '${vmw_server_json}' -w %{http_code} -o /dev/null | grep -q 200",
    require => [Class['plumgrid::cdb'], Package['jq']],
  }
}
