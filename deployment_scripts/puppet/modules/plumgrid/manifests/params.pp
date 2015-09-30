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

class plumgrid::params {
  $plumgrid_package = 'plumgrid-lxc'
  case $::osfamily {
    'RedHat', 'Linux': {
      $manage_repo = false
      $libvirt_package = 'libvirt-daemon-driver-lxc'
      $libvirt_service = 'libvirtd'
      $kernel_header_package = 'kernel-devel'
    }
    'Debian': {
      $manage_repo = true
      $libvirt_package = 'libvirt-bin'
      $libvirt_service = 'libvirt-bin'
      $kernel_header_package = "linux-headers-${kernelrelease}"
    }
  }
  $fabric_dev = '%AUTO_DEV%'
  $mgmt_dev = '%AUTO_DEV%'
}
