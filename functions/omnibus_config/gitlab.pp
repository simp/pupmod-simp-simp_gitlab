# Compile a hash of settings for the ``gitlab`` class parameters, using SIMP
# settings
#
# @return Hash of `puppet/gitlab` parameters
function simp_gitlab::omnibus_config::gitlab() {

  # For HTTPS, non-standard ports *must* be included in the external_url:
  $_external_url = $simp_gitlab::external_url ? {
    /^(https?:\/\/[^\/]+)(?!:\d+)(\/.*)?/ => "${1}:${simp_gitlab::tcp_listen_port}${2}",
    default => $simp_gitlab::external_url,
  }

  $_gitlab_default_parameters = {
    'manage_package'          => $simp_gitlab::manage_package,
    'manage_upstream_edition' => $simp_gitlab::edition,
    'package_ensure'          => $simp_gitlab::package_ensure,
    'external_url'            => $_external_url,
    'nginx'                   => simp_gitlab::omnibus_config::nginx(),
    'gitlab_rails'            => simp_gitlab::omnibus_config::gitlab_rails(),
    'shell'                   => simp_gitlab::omnibus_config::gitlab_shell(),
    'mattermost'              => simp_gitlab::omnibus_config::mattermost(),
    'mattermost_nginx'        => { 'enable' => false },
    'prometheus'              => { 'enable' => false },
    'letsencrypt'             => { 'enable' => false },
    'gitlab_exporter'         => { 'enable' => false },
    'node_exporter'           => { 'enable' => false },
    'redis_exporter'          => { 'enable' => false },
    'postgres_exporter'       => { 'enable' => false },

    #'mattermost_nginx_eq_nginx' => true,
  }
}
