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

notice('MODULAR: plumgrid/pre_deployment.pp')

package { 'libvirt0' :
  ensure => '1.2.2-0ubuntu13.1.14' ,
} ->
package { 'libvirt-bin' :
  ensure => '1.2.2-0ubuntu13.1.14' ,
}
