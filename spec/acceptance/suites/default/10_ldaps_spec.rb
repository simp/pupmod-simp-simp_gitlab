require 'spec_helper_acceptance'
require 'json'
require 'nokogiri'
require 'uri'

test_name 'simp_gitlab ldap tls'

describe 'simp_gitlab using ldap' do

  let(:gitlab_server) {only_host_with_role( hosts, 'server' )}
  let(:ldap_server) {only_host_with_role( hosts, 'ldapserver' )}
  let(:permitted_client) {only_host_with_role( hosts, 'permittedclient' )}
  let(:denied_client) {only_host_with_role( hosts, 'unknownclient' )}
  let(:env_vars){{ 'GITLAB_ROOT_PASSWORD' => 'yourpassword' }}
  let(:ldap_domains){
    ldap_server = only_host_with_role( hosts, 'ldapserver' )
    _domains = fact_on(ldap_server, 'domain').split('.')
    _domains.map! { |d| "dc=#{d}" }
    ldap_domains = _domains.join(',')
  }
  let(:gitlab_signin_url) do
    gitlab_fqdn = fact_on(only_host_with_role(hosts, 'server'), 'fqdn')
    "https://#{gitlab_fqdn}/users/sign_in"
  end

  let(:manifest__ldap_server) do
    <<-EOS_LDAP
      class{'simp_openldap':
        is_server => true,
      }
      include 'svckill'
      include 'iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }
      iptables::listen::tcp_stateful { 'ldaps':
        dports       => [389,636],
        trusted_nets => ['any'],
      }
    EOS_LDAP
  end

  let(:manifest__gitlab) do
    <<-EOS
      include 'svckill'
      include 'iptables'
      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }


      class { 'simp_gitlab':
        trusted_nets => [
                          '10.0.0.0/8',
                          '192.168.21.21',
                          '192.168.21.22',
                          '127.0.0.1/32',
                        ],
        pki      => true,
        firewall => true,
        ldap     => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
      }
    EOS
  end

  let(:ldap_hieradata) do
    files_dir = File.expand_path('../files', __FILE__)
    hieradata_file = File.expand_path('../files/ldap_tls_default.yaml',__FILE__)
    File.read(hieradata_file)
      .gsub('LDAP_BASE_DN',ldap_domains)
      .gsub('LDAP_URI', ldap_server.node_name )
  end

  context 'with TLS & PKI enabled' do
    it 'should prep the test environment' do
      test_prep_manifest = <<-EOM
      # clean up Vagrant's dingleberries
      class{ 'svckill': mode => 'enforcing' }
      EOM
      apply_manifest_on(gitlab_server,  test_prep_manifest, :environment => env_vars)
    end


    shared_examples_for 'a web login for LDAP users' do
      it 'should clean out earlier test environments' do
        remove_gitlab_manifest = <<-PP
          service{'gitlab-runsvdir':
            ensure => stopped,
            enable => false,
          }
          package{['gitlab-ce','gitlab-ee']: ensure=>absent}
          exec{['/opt/gitlab/bin/gitlab-ctl cleanse',
                '/opt/gitlab/bin/gitlab-ctl remove-accounts',
                ]:
            tag => 'before_uninstall',
            onlyif => '/bin/test -f /opt/gitlab/bin/gitlab-ctl',
          }
          exec{'/bin/rm -rf /opt/gitlab*':
            tag => 'after_install',
            onlyif => '/bin/test -f /opt/gitlab*',
          }
          file{'/usr/lib/systemd/system/gitlab-runsvdir.service': ensure=>absent}

          Service <||>
          ->
          Exec<| tag == 'before_uninstall' |>
          ->
          Package<||>
          ->
          Exec<| tag == 'after_install' |>
        PP

        # NOTE: it _might_ be enough to run `gitlab-ctl cleanse`
        apply_manifest_on(gitlab_server, remove_gitlab_manifest, :catch_failures => true)

        on(ldap_server,
           'systemctl status slapd > /dev/null && ' +
             'systemctl stop slapd && ' +
             'rm -rf /var/lib/ldap /etc/openldap && ' +
             'yum erase -y openldap-{servers,clients}; :',
           :environment => env_vars
          )
      end

      it 'should prep the test ldap server' do

        # distribute common LDAP & trusted_nets settings
        hosts.each do |h|
          set_hieradata_on(h, ldap_hieradata, 'default')
        end

        # install LDAP service
        apply_manifest_on(ldap_server, manifest__ldap_server)

        # add accounts
        ldif_file = File.expand_path('../files/ldap_test_user.ldif',__FILE__)
        ldif_text = File.read(ldif_file).gsub('LDAP_BASE_DN',ldap_domains)
        create_remote_file(ldap_server, '/root/user_ldif.ldif', ldif_text)
        on(ldap_server, 'ldapadd -x -ZZ ' +
                        "-D cn=LDAPAdmin,ou=People,#{ldap_domains} " +
                        "-H ldap://#{ldap_server.node_name} " +
                        "-w 'suP3rP@ssw0r!' " +
                        '-f /root/user_ldif.ldif'
          )
      end

      it 'should prep the test hiera data' do
        gitlab_hieradata = ldap_hieradata.gsub('ldap://',ldap_proto)
        set_hieradata_on(gitlab_server, gitlab_hieradata, 'default')
      end

      it 'should apply with no errors' do
        apply_manifest_on(gitlab_server,
                          manifest__gitlab,
                          :catch_failures => true,
                          :environment => env_vars
                         )

        # FIXME: postfix creates the same files twice... is this an ordering issue?
        apply_manifest_on(gitlab_server,
                          manifest__gitlab,
                          :catch_failures => true,
                          :environment => env_vars
                         )
      end

      it 'should be idempotent' do
        apply_manifest_on(gitlab_server,
                          manifest__gitlab,
                          :catch_changes => true,
                          :environment   => env_vars
                         )
      end

      it 'allows https connection on port 443 from permitted clients' do
        shell 'sleep 30' # give it some time to start up

        # The GitLab web interface can take a long time to start.
        # Before trying to connect from other hosts, we'll check in locally
        # every 30 seconds until it's ready (or takes too long)
        result = on(gitlab_server,
                    "#{curl_ssl_cmd(gitlab_server)} --retry 3" +
                    " --retry-delay 30 -L #{gitlab_signin_url}"
                   )
        expect(result.stdout).to match(/GitLab|password/)

        result = on(permitted_client,
                    "#{curl_ssl_cmd(permitted_client)} -L #{gitlab_signin_url}"
                   )
        expect(result.stdout).to match(/GitLab|password/)
      end

      it 'permits an LDAP user to log in via the web page' do
        # This is probably fragile, but we need to test that LDAP users
        # can log in **via the web form** (last tested on 10.3)
        #
        # The following ridiculous procedure was informed by the noble work at
        #
        #   https://stackoverflow.com/questions/47948887/login-to-gitlab-using-curl
        #
        _unique_str = "#{Array.new(8).map{|x|(65 + rand(25)).chr}.join}_#{$$}"
        cookie_file = "/tmp/cookies_#{_unique_str}.txt"
        header_file = "/tmp/headers_#{_unique_str}.txt"

        _curl_cmd = "#{curl_ssl_cmd(permitted_client)} -c #{cookie_file}" +
                    " -D #{header_file} -L '#{gitlab_signin_url}'"
        result  = on(permitted_client, _curl_cmd )
        cookies = on(permitted_client, "cat #{cookie_file}").stdout
        headers = on(permitted_client, "cat #{header_file}").stdout

        doc = Nokogiri::HTML(result.stdout)
        header_csrf_token = doc.at("meta[name='csrf-token']")['content']
        form = doc.at_css 'form#new_ldap_user'
        if form.nil?
          warn "REMINDER: During Simple TLS: Failure/Error: form.css('input#username').first['value'] = 'ldapuser1': undefined method `css' for nil:NilClass", '-'*80, ''
          if ENV['PRY'] == 'yes'
            require 'pry'; binding.pry
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

        gitlab_fqdn = fact_on(gitlab_server, 'fqdn')
        action_uri = "https://#{gitlab_fqdn + form['action']}"
        post_data = URI.encode_www_form(Hash[input_data_hash.map{ |x| [x[:name], x[:value]] }])
        _curl_cmd = "#{curl_ssl_cmd(permitted_client)} -b #{cookie_file}" +
                    " -c #{cookie_file} -D #{header_file} -L '#{action_uri}'" +
                    " -d '#{post_data}' --referer '#{gitlab_signin_url}'"
        result  = on(permitted_client,_curl_cmd)
        doc = Nokogiri::HTML(result.stdout)
        cookies = on(permitted_client, "cat #{cookie_file}").stdout
        headers = on(permitted_client, "cat #{header_file}").stdout

        failed_response_codes = headers.scan(%r[HTTP/1\.\d (\d\d\d) .*$])
                                       .flatten
                                       .select{|x| x !~ /^[23]\d\d/ }
        unless failed_response_codes.empty?
          warn '','-'*80,"REMINDER: found response codes (#{failed_response_codes.join(',')}) during login", '-'*80, ''
          if ENV['PRY'] == 'yes'
            require 'pry'; binding.pry
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
      it_behaves_like 'a web login for LDAP users' do
        let(:ldap_proto){ 'ldap://' }
      end
    end

    context 'authenticates over Simple TLS (ldaps://)' do
      it_behaves_like 'a web login for LDAP users' do
        let(:ldap_proto){ 'ldaps://' }
      end
    end

  end
end
