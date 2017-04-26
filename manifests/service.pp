# == Class simp_gitlab::service
#
# This class is meant to be called from simp_gitlab.
# It ensure the service is running.
#
class simp_gitlab::service {
  assert_private()

  service { $::simp_gitlab::service_name:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true
  }
}
