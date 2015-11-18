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
