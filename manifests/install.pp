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
  # resource to drop a `.conf` file in `/etc/gitlab/nginx/conf.d/`
  file {['/etc/gitlab', '/etc/gitlab/nginx', '/etc/gitlab/nginx/conf.d']:
    ensure => directory,
  }

  file { '/etc/gitlab/nginx/conf.d/http_access_list.conf':
    content => $_http_access_list,
    notify  => Class['gitlab'],
  }

  class { 'gitlab':
    * => deep_merge(simp_gitlab::omnibus_config::gitlab(), $::simp_gitlab::gitlab_options),
  }

  # This ill-advised hootenany is a hack until vshn/gitlab exposes ENV for the reconfigure
  Exec <| title == 'gitlab_reconfigure' |> {
    environment => [ "GITLAB_ROOT_PASSWORD=${simp_gitlab::gitlab_root_passwd}" ],
  }
}
