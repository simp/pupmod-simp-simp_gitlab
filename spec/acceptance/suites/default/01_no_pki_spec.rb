require 'spec_helper_acceptance'

test_name 'simp_gitlab class'

describe 'simp_gitlab class' do

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
        pki      => false,
        firewall => true,
      }
    EOS
  end

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest_on(gitlab_server, manifest__gitlab, catch_failures: true)
    end

    it 'should be idempotent' do
      apply_manifest_on(gitlab_server, manifest__gitlab, catch_changes: true)
    end

    it_behaves_like(
      'a GitLab web service',
      "http://#{gitlab_server_fqdn}/users/sign_in",
      firewall: true
    )
  end
end
