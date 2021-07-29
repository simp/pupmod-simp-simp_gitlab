# NOTE: The LDAP server configuration largely handled from hiera

if $facts['os']['release']['major'] == '7' {
  service { 'slapd': ensure => 'stopped' }

  $ldap_packages = [ 'openldap-servers', 'openldap-clients' ]
  package { $ldap_packages: ensure => absent, require => Service['slapd'] }

  $ldap_dirs = [ '/var/lib/ldap', '/etc/openldap' ]
  tidy { $ldap_dirs:
    recurse => true,
    rmdirs  => true,
    require => Service['slapd']
  }
}
else {
  ds389::instance { 'accounts': ensure => 'absent' }
}
