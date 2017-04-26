require 'spec_helper_acceptance'

test_name 'simp_gitlab pki tls with firewall connection'

describe 'simp_gitlab pki tls with firewall' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:permitted_client) {only_host_with_role( hosts, 'permittedclient' )}
  let(:denied_client) {only_host_with_role( hosts, 'unknownclient' )}
  let(:env_vars){{ 'GITLAB_ROOT_PASSWORD' => 'yourpassword' }}

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
        pki          => true,
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
    end

    it 'should work with no errors' do
      no_firewall_manifest = manifest.sub(/include 'iptables'/,"class {'iptables': enable => false }")
      apply_manifest_on(server, no_firewall_manifest, :catch_failures => true, :environment => env_vars)

      # FIXME: post fix creates the same files twice; why?
      apply_manifest_on(server, no_firewall_manifest, :catch_failures => true, :environment => env_vars)
    end

    it 'should be idempotent' do
      no_firewall_manifest = manifest.sub(/include 'iptables'/,"class {'iptables': enable => false }")
      apply_manifest_on(server, no_firewall_manifest, :catch_changes => true, :environment => env_vars)
    end

    it 'allows https connection on port 443 from permitted clients' do
      shell 'sleep 30' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')

      # retry on first connection in case it still needs more time
      result = on(server, "#{curl_ssl_cmd(server)} --retry 3 --retry-delay 15 -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(denied_client, "#{curl_ssl_cmd(denied_client)} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/403 Forbidden/)
    end
  end


  context 'with PKI + firewall + custom port 777' do
    let(:new_lines) do
      '        firewall                => true,' + "\n" +
      '        tcp_listen_port         => 777,'
    end

    it 'should prep the test enviornment' do
      test_prep_manifest = <<-EOM
      # Turns off firewalld in EL7.  Presumably this would already be done.
      include 'iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }

      class{ 'svckill': mode => 'enforcing' }
      EOM
      apply_manifest_on(server,  test_prep_manifest, :environment => :env_vars)
    end

    it 'should work with no errors' do
      new_manifest = manifest.gsub(%r[pki\s*=>\s*true,], "\\0\n#{new_lines}\n")
      apply_manifest_on(server, new_manifest, :catch_failures => true,  :environment => env_vars)
    end

    it 'should be idempotent' do
      new_manifest = manifest.gsub(%r[pki\s*=>\s*true,], "\\0\n#{new_lines}\n")
      apply_manifest_on(server, new_manifest, :catch_changes => true, :environment => env_vars)
    end

    it 'allows https connection on port 777 from permitted clients' do
      fqdn = fact_on(server, 'fqdn')
      result = on(server, "#{curl_ssl_cmd(server)} -L https://#{fqdn}:777/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "#{curl_ssl_cmd(permitted_client)} -L https://#{fqdn}:777/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(denied_client, "#{curl_ssl_cmd(denied_client)} -L https://#{fqdn}:777/users/sign_in" )
      expect(result.stderr).to match(/Failed connect to #{fqdn}/)
    end
  end

end
