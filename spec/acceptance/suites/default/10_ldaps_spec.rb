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

  # Provides a persistent web browsing session using curl from a SUT client

        #
  class SutWebSession
    attr_reader   :client, :cookie_file, :header_file, :gitlab_signin_url
    attr_accessor :previous_url

    def initialize(client)
      @unique_str   = "#{Array.new(8).map{|x|(65 + rand(25)).chr}.join}_#{$$}"
      @cookie_file  = "/tmp/cookies_#{@unique_str}.txt"
      @header_file  = "/tmp/headers_#{@unique_str}.txt"
      @client       = client
      @curl_cmd     = curl_ssl_cmd(@client)
      @previous_url = nil
    end

    def curl_get(url)
      curl_args      = "-c #{@cookie_file} -D #{@header_file} -L '#{url}'"
      result         = curl_on_client(curl_args)
      @previous_url  = url if result
      result
    end

    def curl_post(url, post_data_hash)
      post_data = URI.encode_www_form(Hash[post_data_hash.map{ |x| [x[:name], x[:value]] }])
      curl_args     = "-b #{@cookie_file} -c #{@cookie_file} -D #{@header_file}" +
                      " -L '#{url}' -d '#{post_data}'"
      result        = curl_on_client(curl_args)
      @previous_url = url if result
      result
    end

    def curl_on_client(curl_args)
      # I don't know if referer is necessary to avoid XSS (the authenticity
      # token should be enough for logins),
      curl_args            += " --referer '#{@previous_url}'" if @previous_url
      result                = on(@client, "#{@curl_cmd} #{curl_args}")
      failed_response_codes = headers.scan(%r[HTTP/1\.\d (\d\d\d) .*$])
                                     .flatten
                                     .select{|x| x !~ /^[23]\d\d/ }
      unless failed_response_codes.empty?
        warn '', '-'*80, "REMINDER: web server returned response codes " +
             "(#{failed_response_codes.join(',')}) during login", '-'*80, ''
        if ENV['PRY'] == 'yes'
          warn "ENV['PRY'] is set to 'yes'; switching to pry console"
          binding.pry
        end
      end
      result.stdout
    end

    def cookies
      on(@client, "cat #{@cookie_file}").stdout
    end

    def headers
      on(@client, "cat #{@header_file}").stdout
    end
  end


  class GitlabSigninForm
    attr_reader :form, :header_csrf_token, :action

    def initialize(html)
      doc = Nokogiri::HTML(html)
      @form = parse_form(doc)
      @header_csrf_token = doc.at("meta[name='csrf-token']")['content']
      @action = @form['action']
    end

    # Returns a hash of all input elements in a completed signin form
    def signin_post_data(username, password)
        @form.css('input#username').first['value'] = username
        @form.css('input#password').first['value'] = password
        input_data_hash = form.css('input').map do |x|
          {
            :name  => x['name'],
            :type  => x['type'],
            :value => (x['value'] || nil)
          }
        end
        input_data_hash.select{|x| x[:name] == 'authenticity_token' }.first[:value] = @header_csrf_token
        input_data_hash
    end

    private

    def parse_form(doc)
      form = doc.at_css 'form#new_ldap_user'
      if form.nil?
        warn "WARNING: Nokogiri didn't find the expected `form#new_ldap_user`", '-'*80, ''
        if ENV['PRY'] == 'yes'
          warn "ENV['PRY'] is set to 'yes'; switching to pry console"
          binding.pry
        end
      end
      form
    end
  end

  context 'with TLS & PKI enabled' do

    shared_examples_for 'a web login for LDAP users' do |ldap_proto|
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
      # The following ridiculous procedure was informed by the noble work at:
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

        # Test for failure
        expect(noko_alert_text).to_not match(/^Could not authenticate/)

        # Test for success
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
