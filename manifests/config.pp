# == Class simp_gitlab::config
#
# This class is called from simp_gitlab for service config.
#
class simp_gitlab::config {
  assert_private()

  $pam_access_origins = $simp_gitlab::trusted_nets.map |$x| {
    regsubst($x, /^127\.0\.0\.1.*/, 'LOCAL')
  }

  pam::access::rule { 'Allow GitLab git users via ssh':
    users   => [ $simp_gitlab::gitlab_ssh_user ],
    origins => $pam_access_origins,
    comment => 'Allow Gitlab git access via ssh',
  }

  # Gitlab's local user account needs to be able to continuously write to
  # its own SSH authorized keys file
  file { $simp_gitlab::gitlab_ssh_keyfile:
    ensure  => 'file',
    owner   => $simp_gitlab::gitlab_ssh_user,
    group   => $simp_gitlab::gitlab_ssh_group,
    seltype => 'sshd_key_t',
  }

  # SSH authorized_keys file permissions are different between home and
  # /etc/ directories
  if $simp_gitlab::gitlab_ssh_keyfile =~ /^${simp_gitlab::gitlab_ssh_home}/ {
    File[$simp_gitlab::gitlab_ssh_keyfile]{ mode => '0600' }
  } else {
    File[$simp_gitlab::gitlab_ssh_keyfile]{ mode => '0644' }

    # If necessary, exempt the Gitlab authorized keys lock file from
    # `ssh::server::conf`'s hard-coded recursive permissions
    $simp_localkeys_path = '/etc/ssh/local_keys'
    if $simp_gitlab::gitlab_ssh_keyfile =~ regexpescape($simp_localkeys_path) {
      $_glob = basename("${simp_gitlab::gitlab_ssh_keyfile}.lock")
      File <| title == $simp_localkeys_path |> { ignore => $_glob }
    }
  }
}
