# == Class simp_gitlab::config::firewall
#
# This class is meant to be called from simp_gitlab.
# It ensures that firewall rules are defined.
#
class simp_gitlab::config::firewall {
  assert_private()

  # FIXME: ensure your module's firewall settings are defined here.
  iptables::listen::tcp_stateful { 'allow_simp_gitlab_tcp_connections':
    trusted_nets => $::simp_gitlab::trusted_nets,
    dports       => $::simp_gitlab::tcp_listen_port
  }
}
