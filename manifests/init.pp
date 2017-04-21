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
#### @param enable_tcpwrappers
####   If true, manage TCP wrappers configuration for simp_gitlab
####   NOTE: NGINX + rails doesn't use tcpwrappers. If *NOTHING* covered by
####         simp_gitlab is affected, remove it.
#
# @param pki
#   * If ``'simp'``, include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/openldap/x509
#   * If ``true``, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/openldap/x509
#   * If ``false``, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#     * app_pki_dir
#     * app_pki_key
#     * app_pki_cert
#     * app_pki_ca
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
#   It defaults to /etc/pki/simp_apps/openldap/x509.
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
# @param edition ('ce')
#   Edition of GitLab to manage
#
# @param syslog
#   Whether or not to use the SIMP Rsyslog module.
#
# @param syslog_target
#   If $syslog is true, store logs at this (filesystem) location.
#
#
#
# 
# @author simp
#
class simp_gitlab (
  Simplib::Netlist     $trusted_nets            = simplib::lookup('simp_options::trusted_nets', {'default_value' => ['127.0.0.1/32'] }),
  Variant[Enum['simp'],Boolean] $pki            = simplib::lookup('simp_options::pki', { 'default_value'         => false }),
  Simplib::Uri         $external_url            = $pki ? { true => "https://${facts['fqdn']}", default => "http://${facts['fqdn']}" },
  Simplib::Netlist     $denied_nets             = [],
  Simplib::Port        $tcp_listen_port         = $pki ? { true => 443, default => 80},
  Boolean              $auditing                = simplib::lookup('simp_options::auditd', { 'default_value'      => false }),
  Boolean              $firewall                = simplib::lookup('simp_options::firewall', { 'default_value'    => false }),
  Boolean              $syslog                  = simplib::lookup('simp_options::syslog', { 'default_value'      => false }),
  Boolean              $selinux                 = simplib::lookup('simp_options::selinux', { 'default_value'     => false }),

  Hash                 $nginx_options           = {},

  Stdlib::Absolutepath $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Stdlib::Absolutepath $app_pki_dir             = '/etc/pki/simp_apps/gitlab/x509',
  Stdlib::Absolutepath $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  Stdlib::Absolutepath $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
  Stdlib::Absolutepath $app_pki_ca              = "${app_pki_dir}/cacerts/cacerts.pem",
  Boolean              $two_way_ssl_validation  = false,
  Integer              $ssl_verify_depth        = 2,
  Array[String]        $openssl_cipher_suite    = simplib::lookup('simp_options::openssl::cipher_suites', { 'default_value' => ['DEFAULT', '!MEDIUM']}),
  Enum['ce','ee']      $edition                 = 'ce',
) {

  include 'postfix'
  include 'ntpd'

  # On EL7, GitLab pulls in
  svckill::ignore{ 'chronyd': }

  # FIXME: nginx trusted_nets (still needs work)
    # FIXME: git server trusted_net
  # FIXME: SSL ciphers (implemented, but untested): https://docs.gitlab.com/omnibus/settings/nginx.html#using-custom-ssl-ciphers
  # FIXME: LDAP configuration

  $oses = load_module_metadata( $module_name )['operatingsystem_support'].map |$i| { $i['operatingsystem'] }
  unless $::operatingsystem in $oses { fail("${::operatingsystem} not supported") }

  file{['/etc/gitlab/nginx', '/etc/gitlab/nginx/conf.d', '/etc/gitlab/nginx/gitlab-server.conf.d']:
    ensure => directory,
  }

  $_http_access_list = epp('simp_gitlab/etc/nginx/http_access_list.conf.epp', {
     'allowed_nets' => $::simp_gitlab::trusted_nets,
     'denied_nets'  => $::simp_gitlab::denied_nets,
     'module_name'  => $module_name,
  })

  file{ '/etc/gitlab/nginx/conf.d/http_access_list.conf':
    content => $_http_access_list,
  }

  # GitLab Omnibus requires alternate port numbers to be included as part of $external_url
  if $simp_gitlab::external_url =~ /^(https?:\/\/[^\/]+)(?!:\d+)(\/.*)?/ {
    $_external_url = "${1}:${simp_gitlab::tcp_listen_port}${2}"
  } else {
    $_external_url = $external_url
  }

  $_nginx_common_options = {
    'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
  }

  $__nginx_pki_options = $::simp_gitlab::two_way_ssl_validation ? {
    true => {
      'ssl_verify_client' => 'on',
      'ssl_verify_depth'  => $::simp_gitlab::ssl_verify_depth,
    },
    default => {}
  }

  $_nginx_pki_options = $::simp_gitlab::pki ? {
    true                          => merge( {
      'ssl_certificate'           => $::simp_gitlab::app_pki_cert,
      'ssl_certificate_key'       => $::simp_gitlab::app_pki_key,
      'redirect_http_to_https'    => true,
      'ssl_ciphers'               => join($::simp_gitlab::openssl_cipher_suite, ':'),
      'ssl_protocols'             => "TLSv1 TLSv1.1 TLSv1.2", #TODO: param
      #      'ssl_session_cache'         => "builtin:1000  shared:SSL:10m",
      'ssl_session_timeout'       => "5m",
      'ssl_prefer_server_ciphers' => "on",




    }, $__nginx_pki_options ),
    default => {}
  }

  $_nginx_options = merge($_nginx_common_options, $_nginx_pki_options, $nginx_options)

  class { 'gitlab':
    external_url  => $_external_url,
    external_port => $simp_gitlab::tcp_listen_port,
    nginx         => $simp_gitlab::_nginx_options,
  }

  if $pki {
    pki::copy{ 'gitlab':
      pki    => $::simp_gitlab::pki,
      source => $::simp_gitlab::app_pki_external_source,
    }
    Pki::Copy['gitlab'] -> Class['gitlab']
  }

  if $firewall {
    iptables::listen::tcp_stateful { 'allow_gitlab_nginx_tcp_connections':
      trusted_nets => $::simp_gitlab::trusted_nets,
      dports       => $::simp_gitlab::tcp_listen_port,
    }
  }

  #### Note: this is a profile; the full component pattern is probably overkill
  ###  include '::simp_gitlab::install'
  ###  include '::simp_gitlab::config'
  ###  include '::simp_gitlab::service'
  ###  Class[ '::simp_gitlab::install' ]
  ###  -> Class[ '::simp_gitlab::config'  ]
  ###  ~> Class[ '::simp_gitlab::service' ]
  ###  -> Class[ '::simp_gitlab' ]
  ###
  ###  if $pki {
  ###    include '::simp_gitlab::config::pki'
  ###    Class[ '::simp_gitlab::config::pki' ]
  ###    -> Class[ '::simp_gitlab::service' ]
  ###  }
  ###
  ###  if $enable_auditing {
  ###    include '::simp_gitlab::config::auditing'
  ###    Class[ '::simp_gitlab::config::auditing' ]
  ###    -> Class[ '::simp_gitlab::service' ]
  ###  }
  ###
  ###  if $firewall {
  ###    include '::simp_gitlab::config::firewall'
  ###    Class[ '::simp_gitlab::config::firewall' ]
  ###    -> Class[ '::simp_gitlab::service'  ]
  ###  }
  ###
  ###  if $enable_logging {
  ###    include '::simp_gitlab::config::logging'
  ###    Class[ '::simp_gitlab::config::logging' ]
  ###    -> Class[ '::simp_gitlab::service' ]
  ###  }
  ###
  ###  if $enable_selinux {
  ###    include '::simp_gitlab::config::selinux'
  ###    Class[ '::simp_gitlab::config::selinux' ]
  ###    -> Class[ '::simp_gitlab::service' ]
  ###  }
  ###
  ###  if $enable_tcpwrappers {
  ###    include '::simp_gitlab::config::tcpwrappers'
  ###    Class[ '::simp_gitlab::config::tcpwrappers' ]
  ###    -> Class[ '::simp_gitlab::service' ]
  ###  }
}
