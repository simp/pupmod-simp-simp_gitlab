# ## Class simp_gitlab::install
#
# This class is called from simp_gitlab to configure & run the GitLab Omnibus
# installer.  It uses the `vshn/gitlab` module to manage the Omnibus config.
#
class simp_gitlab::install {
  assert_private()

  $_http_access_list = epp('simp_gitlab/etc/nginx/http_access_list.conf.epp', {
    'allowed_nets' => $::simp_gitlab::trusted_nets,
    'denied_nets'  => $::simp_gitlab::denied_nets,
    'module_name'  => $module_name,
  })

  # If you need to configure the main NGINX server, you can use a `file`
  # resource to # drop a `.conf` file in `/etc/gitlab/nginx/conf.d/`
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

  class { 'gitlab':
    external_url  => $_external_url,
    external_port => $simp_gitlab::tcp_listen_port,
    nginx         => simp_gitlab::omnibus_config::nginx(),
  }
}
