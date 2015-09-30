notice('MODULAR: plumgrid/pre_deployment.pp')

package { 'libvirt0' :
  ensure => '1.2.2-0ubuntu13.1.14' ,
} ->
package { 'libvirt-bin' :
  ensure => '1.2.2-0ubuntu13.1.14' ,
}
