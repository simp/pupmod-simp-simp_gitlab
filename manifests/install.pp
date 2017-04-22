# == Class simp_gitlab::install
#
# This class is called from simp_gitlab for install.
#
# GitLab config & installation is handled by the (chef) Omnibus installer, so
# this "install" class contains logic for config & install
#
class simp_gitlab::install {
  assert_private()

  $_http_access_list = epp('simp_gitlab/etc/nginx/http_access_list.conf.epp', {
    'allowed_nets' => $::simp_gitlab::trusted_nets,
    'denied_nets'  => $::simp_gitlab::denied_nets,
    'module_name'  => $module_name,
  })

  file{['/etc/gitlab', '/etc/gitlab/nginx', '/etc/gitlab/nginx/conf.d']:
    ensure => directory,
  }

  file{ '/etc/gitlab/nginx/conf.d/http_access_list.conf':
    content => $_http_access_list,
  }

  # Non-default HTTPS ports must be included in the external_url
  $_external_url = $simp_gitlab::external_url ? {
    /^(https?:\/\/[^\/]+)(?!:\d+)(\/.*)?/ => "${1}:${simp_gitlab::tcp_listen_port}${2}",
    default => "${external_url}",
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
      'ssl_ciphers'               => join($::simp_gitlab::cipher_suite, ':'),
      'ssl_protocols'             => 'TLSv1 TLSv1.1 TLSv1.2', #TODO: param
      #      'ssl_session_cache'         => "builtin:1000  shared:SSL:10m",
      'ssl_session_timeout'       => '5m',
      'ssl_prefer_server_ciphers' => 'on',
    }, $__nginx_pki_options ),
    default => {}
  }

  $_nginx_options = merge($_nginx_common_options, $_nginx_pki_options, $::simp_gitlab::nginx_options)

  class { 'gitlab':
    external_url  => $_external_url,
    external_port => $simp_gitlab::tcp_listen_port,
    nginx         => $_nginx_options,
  }
}
