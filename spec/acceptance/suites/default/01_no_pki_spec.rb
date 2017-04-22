require 'spec_helper_acceptance'

test_name 'simp_gitlab class'

describe 'simp_gitlab class' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:client) {only_host_with_role( hosts, 'permittedclient' )}
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
        pki          => false
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

    it 'allow https connection on port 80' do
      shell 'sleep 90' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')
      result = on(client, "curl -L http://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)
    end
  end
end
