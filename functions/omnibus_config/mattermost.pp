# Compile a hash of settings for the gitlab module's `mattermost` parameter, using SIMP settings
# @return Hash of settings for the 'gitlab::mattermost' parameter
function simp_gitlab::omnibus_config::mattermost() {
  # Placeholder until we decide to implement mattermost
  { 'enable' => false }
}
