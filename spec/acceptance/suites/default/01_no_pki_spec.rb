require 'spec_helper_acceptance'

test_name 'simp_gitlab class'

describe 'simp_gitlab class' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:permitted_client) {only_host_with_role( hosts, 'permittedclient' )}
  let(:denied_client) {only_host_with_role( hosts, 'unknownclient' )}
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
        pki          => false,
        firewall     => true,
      }
    EOS
  end

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest_on(server, manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest_on(server, manifest, :catch_changes => true)
    end

    it 'allows http connection on port 80' do
      shell 'sleep 90' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')
      result = on(permitted_client, "curl -L http://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)
    end
    it 'allows http connection on port 80 from permitted clients' do
      shell 'sleep 30' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')

      # retry on first connection in case it still needs more time
      result = on(server, "curl --retry 3 --retry-delay 15 -L http://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      result = on(permitted_client, "curl -L http://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)

      # We are testing with firewall enabled, so we expect curl to fail
      #
      #  Curl exit codes:
      #
      #    7  = Failed connect to #{fqdn}
      #    28 =  Connection timed out
      #
      #  Both exit codes have been encountered during testing, and I think it
      #  depends on the whether the host system's network stack has been locked
      #  down (ala SIMP) or not.

      result = on(denied_client, "curl -L http://#{fqdn}:777/users/sign_in", :acceptable_exit_codes => [7,28])
    end
  end
end
