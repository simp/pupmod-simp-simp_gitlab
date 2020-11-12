# @summary Manage additional GitLab-related configuration
#
# @api private
# @author https://github.com/simp/pupmod-simp-simp_gitlab/graphs/contributors
#
class simp_gitlab::config {
  assert_private()

  $pam_access_origins = $simp_gitlab::trusted_nets.map |$x| {
    regsubst($x, /^127\.0\.0\.1.*/, 'LOCAL')
  }

  pam::access::rule { 'Allow GitLab git users via ssh':
    users   => [ $simp_gitlab::gitlab_ssh_user ],
    origins => $pam_access_origins,
    comment => 'Allow Gitlab git access via ssh',
  }

  file { '/usr/local/sbin/change_gitlab_root_password':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => file("${module_name}/usr/local/sbin/change_gitlab_root_password")
  }

  if $simp_gitlab::set_gitlab_root_password {
    # This only runs if the marker file created by change_gitlab_root_password
    # is absent
    $_exe = '/usr/local/sbin/change_gitlab_root_password'
    $_timeout = $simp_gitlab::rails_console_load_timeout
    exec { 'set_gitlab_root_password':
      command => "${_exe} -t ${_timeout} ${simp_gitlab::gitlab_root_password}",
      require => File['/usr/local/sbin/change_gitlab_root_password'],
      creates => '/etc/gitlab/.root_password_set',

      # make sure Puppet timeout is longer than max time we would allow for
      # the script to run
      timeout => $_timeout + 60,
    }

    Class['gitlab::service'] -> Exec['set_gitlab_root_password']
  }

}
