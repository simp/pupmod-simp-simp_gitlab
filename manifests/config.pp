# == Class simp_gitlab::config
#
# This class is called from simp_gitlab for service config.
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
}
