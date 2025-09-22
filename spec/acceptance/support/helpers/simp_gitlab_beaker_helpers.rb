# memoized variables to share across examples
module SimpGitlabBeakerHelpers::SutVariables
  def gitlab_ce_version
    unless @gitlab_ce_version
      @gitlab_ce_version = if ENV['TEST_GITLAB_CE_VERSION'] && !ENV['TEST_GITLAB_CE_VERSION'].strip.empty?
                             # explicit version
                             ENV['TEST_GITLAB_CE_VERSION']
                           else
                             'latest'
                           end
    end
    @gitlab_ce_version
  end

  def gitlab_server
    @gitlab_server ||= only_host_with_role(hosts, 'server')
  end

  def ldap_server
    @ldap_server ||= only_host_with_role(hosts, 'ldapserver')
  end

  def permitted_client
    @permitted_client ||= only_host_with_role(hosts, 'permittedclient')
  end

  def denied_client
    @denied_client ||= only_host_with_role(hosts, 'unknownclient')
  end

  def gitlab_server_fqdn
    @gitlab_server_fqdn ||= fact_on(gitlab_server, 'fqdn')
  end

  def ldap_server_fqdn
    @ldap_server_fqdn ||= fact_on(ldap_server, 'fqdn')
  end

  def permitted_client_fqdn
    @permitted_client_fqdn ||= fact_on(permitted_client, 'fqdn')
  end

  def denied_client_fqdn
    @denied_client_fqdn ||= fact_on(denied_client, 'fqdn')
  end

  def gitlab_signin_url(proto = 'https', port = nil)
    "#{proto}://#{gitlab_server_fqdn}#{":#{port}" if port}/users/sign_in"
  end
end
