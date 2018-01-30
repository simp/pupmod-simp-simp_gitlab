require 'spec_helper_acceptance'
require 'nokogiri'
require 'helpers/sut_web_session'
require 'helpers/gitlab_signin_form'

describe 'simp_gitlab using ldap' do

  # We're using instances variables instead of `let()` blocks to run expensive
  # ops up front and keep beaker log chatter focused on the tests
  before(:all) do
    _domains     = fact_on(ldap_server, 'domain').split('.')
    _domains.map! { |d| "dc=#{d}" }
    @ldap_domains = _domains.join(',')

    hieradata_file = File.expand_path('../support/files/ldap_tls_default.yaml',__FILE__)
    @ldap_hieradata = File.read(hieradata_file)
                        .gsub('LDAP_BASE_DN',@ldap_domains)
                        .gsub('LDAP_URI', ldap_server.node_name )

    @manifest__remove_gitlab = File.read(
      File.expand_path('../support/manifests/remove_gitlab.pp',__FILE__)
    )
    @manifest__ldap_server   = File.read(
      File.expand_path('../support/manifests/install_ldap_server.pp',__FILE__)
    )
    @manifest__gitlab = <<-EOS
      include 'svckill'
      include 'iptables'
      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }

      class { 'simp_gitlab':
        trusted_nets => [ #{ENV['TRUSTED_NETS'].to_s.split(/[,| ]/).map{|x| "\n#{' '*26}'#{x}',"}.join}
                          '#{gitlab_server.get_ip}',
                          '#{permitted_client.get_ip}',
                          '127.0.0.1/32',
                        ],
        pki      => true,
        firewall => true,
        ldap     => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
      }
    EOS
  end


  context 'with TLS & PKI enabled' do
    shared_examples_for 'a web login for LDAP users' do |ldap_proto|
      before :all do

        # clean out earlier gitlab environments
        apply_manifest_on(gitlab_server, @manifest__remove_gitlab, catch_failures: true)

        # clean out earlier ldap environments
        on(ldap_server,
           'systemctl status slapd > /dev/null && ' +
             'systemctl stop slapd && ' +
             'rm -rf /var/lib/ldap /etc/openldap && ' +
             'yum erase -y openldap-{servers,clients}; :'
          )

        # set up the ldap server
        # ------------------------------
        # distribute common LDAP & trusted_nets settings
        hosts.each { |h| set_hieradata_on(h, @ldap_hieradata, 'default') }

        # install LDAP service
        apply_manifest_on(ldap_server, @manifest__ldap_server)

        # add LDAP accounts
        ldif_file = File.expand_path('../support/files/ldap_test_user.ldif',__FILE__)
        ldif_text = File.read(ldif_file).gsub('LDAP_BASE_DN',@ldap_domains)
        create_remote_file(ldap_server, '/root/user_ldif.ldif', ldif_text)
        result = on(ldap_server, 'ldapadd -x -ZZ ' +
                        "-D cn=LDAPAdmin,ou=People,#{@ldap_domains} " +
                        "-H ldap://#{ldap_server_fqdn} " +
                        "-w 'suP3rP@ssw0r!' " +
                        '-f /root/user_ldif.ldif'
        )
      end

      it 'should be configured with the test hiera data' do
        gitlab_hieradata = @ldap_hieradata.gsub('ldap://',ldap_proto)
        set_hieradata_on(gitlab_server, gitlab_hieradata, 'default')
      end

      it 'should apply with no errors' do
        apply_manifest_on(gitlab_server,@manifest__gitlab,catch_failures: true)

        # FIXME: postfix creates the same files twice... is this an ordering issue?
        apply_manifest_on(gitlab_server,@manifest__gitlab,catch_failures: true)
      end

      it 'should be idempotent' do
        apply_manifest_on(gitlab_server,@manifest__gitlab,catch_changes: true)
      end

      it_behaves_like('a GitLab web service', gitlab_signin_url, firewall: true)

      # The acceptance criteria for this test is that the user can log in
      # from a permitted client **using the GitLab web interface**
      # ------------------------------------------------------------------------
      #
      # Troubleshooting:
      #
      #   - Check for login errors on the gitlab_sever in
      #     /var/log/gitlab/unicorn/unicorn_stdout.log
      #
      # Common errors:
      #
      #   ERROR -- omniauth: (ldapldapclient2hosttld) Authentication failure!
      #     ldap_error: Net::LDAP::Error,
      #     SSL_connect returned=1 errno=0 state=error: certificate verify failed
      #   ERROR -- omniauth: (ldapldapclient2hosttld) Authentication failure!
      #     invalid_credentials: OmniAuth::Strategies::LDAP::InvalidCredentialsError,
      #     Invalid credentials for ldapuser1
      #
      # This procedure was informed by the noble work at:
      #
      #   https://stackoverflow.com/questions/47948887/login-to-gitlab-using-curl
      #
      it 'permits an LDAP user to log in via the web page' do

        user1_session = SutWebSession.new(permitted_client)
        html    = user1_session.curl_get(gitlab_signin_url)
        gl_form = GitlabSigninForm.new(html)
        html = user1_session.curl_post(
          "https://#{gitlab_server_fqdn + gl_form.action}",
          gl_form.signin_post_data('ldapuser1','suP3rP@ssw0r!')
        )
        doc     = Nokogiri::HTML(html)

        noko_alerts     = doc.css("div[class='flash-alert']")
        profile_link    = doc.css("a[class='profile-link']")
        noko_alert_text = ''
        unless noko_alerts.empty?
          noko_alert_text = noko_alerts.text.strip
          warn '='*80,"== noko alert text: '#{noko_alert_text}'",'='*80
        end

        if(noko_alert_text =~ /^Could not authenticate/ || profile_link.empty?)
          warn "ENV['PRY'] is set to 'yes'; switching to pry console"
          binding.pry if ENV['PRY'] == 'yes'
        end

        # Test for failure
        expect(noko_alert_text).to_not match(/^Could not authenticate/)

        # Test for success
        expect(profile_link).not_to be_empty
        expect(profile_link.first['data-user']).to eq('ldapuser1')
      end
    end

    context 'authenticates over StartTLS (ldap://)' do
      test_name 'simp_gitlab ldap startls'
      it_behaves_like 'a web login for LDAP users', 'ldap://'
    end

    context 'authenticates over Simple TLS (ldaps://)' do
      test_name 'simp_gitlab ldap simple tls'
      it_behaves_like 'a web login for LDAP users', 'ldaps://'
    end

  end
end
