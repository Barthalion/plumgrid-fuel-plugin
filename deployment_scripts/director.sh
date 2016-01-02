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

#!/bin/bash

. /tmp/plumgrid_config

if [[ ! -f "/root/plumgrid" ]];then
  service neutron-server stop

  chmod 770 /etc/sudoers.d/neutron_sudoers
  echo "neutron ALL = (ALL) NOPASSWD:ALL" > /etc/sudoers.d/neutron_sudoers
  chmod 440 /etc/sudoers.d/neutron_sudoers

  service neutron-server start

  # Stop apache from using ports conflicting with keystone service ports
  sed -i s/".*NameVirtualHost \*:35357"/"#NameVirtualHost \*:35357"/g /etc/apache2/ports.conf
  sed -i s/".*NameVirtualHost \*:5000"/"#NameVirtualHost \*:5000"/g /etc/apache2/ports.conf

  touch /root/plumgrid

else
  echo "This Director has already been configured, skipping."
fi
