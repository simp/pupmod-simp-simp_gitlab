# @summary Install, initially configure and bring up a GitLab instance
#
# It uses the `puppet/gitlab` module to manage the Omnibus config, install
# the package, and run the GitLab Omnibus installer.
#
# @api private
# @author https://github.com/simp/pupmod-simp-simp_gitlab/graphs/contributors
#
class simp_gitlab::install {
  assert_private()

  # In the gitlab resource, we are configuring the NGINX server to load `.conf`
  # files in `/etc/gitlab/nginx/conf.d`, so make sure we have that set up.
  $_http_access_list = epp('simp_gitlab/etc/nginx/http_access_list.conf.epp', {
    'allowed_nets' => $simp_gitlab::trusted_nets,
    'denied_nets'  => $simp_gitlab::denied_nets,
    'module_name'  => $module_name,
  })

  file {['/etc/gitlab/nginx', '/etc/gitlab/nginx/conf.d']:
    ensure => directory,
  }

  file { '/etc/gitlab/nginx/conf.d/http_access_list.conf':
    content => $_http_access_list,
    before  => Class['gitlab::install'],
    notify  => Class['gitlab::service'],
  }

  # Make sure the standard authorized keys file path is used for the
  # the GitLab local user, not the non-standard path set by SIMP. We
  # do this because ssh configuration managed by GitLab via Chef
  # (including ownership, permissions and selinux context of
  # directory in which ssh authorized keys file exists) cannot be
  # simultaneously, but independently, managed by Puppet.
  #
  # As of simp/ssh 9.0.0, `Service['sshd']` is only declared when service
  # management has been requested via `ssh::server::service_ensure` or
  # `ssh::server::service_enable`; a bare `include ssh` leaves the service
  # unmanaged.  Only notify the service when it is actually in the catalog so
  # the catalog still compiles either way.  (When sshd is unmanaged, this
  # setting is not picked up until sshd is restarted by other means.)
  $_sshd_managed = (getvar('ssh::server::service_ensure') =~ NotUndef) or (getvar('ssh::server::service_enable') =~ NotUndef)
  $_sshd_notify = $_sshd_managed ? {
    true    => Service['sshd'],
    default => undef,
  }

  sshd_config { 'AuthorizedKeysFile GitLab user':
    ensure    => present,
    key       => 'AuthorizedKeysFile',
    condition => "User ${simp_gitlab::gitlab_ssh_user}",
    value     => $simp_gitlab::gitlab_ssh_keyfile,
    require   => Package['openssh-server'],
    before    => Class['gitlab'],
    notify    => $_sshd_notify,
  }

  class { 'gitlab':
    * => $simp_gitlab::merged_gitlab_options,
  }

  # gitlab::service optionally manages this service, so when it is not managed,
  # we need to make sure it is not killed
  svckill::ignore { 'gitlab-runsvdir': }
}
