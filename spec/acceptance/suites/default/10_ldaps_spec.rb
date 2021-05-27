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
    @manifest__gitlab = <<~EOS
      include 'svckill'
      include 'iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }

      class { 'simp_gitlab':
        trusted_nets            => [ #{ENV['TRUSTED_NETS'].to_s.split(/[,| ]/).map{|x| "\n#{' '*30}'#{x}',"}.join}
                                     '#{gitlab_server.get_ip}',
                                     '#{permitted_client.get_ip}',
                                     '127.0.0.1/32',
                                   ],
        pki                     => true,
        firewall                => true,
        ldap                    => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
        package_ensure          => '#{gitlab_ce_version}',
      }

      # allow vagrant access despite change in the default location of
      # authorized keys files that comes from SIMP's ssh module
      file { '/etc/ssh/local_keys/vagrant':
        ensure  => file,
        owner   => 'vagrant',
        group   => 'vagrant',
        source  => '/home/vagrant/.ssh/authorized_keys',
        mode    => '0644',
        seltype => 'sshd_key_t',
       }
    EOS
  end

  hosts_with_role(hosts, 'ldapserver').each do |ldapserver|
    context "on LDAP server #{ldapserver}" do
      it 'should enable additional OS repos as needed' do
        result = on(ldapserver, 'cat /etc/oracle-release', :accept_all_exit_codes => true)
        if (result.exit_code == 0) && ldapserver[:platform].match(/el-7/)
          # OEL 7 needs another repo enabled for the openssh-ldap package
          ldapserver.install_package('yum-utils')
          on(ldapserver, 'yum-config-manager --enable ol7_optional_latest')
        end
      end
    end
  end

  context 'with TLS & PKI enabled' do
    shared_examples_for 'a web login for LDAP users' do |ldap_proto|
      before :all do

        # clean out earlier gitlab environments
        apply_manifest_on(gitlab_server, @manifest__remove_gitlab, catch_failures: true)

        # clean out earlier ldap environments
        on(ldap_server,
           'puppet resource service slapd ensure=stopped > /dev/null && ' +
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
        # On slow servers, the gitlab-rails console may not come up in the
        # allotted time after a `gitlab-ctl reconfigure`. This means
        # `Exec[set_gitlab_root_password]` will fail. So may need to execute
        # `puppet apply` twice to get to a non-errored state.
        result = apply_manifest_on(gitlab_server,@manifest__gitlab, acceptable_exit_codes: [0,1,2,4,6] )

        unless [0,2].include?(result.exit_code)
          puts '>'*80
          puts 'First `puppet apply` with gitlab install failed. Retrying...'
          puts '<'*80
          apply_manifest_on(gitlab_server,@manifest__gitlab,catch_failures: true)
        end
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
      #   - Check for access errors on the gitlab_server in
      #     /var/log/gitlab/nginx/gitlab_error.log
      #
      #   - Check for login errors on the gitlab_server in
      #     /var/log/gitlab/puma/puma_stdout.log
      #     or (older GitLab versions)
      #     /var/log/gitlab/unicorn/unicorn_stdout.log
      #
      # Common errors:
      # nginx:
      #   [error]...access forbidden by rule, client: 1.2.3.4,...
      #   Unless nginx configuration has radically changed, you will only
      #   see this if you have not set the TRUSTED_NETS environment variable
      #   appropriately, when you attempt to access the SUT's GitLab server
      #   from a web browser.
      #
      # puma:
      #   ERROR -- omniauth: (ldapldapclient2hosttld) Authentication failure!
      #     ldap_error: Net::LDAP::Error,
      #     SSL_connect returned=1 errno=0 state=error: certificate verify failed
      #   ERROR -- omniauth: (ldapldapclient2hosttld) Authentication failure!
      #     invalid_credentials: OmniAuth::Strategies::LDAP::InvalidCredentialsError,
      #     Invalid credentials for ldapuser1
      #
      # Web session handling:
      #   ERROR: Not a recognizable signin form
      #     * GitlabSigninForm has failed to parse the returned HTML page,  because the
      #       page returned is not the expected login page.
      #     * If you examine the HTML returned (e.g., load it into a browser), and the
      #       page is a change password page, this means the GitLab root password was
      #       not set during install.
      #
      # This procedure was informed by the noble work at:
      #
      #   https://stackoverflow.com/questions/47948887/login-to-gitlab-using-curl
      #
      it 'permits an LDAP user to log in via the web page' do

        user1_session = SutWebSession.new(permitted_client)
        html    = user1_session.curl_get(gitlab_signin_url)
        gl_form = GitlabSigninForm.new(html)
        html    = user1_session.curl_post(
          "https://#{gitlab_server_fqdn + gl_form.action}",
          gl_form.signin_post_data('ldapuser1','suP3rP@ssw0r!')
        )
        doc     = Nokogiri::HTML(html)

        # The following CSS-based searches are fragile, but the best
        # we can do...

        # Looking for the list item that is the drop down with user settings.
        # Currently it is in the top most right corner of the web page, when the
        # user has logged in.
        current_user = doc.css("li[class='current-user']").first
        current_user_text = nil
        if current_user.nil?
          warn '='*80,'== list item with current-user not found ==','='*80
        else
          current_user_text = current_user.text
          unless current_user_text.match('ldapuser1')
            warn "INFO: current-user list item text: #{current_user_text}"
          end
        end

        # Looking for the alert banner that appears at the top of the login
        # web page when the login attempt is unsuccessful.
        login_alerts = doc.css("div[class~='flash-alert']")
        login_alert_text = ''
        unless login_alerts.empty?
          login_alert_text = login_alerts.text.strip
          warn '='*80,"== login alert text: '#{login_alert_text}'",'='*80
        end

        if ENV['PRY'] == 'yes'
          if(login_alert_text =~ /^Could not authenticate/ || !current_user_text.match('ldapuser1'))
            warn "ENV['PRY'] is set to 'yes'; switching to pry console"
            binding.pry
          end
        end

        # Test for failure
        expect(login_alert_text).to_not match(/^Could not authenticate/)

        # Test for success
        expect(current_user).not_to be_nil
        expect(current_user_text).to match(/ldapuser1/)
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
