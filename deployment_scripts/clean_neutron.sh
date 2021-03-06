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

if [[ -f "/root/plumgrid" ]];then
  source /root/openrc
  router_id=`neutron router-list | grep "network_id" | awk '{print $2}'`
  neutron router-gateway-clear $router_id
  subnet_id=`neutron router-port-list $router_id | grep "subnet_id" | awk '{print $8}' | awk -F '\"' '{print $2}'`
  neutron router-interface-delete $router_id $subnet_id
  neutron router-delete $router_id
  neutron subnet-delete $subnet_id
  neutron net-delete net04
  neutron net-delete net04_ext
  admin_id=`keystone tenant-list|grep admin|awk -F '|' '{ print $2 }'`
  neutron security-group-delete --tenant-id $admin_id
else
  echo "PLUMgrid plugin has been run before, skipping."
fi
