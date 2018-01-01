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
    # Determine what your domain is, in dn form
    _domains = fact_on(ldap_server, 'domain').split('.')
    _domains.map! { |d| "dc=#{d}" }
    ldap_domains = _domains.join(',')
  }

  let(:ldap_server_manifest) do
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

  let(:manifest) do
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

  # helper to build up curl command strings
  def curl_ssl_cmd( host )
    fqdn   = fact_on(host, 'fqdn')
    'curl  --connect-timeout 30'+
         ' --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
         " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
         " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
  end


  context 'with TLS & PKI enabled' do
    it 'should prep the test environment' do
      test_prep_manifest = <<-EOM
      # clean up Vagrant's dingleberries
      class{ 'svckill': mode => 'enforcing' }
      EOM
      apply_manifest_on(gitlab_server,  test_prep_manifest)
    end


    shared_examples_for 'a web login for LDAP users' do
      let(:gitlab_type){ 'ce' }

      it 'should clean out earlier test environments' do
        on(gitlab_server,
           'which gitlab-rake && ' +
             'echo yes | gitlab-rake gitlab:setup && ' +
             'gitlab-rake gitlab:cleanup:dirs && ' +
             'gitlab-rake gitlab:git:prune ;:',
           :environment => env_vars
          )

        on(ldap_server,
           'systemctl status slapd > /dev/null && ' +
             'systemctl stop slapd && ' +
             'rm -rf /var/lib/ldap /etc/openldap && ' +
             'yum erase -y openldap-{servers,clients}',
           :environment => env_vars
          )
      end

      it 'should prep the test ldap server' do

        # distribute common LDAP & trusted_nets settings
        hosts.each do |h|
          set_hieradata_on(h, ldap_hieradata, 'default')
        end

        # install LDAP service
        apply_manifest_on(ldap_server, ldap_server_manifest)

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

      it 'should work with no errors' do
        apply_manifest_on(gitlab_server, manifest, :catch_failures => true, :environment => env_vars)

        # FIXME: postfix creates the same files twice... is this an ordering issue?
        apply_manifest_on(gitlab_server, manifest, :catch_failures => true, :environment => env_vars)
      end

      it 'should be idempotent' do
        apply_manifest_on(gitlab_server, manifest, :catch_changes => true, :environment => env_vars)
      end

      it 'allows https connection on port 443 from permitted clients' do
        shell 'sleep 30' # give it some time to start up
        fqdn = fact_on(gitlab_server, 'fqdn')

        # retry on first connection in case it still needs more time
        result = on(gitlab_server, "#{curl_ssl_cmd(gitlab_server)} --retry 3 --retry-delay 30 -L https://#{fqdn}/users/sign_in" )
        expect(result.stdout).to match(/GitLab|password/)

        result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}/users/sign_in" )
        expect(result.stdout).to match(/GitLab|password/)
      end

      it 'permits an LDAP user to log in via the web page' do
        gitlab_fqdn = fact_on(gitlab_server, 'fqdn')

        # This is probably fragile, but we need to test that LDAP users
        # can log in **via the web form** (last tested on 10.3)
        #
        # The following ridiculous procedure were informed by the noble work at
        #
        #   https://stackoverflow.com/questions/47948887/login-to-gitlab-using-curl
        #
        _unique_str = "#{Array.new(8).map{|x|(65 + rand(25)).chr}.join}_#{$$}"
        cookie_file = "/tmp/cookies_#{_unique_str}.txt"
        header_file = "/tmp/headers_#{_unique_str}.txt"

        signin_url =  "https://#{gitlab_fqdn}/users/sign_in"
        result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -c #{cookie_file} -D #{header_file} -L '#{signin_url}'" )
        cookies = on(permitted_client, "cat #{cookie_file}").stdout
        headers = on(permitted_client, "cat #{header_file}").stdout

        doc = Nokogiri::HTML(result.stdout)
        header_csrf_token = doc.at("meta[name='csrf-token']")['content']
        form = doc.at_css 'form#new_ldap_user'
        form.css('input#username').first['value'] = 'ldapuser1'
        form.css('input#password').first['value'] = 'suP3rP@ssw0r!'
        input_data_hash = form.css('input').map{|x| { :name => x['name'], :type => x['type'], :value => (x['value'] || nil) }}
        input_data_hash.select{|x| x[:name] == 'authenticity_token' }.first[:value] = header_csrf_token

        # Check for login errors in /var/log/gitlab/unicorn/unicorn_stdout.log
        #
        # Common errors:
        # E, [2017-12-31T02:46:34.658511 #9101] ERROR -- omniauth: (ldapldapclient2onyxpointnet) Authentication failure! ldap_error: Net::LDAP::Error, SSL_connect returned=1 errno=0 state=error: certificate verify failed
        # E, [2017-12-31T03:58:35.041377 #3521] ERROR -- omniauth: (ldapldapclient2onyxpointnet) Authentication failure! invalid_credentials: OmniAuth::Strategies::LDAP::InvalidCredentialsError, Invalid credentials for ldapuser1

        action_uri = "https://#{gitlab_fqdn + form['action']}"
        post_data = URI.encode_www_form(Hash[input_data_hash.map{ |x| [x[:name], x[:value]] }])
        _curl_cmd = "#{curl_ssl_cmd(permitted_client)} -b #{cookie_file} -c #{cookie_file} -D #{header_file} -L '#{action_uri}' -d '#{post_data}' --referer '#{signin_url}'"
        result  = on(permitted_client,_curl_cmd)
        doc = Nokogiri::HTML(result.stdout)
        cookies = on(permitted_client, "cat #{cookie_file}").stdout
        headers = on(permitted_client, "cat #{header_file}").stdout

        noko_alert_text = ''
        noko_alerts = doc.css("div[class='flash-alert']")
        if !noko_alerts.empty?
          noko_alert_text = noko_alerts.text.strip
        end
        expect(noko_alert_text).to_not match(/^Could not authenticate/)
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
### # Here is an example of how to grab a token under the new (10.0+ v4 API):
###
###require 'json'
###
###      oauth_json_pp= <<-PP
###        $pw = passgen( "simp_gitlab_${trusted['certname']}" )
###        $json = "{\\"grant_type\\": \\"password\\", \\"username\\": \\"root\\", \\"password\\": \\"${pw}\\"}"
###        file{ '/root/ouath_json.template':
###          content => $json
###        }
###      PP
###      apply_manifest_on(gitlab_server, oauth_json_pp, :catch_failures => true, :environment => env_vars)
###      _r = on(gitlab_server, "curl https://#{gitlab_server.node_name}/oauth/token --capath /etc/pki/simp-testing/pki/cacerts/ -d @/root/ouath_json.template  --header 'Content-Type: application/json' ")
###
###      expect(_r.exit_code_in? [0,2]).to be true
###      token_data = JSON.parse(_r.stdout)
