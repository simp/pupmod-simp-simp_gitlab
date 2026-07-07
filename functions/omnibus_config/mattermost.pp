# Compile a hash of settings for the ``gitlab::mattermost`` parameter, using
# SIMP settings
#
# NOTE: This function is intentionally NOT wired into
# simp_gitlab::omnibus_config::gitlab anymore. Bundled Mattermost was removed
# from the GitLab Linux package in 19.0, and `gitlab-ctl reconfigure` FATALs on
# the presence of ANY `mattermost[...]` key in gitlab.rb (even `enable=>false`).
# Do not re-add its return value to the omnibus config. To integrate an
# external Mattermost, use `gitlab_rails['mattermost_host']` instead.
#
# @return Hash of settings for the 'gitlab::mattermost' parameter
function simp_gitlab::omnibus_config::mattermost() {
  # Placeholder until we decide to implement mattermost
  { 'enable' => false }
}
