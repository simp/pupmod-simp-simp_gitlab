# Full description of SIMP module 'simp_gitlab' here.
#
# === Welcome to SIMP!
# This module is a component of the System Integrity Management Platform, a
# managed security compliance framework built on Puppet.
#
# ---
# *FIXME:* verify that the following paragraph fits this module's characteristics!
# ---
#
# This module is optimally designed for use within a larger SIMP ecosystem, but
# it can be used independently:
#
# * When included within the SIMP ecosystem, security compliance settings will
#   be managed from the Puppet server.
#
# * If used independently, all SIMP-managed security subsystems are disabled by
#   default, and must be explicitly opted into by administrators.  Please
#   review the +trusted_nets+ and +$enable_*+ parameters for details.
#
# @param service_name
#   The name of the simp_gitlab service
#
# @param package_name
#   The name of the simp_gitlab package
#
# @param trusted_nets
#   A whitelist of subnets (in CIDR notation) permitted access
#
# @param enable_auditing
#   If true, manage auditing for simp_gitlab
#
# @param enable_firewall
#   If true, manage firewall rules to acommodate simp_gitlab
#
# @param enable_logging
#   If true, manage logging configuration for simp_gitlab
#
# @param enable_pki
#   If true, manage PKI/PKE configuration for simp_gitlab
#
# @param enable_selinux
#   If true, manage selinux to permit simp_gitlab
#
# @param enable_tcpwrappers
#   If true, manage TCP wrappers configuration for simp_gitlab
#
# @author simp
#
class simp_gitlab (
  Simplib::Netlist     $trusted_nets               = simplib::lookup('simp_options::trusted_nets', {'default_value' => ['127.0.0.1/32'] }),
  Boolean              $enable_pki                 = simplib::lookup('simp_options::pki', { 'default_value'         => false }),
  Stdlib::Absolutepath $app_pki_external_source    = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Boolean              $enable_auditing            = simplib::lookup('simp_options::auditd', { 'default_value'      => false }),
  Boolean              $enable_firewall            = simplib::lookup('simp_options::firewall', { 'default_value'    => false }),
  Boolean              $enable_logging             = simplib::lookup('simp_options::syslog', { 'default_value'      => false }),
  Boolean              $enable_selinux             = simplib::lookup('simp_options::selinux', { 'default_value'     => false }),
  Boolean              $enable_tcpwrappers         = simplib::lookup('simp_options::tcpwrappers', { 'default_value' => false }),

  Hash                 $nginx_options              = {},
  Simplib::Uri         $external_url               = $enable_pki ? { true => "https://${facts['fqdn']}", default => "http://${facts['fqdn']}" },
  Simplib::Port        $tcp_listen_port            = $enable_pki ? { true => 443, default => 80},
) {

  $oses = load_module_metadata( $module_name )['operatingsystem_support'].map |$i| { $i['operatingsystem'] }
  unless $::operatingsystem in $oses { fail("${::operatingsystem} not supported") }


  if $external_url =~ /\/\/(.+)?([:\/]|$)/ {
    $external_server = $1
  }
  else {
    fail( "could not determine server name for URL '${external_url}'" )
  }

  # TODO: should these be params?
  $app_pki_dir             = '/etc/pki/simp_apps/gitlab/x509'
  $app_pki_key             = "${app_pki_dir}/private/${external_server}.pem"
  $app_pki_cert            = "${app_pki_dir}/public/${external_server}.pub"

  $default_nginx_options = $enable_pki ? {
    true => {
      'ssl_certificate'        => $app_pki_cert,
      'ssl_certificate_key'    => $app_pki_key,
      'redirect_http_to_https' => true,
    },
    default => {}
  }

  $_nginx_options = merge($default_nginx_options, $nginx_options)

  class { 'gitlab':
    external_url  => $simp_gitlab::external_url,
    external_port => $simp_gitlab::tcp_listen_port,
    nginx         => $_nginx_options,
  }

  if $enable_pki {
    pki::copy{ 'gitlab':
      pki => $enable_pki,
    }
    Pki::Copy['gitlab'] -> Class['gitlab']
  }

  if $enable_firewall {
    iptables::listen::tcp_stateful { 'allow_simp_gitlab_tcp_connections':
      trusted_nets => $::simp_gitlab::trusted_nets,
      dports       => $::simp_gitlab::tcp_listen_port
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
  ###  if $enable_pki {
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
  ###  if $enable_firewall {
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
