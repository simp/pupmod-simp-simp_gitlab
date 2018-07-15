# Compile a hash of settings for the gitlab module's `gitlab_rails` parameter,
# using SIMP settings
#
# @return Hash of settings for the 'gitlab::gitlab_rails' # parameter
function simp_gitlab::omnibus_config::gitlab_rails() {

  $options = {
    'usage_ping_enabled' => false,
  }

  # --------------------------------------------------------------------
  # Construct the 'dap_servers' Hash
  # --------------------------------------------------------------------
  $_servers = hash($simp_gitlab::ldap_uri.map |$server| {

    # We should also capture a port if it is specified at end of the URL, but
    # even simp_openldap doesn't support that.
    $_port = $server ? {
      /^(ldap):/  => '389', # 'plain' or 'start_tls'
      /^(ldaps):/ => '636', # 'simple_tls'
      default     => fail("Cannot determine the LDAP port for '${server}'" ),
    }

    $_encryption = $server ? {
      /^(ldap):/  => 'start_tls',  # starts at 'plain' and negotiates up
      /^(ldaps):/ => 'simple_tls', # ldaps is more secure, but deprecated
      default     => fail("Cannot determine the LDAP encryption for '${server}'" ),
    }

    [
      # can't use underscores: https://gitlab.com/gitlab-org/gitlab-ee/issues/1863
      regsubst($server, '\.|[-:/_]', '', 'G'),
      {
        ## label
        #
        # A human-friendly name for your LDAP server. It is OK to change the label later,
        # for instance if you find out it is too large to fit on the web page.
        #
        # Example: 'Paris' or 'Acme, Ltd.'
        'label'                         => 'LDAP',
        'host'                          => regsubst($server,'^ldaps?://',''),
        'port'                          => $_port,
        'uid'                           => 'uid',
        'encryption'                    => $_encryption,
        'bind_dn'                       => $simp_gitlab::ldap_bind_dn,
        'password'                      => $simp_gitlab::ldap_bind_pw,
        'active_directory'              => $simp_gitlab::ldap_active_directory,
        'allow_username_or_email_login' => false,
        'block_auto_created_users'      => false,
        'base'                          => $simp_gitlab::ldap_base_dn,
        'group_base'                    => pick_default($simp_gitlab::ldap_group_base,''),
        'user_filter'                   => pick_default($simp_gitlab::ldap_user_filter,''),
        # using the Omnibus trusted_certs instead: https://gitlab.com/gitlab-org/gitlab-ce/issues/37254
        #'ca_file'                       => $simp_gitlab::app_pki_ca,
        'verify_certificates'           => $simp_gitlab::ldap_verify_certificates,
      }
    ]
  })

  $ldap_options = $::simp_gitlab::ldap ? {
    true    => {
      'ldap_enabled' => true,
      'ldap_servers' => $_servers,
    },
    default =>  {},
  }
  # --------------------------------------------------------------------

  deep_merge( $options, $ldap_options )

}

