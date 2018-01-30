# Compile a hash of settings for the gitlab module's `nginx` parameter, using SIMP settings
# @return Hash of settings for the 'gitlab::nginx' parameter
function simp_gitlab::omnibus_config::nginx() {

  # These options are always used
  $_nginx_base_options = {
    'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
  }

  $__nginx_pki_validation_options = $::simp_gitlab::two_way_ssl_validation ? {
    true => {
      'ssl_verify_client' => 'on',
      'ssl_verify_depth'  => $::simp_gitlab::ssl_verify_depth,
    },
    default => {}
  }

  $__nginx_pki_base_options = {
      'redirect_http_to_https'    => true,
      'ssl_certificate'           => $::simp_gitlab::app_pki_cert,
      'ssl_client_certificate'    => $::simp_gitlab::app_pki_ca,
      'ssl_certificate_key'       => $::simp_gitlab::app_pki_key,
      'ssl_ciphers'               => join($::simp_gitlab::cipher_suite, ':'),
      # TODO: there doesn't appear to be a SIMP global catalyst for SSL protocols
      'ssl_protocols'             => join($::simp_gitlab::ssl_protocols,' '),
      'ssl_prefer_server_ciphers' => 'on',
      'ssl_session_timeout'       => '5m',

      # Using only "shared" is more efficient:
      #   - https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_session_cache
      'ssl_session_cache'         => 'shared:SSL:10m',

      ## Reminder: Gitlab Omnibus will disable compression when HTTPS is
      ## enabled, regardless of the value of the 'gzip' setting:
      ##  - https://docs.gitlab.com/ce/security/crime_vulnerability.html
      # 'gzip'                      => 'off'
  }

  $_nginx_pki_options = $::simp_gitlab::pki ? {
    true => merge( $__nginx_pki_base_options, $__nginx_pki_validation_options ),
    simp => merge( $__nginx_pki_base_options, $__nginx_pki_validation_options ),
    default => {}
  }

  $_nginx_options = merge($_nginx_base_options, $_nginx_pki_options)
}
