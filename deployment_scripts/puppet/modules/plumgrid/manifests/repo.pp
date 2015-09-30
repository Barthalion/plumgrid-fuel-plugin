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

class plumgrid::repo (
  $ensure = 'present',
  $os_release = 'icehouse',
  $repo_baseurl,
  $repo_component,
) {
  if $ensure == 'present' {
    case $::osfamily {
      'RedHat', 'Linux': {
        if $repo_baseurl and $repo_baseurl != '' {
          yumrepo { 'plumgrid':
            baseurl => "${repo_baseurl}/${repo_component}/el${operatingsystemmajrelease}/${architecture}",
            descr => "PLUMgrid Repo",
            enabled => 1,
            gpgcheck => 1,
            gpgkey => "${repo_baseurl}/GPG-KEY",
          }
        }
      }
      'Debian': {
        apt::source { 'openstack':
          location => 'http://ubuntu-cloud.archive.canonical.com/ubuntu',
          release => "${::lsbdistcodename}-updates/${os_release}",
          repos => 'main',
          key => 'ECD76E3E',
          key_server => 'keyserver.ubuntu.com',
          include_src => false,
        }
        Apt::Source['openstack'] -> Package['plumgrid-lxc']
      }
      default: {
        fail("Unsupported repository for osfamily: ${::osfamily}, OS: ${::operatingsystem}, module ${module_name}")
      }
    }
  } else {
    case $::osfamily {
      'RedHat', 'Linux': {
        if $repo_baseurl and $repo_baseurl != '' {
          yumrepo { 'plumgrid': ensure => absent, }
        }
      }
      'Debian': {
        apt::source { 'openstack': ensure => absent, }
      }
    }
  }
}
