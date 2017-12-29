require 'spec_helper_acceptance'

test_name 'simp_gitlab ldap tls'

describe 'simp_gitlab using ldap over tls' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:ldap_server) {only_host_with_role( hosts, 'ldapserver' )}
  let(:permitted_client) {only_host_with_role( hosts, 'permittedclient' )}
  let(:denied_client) {only_host_with_role( hosts, 'unknownclient' )}
  let(:env_vars){{ 'GITLAB_ROOT_PASSWORD' => 'yourpassword' }}

  let(:ldap_server_manifest) do
    <<-EOS_LDAP
      class{'simp_openldap':
        is_server => true,
      }
      #include 'simp::server::ldap'
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

  # helper to build up curl command strings
  def curl_ssl_cmd( host )
    fqdn   = fact_on(host, 'fqdn')
    'curl  --connect-timeout 30'+
         ' --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
         " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
         " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
  end

  context 'with PKI enabled' do
    it 'should prep the test enviornment' do
      test_prep_manifest = <<-EOM
      # clean up Vagrant's dingleberries
      class{ 'svckill': mode => 'enforcing' }
      EOM
      apply_manifest_on(server,  test_prep_manifest)

      # Determine what your domain is, in dn form
      _domains = fact_on(server, 'domain').split('.')
      _domains.map! { |d| "dc=#{d}" }
      domains = _domains.join(',')

      # Add users and groups to LDAP
      files_dir      = File.expand_path('../files', __FILE__)
      ldif_file      = File.expand_path('ldap_test_user.ldif',files_dir)
      hieradata_file = File.expand_path('ldap_tls_default.yaml',files_dir)

      ldif_text      = File.read(ldif_file)
                         .gsub('LDAP_BASE_DN',domains)
      create_remote_file(ldap_server, '/root/user_ldif.ldif', ldif_text)

      ldap_server_hieradata = File.read(hieradata_file)
                                .gsub('LDAP_BASE_DN',domains)
                                .gsub('LDAP_URI', ldap_server.node_name )
      # share trusted_nets, etc
      set_hieradata_on(hosts, ldap_server_hieradata, 'default')

      apply_manifest_on(ldap_server, ldap_server_manifest)
    end


    it 'should work with no errors' do
      apply_manifest_on(server, manifest, :catch_failures => true, :environment => env_vars)

      # FIXME: postfix creates the same files twice... is this an ordering issue?
      apply_manifest_on(server, manifest, :catch_failures => true, :environment => env_vars)
    end

    it 'should be idempotent' do
      apply_manifest_on(server, manifest, :catch_changes => true, :environment => env_vars)
    end

    it 'allows https connection on port 443 from permitted clients' do
      shell 'sleep 30' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')

      # retry on first connection in case it still needs more time
      result = on(server, "#{curl_ssl_cmd(server)} --retry 3 --retry-delay 30 -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)
    end

    it 'authenticates via StartTLS-encrypted LDAP' do
require 'pry'; binding.pry
    end
  end


end
