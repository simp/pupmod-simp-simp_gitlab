# == Class simp_gitlab::config::firewall
#
# This class is meant to be called from simp_gitlab.
# It ensures that firewall rules are defined.
#
class simp_gitlab::config::firewall {
  assert_private()

  iptables::listen::tcp_stateful { 'allow_gitlab_nginx_tcp':
    trusted_nets => $::simp_gitlab::trusted_nets,
    dports       => $::simp_gitlab::tcp_listen_port
  }
}
