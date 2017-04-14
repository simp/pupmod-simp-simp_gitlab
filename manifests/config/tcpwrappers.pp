# == Class simp_gitlab::config::tcpwrappers
#
# This class is meant to be called from simp_gitlab.
# It ensures that tcpwrappers rules are defined.
#
class simp_gitlab::config::tcpwrappers {
  assert_private()

  # FIXME: ensure your module's tcpwrappers settings are defined here.
  $msg = "FIXME: define the ${module_name} module's tcpwrappers settings."

  notify{ 'FIXME: tcpwrappers': message => $msg } # FIXME: remove this, add logic
  err( $msg )                                     # FIXME: remove this, add logic

}

