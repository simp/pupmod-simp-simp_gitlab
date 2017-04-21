require 'spec_helper_acceptance'

test_name 'simp_gitlab pki tls with firewall connection'

describe 'simp_gitlab pki tls with firewall' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:permitted_client) {only_host_with_role( hosts, 'permittedclient' )}
  let(:denied_client) {only_host_with_role( hosts, 'unknownclient' )}

  let(:manifest) do
    <<-EOS
      include 'svckill'
      class { 'simp_gitlab':
        trusted_nets => [
                          '10.0.0.0/8',
                          '192.168.21.21',
                          '192.168.21.22',
                          '127.0.0.1/32',
                        ],
        pki          => true,
        firewall     => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
      }
    EOS
  end

  # helper to build up curl command strings
  def curl_ssl_cmd( host )
    fqdn   = fact_on(host, 'fqdn')
    'curl  --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
         " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
         " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
  end


  before :all do
    hosts.add_env_var('PUPPET_EXTRA_OPTS', '--logdest /var/log/puppetlabs/puppet/beaker.log')
    apply_manifest_on(server, "class{ 'svckill': mode => 'enforcing' }")
  end

  context 'with PKI + firewall enabled' do
    it 'should work with no errors' do
      apply_manifest_on(server, manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server, manifest, :catch_changes => true)
    end

    it 'allows https connection on port 443 from permitted clients' do
      shell 'sleep 30' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')

      result = on(server, "#{curl_ssl_cmd(server)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(denied_client, "#{curl_ssl_cmd(denied_client)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/403 Forbidden/)
    end
  end


  context 'with PKI + custom port 777' do

    it 'should work with no errors' do
      new_lines = '        tcp_listen_port         => 777,'
      new_manifest = manifest.gsub(%r[^\ *}], "\n#{new_lines}\n\}")
      apply_manifest_on(server, new_manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      new_lines = '        tcp_listen_port         => 777,'
      new_manifest = manifest.gsub(%r[^\ *}], "\n#{new_lines}\n\}")
      apply_manifest_on(server, manifest, :catch_changes => true)
    end

    it 'allows https connection on port 777 from permitted clients' do
      shell 'sleep 30' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')
      result = on(server, "#{curl_ssl_cmd(server)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}:777/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(denied_client, "#{curl_ssl_cmd(denied_client)} -L https://#{fqdn}:777/users/sign_in" )
      expect(result.stdout).to match(/403 Forbidden/)
    end

  end
end
