require 'spec_helper_acceptance'
require 'json'
require 'nokogiri'
require 'uri'
require 'pry' if ENV['PRY'] == 'yes'

test_name 'simp_gitlab ldap tls'

describe 'simp_gitlab using ldap' do
  let(:manifest__gitlab) do
    <<-EOS
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

  let(:manifest__remove_gitlab) do
    File.read(File.expand_path('../support/manifests/remove_gitlab.pp',__FILE__))
  end

  let(:manifest__ldap_server) do
    File.read(File.expand_path('../support/manifests/install_ldap_server.pp',__FILE__))
  end

  let(:ldap_domains) do
    _domains     = fact_on(ldap_server, 'domain').split('.')
    _domains.map! { |d| "dc=#{d}" }
    ldap_domains = _domains.join(',')
  end

  let(:ldap_hieradata) do
    hieradata_file = File.expand_path('../support/files/ldap_tls_default.yaml',__FILE__)
    File.read(hieradata_file)
      .gsub('LDAP_BASE_DN',ldap_domains)
      .gsub('LDAP_URI', ldap_server.node_name )
  end

  let(:gitlab_signin_url) do
    "https://#{gitlab_server_fqdn}/users/sign_in"
  end

  context 'with TLS & PKI enabled' do
    it 'should prep the test environment' do
      test_prep_manifest = "class{ 'svckill': mode => 'enforcing' }"
      apply_manifest_on(gitlab_server,  test_prep_manifest)
    end


    shared_examples_for 'a web login for LDAP users' do |ldap_proto|
      let :unique_str do
        "#{Array.new(8).map{|x|(65 + rand(25)).chr}.join}_#{$$}"
      end
      let(:cookie_file){ "/tmp/cookies_#{unique_str}.txt" }
      let(:header_file){ "/tmp/headers_#{unique_str}.txt" }

      it 'should clean out earlier test environments' do
        apply_manifest_on(gitlab_server, manifest__remove_gitlab, catch_failures: true)
        on(ldap_server,
           'systemctl status slapd > /dev/null && ' +
             'systemctl stop slapd && ' +
             'rm -rf /var/lib/ldap /etc/openldap && ' +
             'yum erase -y openldap-{servers,clients}; :'
          )
      end

      it 'should prep the test ldap server' do
        # distribute common LDAP & trusted_nets settings
        hosts.each { |h| set_hieradata_on(h, ldap_hieradata, 'default') }

        # install LDAP service
        apply_manifest_on(ldap_server, manifest__ldap_server)

        # add LDAP accounts
        ldif_file = File.expand_path('../support/files/ldap_test_user.ldif',__FILE__)
        ldif_text = File.read(ldif_file).gsub('LDAP_BASE_DN',ldap_domains)
        create_remote_file(ldap_server, '/root/user_ldif.ldif', ldif_text)
        on(ldap_server, 'ldapadd -x -ZZ ' +
                        "-D cn=LDAPAdmin,ou=People,#{ldap_domains} " +
                        "-H ldap://#{ldap_server.node_name} " +
                        "-w 'suP3rP@ssw0r!' " +
                        '-f /root/user_ldif.ldif'
        )
      end

      it 'should be configured with the test hiera data' do
        gitlab_hieradata = ldap_hieradata.gsub('ldap://',ldap_proto)
        set_hieradata_on(gitlab_server, gitlab_hieradata, 'default')
      end

      it 'should apply with no errors' do
        apply_manifest_on(gitlab_server,manifest__gitlab,catch_failures: true)

        # FIXME: postfix creates the same files twice... is this an ordering issue?
        apply_manifest_on(gitlab_server,manifest__gitlab,catch_failures: true)
      end

      it 'should be idempotent' do
        apply_manifest_on(gitlab_server,manifest__gitlab,catch_changes: true)
      end

      it 'serves the GitLab content on port 443' do
        # The delays and retries give the web interface time to start
        shell 'sleep 30'
        result = on(gitlab_server,
          "#{curl_ssl_cmd(gitlab_server)} --retry 3" +
          " --retry-delay 30 -L #{gitlab_signin_url}"
        )
        expect(result.stdout).to match(/GitLab|password/)
      end

      it 'allows https access from permitted clients on port 443' do
        result = on(permitted_client,
          "#{curl_ssl_cmd(permitted_client)} -L #{gitlab_signin_url}"
        )
        expect(result.stdout).to match(/GitLab|password/)
      end

      # The acceptance criteria for this test is that the user can log in
      # from a permitted client **using the GitLab web interface**
      it 'permits an LDAP user to log in via the web page' do
        # The following ridiculous procedure was informed by the noble work at
        #
        #   https://stackoverflow.com/questions/47948887/login-to-gitlab-using-curl
        #
        _curl_cmd = "#{curl_ssl_cmd(permitted_client)} -c #{cookie_file}" +
                    " -D #{header_file} -L '#{gitlab_signin_url}'"
        result  = on(permitted_client, _curl_cmd )

        doc = Nokogiri::HTML(result.stdout)
        header_csrf_token = doc.at("meta[name='csrf-token']")['content']
        form = doc.at_css 'form#new_ldap_user'
        if form.nil?
          warn "WARNING: Nokogiri didn't find the expected `form#new_ldap_user`", '-'*80, ''
          if ENV['PRY'] == 'yes'
            warn "WARNING: PRY: switching to pry console"
            binding.pry
          end
        end
        form.css('input#username').first['value'] = 'ldapuser1'
        form.css('input#password').first['value'] = 'suP3rP@ssw0r!'
        input_data_hash = form.css('input').map do |x|
          {
            :name  => x['name'],
            :type  => x['type'],
            :value => (x['value'] || nil)
          }
        end
        input_data_hash.select{|x| x[:name] == 'authenticity_token' }.first[:value] = header_csrf_token

        # Check for login errors in /var/log/gitlab/unicorn/unicorn_stdout.log
        #
        # Common errors:
        # E, [2017-12-31T02:46:34.658511 #9101] ERROR -- omniauth: (ldapldapclient2onyxpointnet) Authentication failure! ldap_error: Net::LDAP::Error, SSL_connect returned=1 errno=0 state=error: certificate verify failed
        # E, [2017-12-31T03:58:35.041377 #3521] ERROR -- omniauth: (ldapldapclient2onyxpointnet) Authentication failure! invalid_credentials: OmniAuth::Strategies::LDAP::InvalidCredentialsError, Invalid credentials for ldapuser1

        action_uri = "https://#{gitlab_server_fqdn + form['action']}"
        post_data = URI.encode_www_form(Hash[input_data_hash.map{ |x| [x[:name], x[:value]] }])
        _curl_cmd = "#{curl_ssl_cmd(permitted_client)} -b #{cookie_file}" +
                    " -c #{cookie_file} -D #{header_file} -L '#{action_uri}'" +
                    " -d '#{post_data}' --referer '#{gitlab_signin_url}'"
        result  = on(permitted_client,_curl_cmd)
        doc     = Nokogiri::HTML(result.stdout)
        cookies = on(permitted_client, "cat #{cookie_file}").stdout
        headers = on(permitted_client, "cat #{header_file}").stdout

        failed_response_codes = headers.scan(%r[HTTP/1\.\d (\d\d\d) .*$])
                                       .flatten
                                       .select{|x| x !~ /^[23]\d\d/ }
        unless failed_response_codes.empty?
          warn '','-'*80,"REMINDER: found response codes (#{failed_response_codes.join(',')}) during login", '-'*80, ''
          if ENV['PRY'] == 'yes'
            binding.pry
          end
        end

        noko_alert_text = ''
        noko_alerts = doc.css("div[class='flash-alert']")
        if !noko_alerts.empty?
          noko_alert_text = noko_alerts.text.strip
          warn '='*80,"== noko alert text: '#{noko_alert_text}'",'='*80
        end

        # Test for failure
        expect(noko_alert_text).to_not match(/^Could not authenticate/)

        # Test for success
        profile_link = doc.css("a[class='profile-link']")
        expect(profile_link).not_to be_empty
        expect(profile_link.first['data-user']).to eq('ldapuser1')
      end
    end

    context 'authenticates over StartTLS (ldap://)' do
      it_behaves_like 'a web login for LDAP users', 'ldap://'
    end

    context 'authenticates over Simple TLS (ldaps://)' do
      it_behaves_like 'a web login for LDAP users', 'ldaps://'
    end

  end
end
