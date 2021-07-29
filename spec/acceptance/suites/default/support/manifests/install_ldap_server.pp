# NOTE: The LDAP server and client configurations are largely handled from hiera

if $facts['os']['release']['major'] == '7' {
  # Sets up server and client
  class{'simp_openldap': is_server => true }
}
else {
  # Sets up LDAP server, only.
  include 'simp_ds389::instances::accounts'
}

include 'svckill'
include 'iptables'
iptables::listen::tcp_stateful { 'ssh':
  dports       => 22,
  trusted_nets => ['any'],
}
