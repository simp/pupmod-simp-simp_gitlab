# Compile a hash of settings for the gitlab module's `gitlab_rails` parameter, using SIMP settings
# @return Hash of settings for the 'gitlab::gitlab_rails' parameter
function simp_gitlab::omnibus_config::gitlab_rails() >> Hash {

$_servers = hash($simp_gitlab::ldap_uri.map |$server| {

  # We should also capture a port if it is specified at end of the URL, but
  # simp_openldap doesn't even support that.
  $_port = $server ? {
    /^(ldap):/  => '389',
    /^(ldaps):/ => '636',
    default     => fail("Cannot determine the LDAP port for '${server}'" ),
  }

  $_method = $server ? {
    /^(ldap):/  => 'plain',
    /^(ldaps):/ => 'tls',
    default     => fail("Cannot determine the LDAP method for '${server}'" ),
  }

  [ $server,
    {
      'label'                         => 'LDAP',
      'host'                          => $server,
      'port'                          => $_port,
      'uid'                           => 'uid',
      'method'                        => $_method,
      'bind_dn'                       => $simp_gitlab::ldap_bind_dn,
      'password'                      => $simp_gitlab::ldap_bind_pw,
      'active_directory'              => $simp_gitlab::ldap_active_directory,
      'allow_username_or_email_login' => false,
      'block_auto_created_users'      => false,
      'base'                          => $simp_gitlab::ldap_base_dn,
      'group_base'                    => pick_default($simp_gitlab::ldap_group_base,''),
      'user_filter'                   => pick_default($simp_gitlab::ldap_user_filter,''),
    }
  ]
})

  if $::simp_gitlab::ldap {
    {
      'ldap_enabled' => true,
      'ldap_servers' => $_servers,
    }
  } else {
    {}
  }
}

