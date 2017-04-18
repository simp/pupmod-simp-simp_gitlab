require 'spec_helper_acceptance'

test_name 'simp_gitlab class'

describe 'simp_gitlab class' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:client) {only_host_with_role( hosts, 'client' )}
  let(:pupenv) {{'PUPPET_EXTRA_OPTS' => '--logdest /var/log/puppetlabs/puppet/beaker.log'}}
  let(:manifest) do
    <<-EOS
      class { 'simp_gitlab': }
    EOS
  end

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest_on(server, manifest, :catch_failures => true, :environment => pupenv)
    end

    it 'should be idempotent' do
      apply_manifest_on(server, manifest, :catch_changes => true, :environment => pupenv)
    end

    it 'allow https connection on port 80' do
      shell 'sleep 90' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')
      result = on(client, "curl -L http://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)
    end
  end
end
