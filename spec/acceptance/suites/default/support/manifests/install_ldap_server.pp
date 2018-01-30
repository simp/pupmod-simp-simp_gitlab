# NOTE: The design of the simp_openldap module requires most configuration
#       to be handled from hiera
class{'simp_openldap': is_server => true }
include 'svckill'
include 'iptables'

iptables::listen::tcp_stateful { 'ssh':
  dports       => 22,
  trusted_nets => ['any'],
}
iptables::listen::tcp_stateful { 'ldaps':
  dports       => [389,636],
  trusted_nets => ['any'],
}

