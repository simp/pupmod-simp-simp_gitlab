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
    # Do NOT emit any `mattermost[...]` / `mattermost_nginx[...]` keys. Bundled
    # Mattermost was removed from the GitLab Linux package in 19.0, and
    # `gitlab-ctl reconfigure` now FATALs ("Removed configurations found in
    # gitlab.rb. Aborting reconfigure.") on the mere presence of those keys --
    # even `enable => false`. Leaving them out lets the upstream module's
    # `undef` defaults suppress the block. To integrate an external Mattermost,
    # set `gitlab_rails['mattermost_host']` via gitlab_rails config instead.
    'prometheus'              => { 'enable' => false },
    'letsencrypt'             => { 'enable' => false },
    'gitlab_exporter'         => { 'enable' => false },
    'node_exporter'           => { 'enable' => false },
    'redis_exporter'          => { 'enable' => false },
    'postgres_exporter'       => { 'enable' => false },

    #'mattermost_nginx_eq_nginx' => true,
  }
}
