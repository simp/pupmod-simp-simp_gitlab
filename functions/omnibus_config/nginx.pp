# Compile a hash of settings for the gitlab module's `nginx` parameter, using SIMP settings
function simp_gitlab::omnibus_config::nginx() >> Hash {

  # If you need to configure the main NGINX server, use a `file` resource to
  # drop a `.conf` file in `/etc/gitlab/nginx/conf.d/`
  $_nginx_common_options = {
    'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
  }

  $__nginx_pki_validation_options = $::simp_gitlab::two_way_ssl_validation ? {
    true => {
      'ssl_verify_client' => 'on',
      'ssl_verify_depth'  => $::simp_gitlab::ssl_verify_depth,
    },
    default => {}
  }

  $_nginx_pki_options = $::simp_gitlab::pki ? {
    true => merge( {
      'ssl_certificate'           => $::simp_gitlab::app_pki_cert,
      'ssl_certificate_key'       => $::simp_gitlab::app_pki_key,
      'redirect_http_to_https'    => true,                    #TODO: param
      'ssl_ciphers'               => join($::simp_gitlab::cipher_suite, ':'),
      'ssl_protocols'             => 'TLSv1 TLSv1.1 TLSv1.2', #TODO: param
      'ssl_session_timeout'       => '5m',                    #TODO: param
      'ssl_prefer_server_ciphers' => 'on',                    #TODO: param
      #'ssl_session_cache'         => "builtin:1000  shared:SSL:10m",
    }, $__nginx_pki_validation_options ),
    default => {}
  }

  $_nginx_options = merge($_nginx_common_options, $_nginx_pki_options, $::simp_gitlab::nginx_options)
}
