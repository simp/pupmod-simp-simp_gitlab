# Determine the actual path to the  Gitlab `git` user's SSH authorized keys file
# @return String absolute path to the Gitlab `git` user's SSH authorized keys file
function simp_gitlab::authorizedkeyfile_path() {
  if $simp_gitlab::ssh_authorized_keyfile =~ /%{0}%(u|h)/ {
    $__ssh_auth_file = regsubst( $simp_gitlab::ssh_authorized_keyfile, '%u', $simp_gitlab::gitlab_ssh_user, 'G' )
    $result          = regsubst( $__ssh_auth_file, '%h', $simp_gitlab::gitlab_ssh_home, 'G')
  } else {
    $result = $simp_gitlab::ssh_authorized_keyfile
  }
}
