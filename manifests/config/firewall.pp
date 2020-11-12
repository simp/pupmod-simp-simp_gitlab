# @summary Manage firewall for external GitLab access
#
# @api private
# @author https://github.com/simp/pupmod-simp-simp_gitlab/graphs/contributors
#
class simp_gitlab::config::firewall {
  assert_private()

  iptables::listen::tcp_stateful { 'allow_gitlab_nginx_tcp':
    trusted_nets => $::simp_gitlab::trusted_nets,
    dports       => $::simp_gitlab::tcp_listen_port
  }
}
