require 'spec_helper_acceptance'

test_name 'simp_gitlab pki tls with firewall connection'

describe 'simp_gitlab pki tls with firewall' do

  let(:server) {only_host_with_role( hosts, 'server' )}
  let(:client) {only_host_with_role( hosts, 'client' )}
  let(:pupenv) {{'PUPPET_EXTRA_OPTS' => '--logdest /var/log/puppetlabs/puppet/beaker.log'}}
  let(:manifest) do
    <<-EOS
      class { 'simp_gitlab':
        pki                     => true,
        firewall                => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
      }
    EOS
  end
  let(:curl_ssl_cmd ) do
    client = only_host_with_role( hosts, 'client' )
    fqdn   = fact_on(client, 'fqdn')
    'curl  --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
         " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
         " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
  end

  context 'with PKI + firewall enabled' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest_on(server, manifest, :catch_failures => true, :environment => pupenv)
    end

    it 'should be idempotent' do
      apply_manifest_on(server, manifest, :catch_changes => true, :environment => pupenv)
    end

    it 'allows https connection on port 443' do
      shell 'sleep 90' # give it some time to start up
      fqdn = fact_on(server, 'fqdn')
      result = on(client, "#{curl_ssl_cmd} -L https://#{fqdn}/users/sign_in" )
      expect(result.stdout).to match(/GitLab|password/)
    end
  end
end
