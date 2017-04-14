# == Class simp_gitlab::install
#
# This class is called from simp_gitlab for install.
#
class simp_gitlab::install {
  assert_private()

  package { $::simp_gitlab::package_name:
    ensure => present
  }
}
