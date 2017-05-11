# SIMP Profile for managing GitLab
#
# ## Welcome to SIMP!
#
# This module is a component of the System Integrity Management Platform, a
# managed security compliance framework built on Puppet.
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * When included within the SIMP ecosystem, security compliance settings will
#   be managed from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems are disabled by
#   default, and must be explicitly opted into by administrators.  Please
#   review the parameters (e.g., `$trusted_nets`, `pki`) for details.
#
# @param trusted_nets
#   A whitelist of subnets (in CIDR notation) permitted access
#
# @param denied_nets
#   A blacklist of subnets (in CIDR notation) that should be explicitly denied access
#
# @param external_url
#   Default: http://$fqdn
#   External URL of Gitlab.  By default, this will be 'https' if ``$pki`` is
#   set and 'http' if is ``false``.
#
# @param tcp_listen_port
#   The port upon which to listen for regular TCP connections.  By default
#   this will be ``'80'`` if HTTPS is disabled and ``'443'`` if HTTPS is enabled.
#
#
# @param auditing
#   If ``true``, manage auditing for **simp_gitlab**
#
# @param firewall
#   If ``true``, manage firewall rules to acommodate **simp_gitlab**
#
# @param pki
#   * If ``'simp'``, include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/gitlab/x509
#   * If ``true``, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/gitlab/x509
#   * If ``false``, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#
#        * app_pki_dir
#        * app_pki_key
#        * app_pki_cert
#        * app_pki_ca
#
# @param app_pki_external_source
#   * If pki = 'simp' or true, this is the directory from which certs will be
#     copied, via pki::copy.  Defaults to /etc/pki/simp/x509.
#
#   * If pki = false, this variable has no effect.
#
# @param app_pki_dir
#   This variable controls the basepath of $app_pki_key, $app_pki_cert,
#   $app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
#   It defaults to /etc/pki/simp_apps/gitlab/x509.
#
# @param app_pki_key
#   Full path of the private SSL key file.
#
# @param app_pki_cert
#   Full path of the public SSL certificate.
#
# @param app_pki_ca
#   Full path of the the SSL CA certificate.
#
# @param edition
#   Edition of GitLab to manage (`'ce'` or `'ee'`)
#
# @param syslog
#   Whether or not to use the SIMP Rsyslog module.
#
# @param two_way_ssl_validation
#   When `true`, server and clients will require mutual TLS authentication.
#
# @param ssl_verify_depth
#   Sets the verification depth in the client certificates chain.
#
# @param gitlab_options
#   Hash of custom parameters for `vshn/gitlab`.
#
# @param cipher_suite
#   The cipher suite to use with SSL
#
# @param ldap
#   If ``true``, enable LDAP support for Gitlab Omnibus.
#
# @param ldap_uri
#   List of OpenLDAP server URIs.  Note that _multiple_ URIs is an EE feature.
#   @example ['ldap://server1', 'ldaps://server2']
#
# @param ldap_active_directory
#   This setting specifies if LDAP server is Active Directory LDAP server.
#   For non AD servers it skips the AD specific queries.
#   If your LDAP server is not AD, set this to false.
#
# @param ldap_base_dn
#   Base where we can search for users
#
#   @example Ex. ou=People,dc=gitlab,dc=example
#
# @param ldap_bind_dn
#   The DN to use when binding to the LDAP server
#
# @param ldap_bind_pw
#   The password of the bind user
#
# @param ldap_user_filter
#   Format: RFC 4515 http://tools.ietf.org/search/rfc4515
#   @example (employeeType=developer)
#
# @param ldap_group_base
#   EE only
#
# @author simp
#
class simp_gitlab (
  Simplib::Netlist       $trusted_nets            = simplib::lookup('simp_options::trusted_nets', {'default_value' => ['127.0.0.1/32'] }),
  Simp_gitlab::Stroolean $pki                     = simplib::lookup('simp_options::pki', { 'default_value'         => false }),
  Simplib::Uri           $external_url            = $pki ? { true => "https://${facts['fqdn']}", 'simp' => "https://${facts['fqdn']}", default => "http://${facts['fqdn']}" },
  Simplib::Netlist       $denied_nets             = [],
  Simplib::Port          $tcp_listen_port         = $pki ? { true => 443, 'simp' => 443, default => 80},
  Boolean                $auditing                = simplib::lookup('simp_options::auditd',        {'default_value' => false}),
  Boolean                $firewall                = simplib::lookup('simp_options::firewall',      {'default_value' => false}),
  Boolean                $syslog                  = simplib::lookup('simp_options::syslog',        {'default_value' => false}),
  Boolean                $ldap                    = simplib::lookup('simp_options::ldap',          {'default_value' => false}),
  Boolean                $ldap_active_directory   = false,
  Array[Simplib::URI]    $ldap_uri                = simplib::lookup('simp_options::ldap::uri',     {'default_value' => []}),
  String                 $ldap_base_dn            = simplib::lookup('simp_options::ldap::base_dn', {'default_value' => simplib::ldap::domain_to_dn()}),
  String                 $ldap_bind_dn            = simplib::lookup('simp_options::ldap::bind_dn', {'default_value' => "cn=hostAuth,ou=Hosts,${ldap_base_dn}"}),
  String                 $ldap_bind_pw            = simplib::lookup('simp_options::ldap::bind_pw', {'default_value' => "cn=LDAPAdmin,ou=People,${ldap_base_dn}"}),
  Optional[String]       $ldap_group_base         = undef,
  Optional[String]       $ldap_user_filter        = undef,
  Hash                   $gitlab_options          = {},

  Stdlib::Absolutepath   $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Stdlib::Absolutepath   $app_pki_dir             = '/etc/pki/simp_apps/gitlab/x509',
  Stdlib::Absolutepath   $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  Stdlib::Absolutepath   $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
  Stdlib::Absolutepath   $app_pki_ca              = "${app_pki_dir}/cacerts/cacerts.pem",
  Boolean                $two_way_ssl_validation  = false,
  Integer                $ssl_verify_depth        = 2,
  Array[String]          $cipher_suite            = simplib::lookup('simp_options::openssl::cipher_suites', {
                                                                    'default_value' => ['DEFAULT', '!MEDIUM']
                                                                    }),
  Enum['ce','ee']        $edition                 = 'ce',
) {

  $oses = load_module_metadata( $module_name )['operatingsystem_support'].map |$i| { $i['operatingsystem'] }
  unless $::operatingsystem in $oses { fail("${::operatingsystem} not supported") }

  include 'postfix'
  include 'ntpd'
  include 'simp_gitlab::install'

  Class['ntpd']
  -> Class['simp_gitlab::install']
  -> Class['postfix']

  svckill::ignore { 'chronyd': } # On EL7, GitLab pulls in the chronyd service

  if $pki {
    pki::copy { 'gitlab':
      pki    => $::simp_gitlab::pki,
      source => $::simp_gitlab::app_pki_external_source,
    }
    Pki::Copy['gitlab'] -> Class['::simp_gitlab::install']
  }

  if $firewall {
    include 'simp_gitlab::config::firewall'
    Class['simp_gitlab::config::firewall'] -> Class['::simp_gitlab::install']
  }

}
