# Compile a hash of settings for the gitlab module's `shell` parameter, using SIMP settings
# @return Hash of settings for the 'gitlab::shell' parameter
function simp_gitlab::omnibus_config::gitlab_shell() {
  $_shell_base_options = {
    'auth_file' => $simp_gitlab::gitlab_ssh_keyfile,
  }
}

