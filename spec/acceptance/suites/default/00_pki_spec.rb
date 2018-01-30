require 'spec_helper_acceptance'

test_name 'simp_gitlab pki tls with firewall connection'

describe 'simp_gitlab pki tls with firewall' do
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
        pki                     => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
      }
    EOS
  end

  context 'with PKI enabled' do
    it 'should prep the test environment' do
      test_prep_manifest = <<-EOM
      # clean up Vagrant's leftovers
      class{ 'svckill': mode => 'enforcing' }
      EOM
      apply_manifest_on(gitlab_server, test_prep_manifest)
    end

    it 'should work with no errors' do
      no_firewall_manifest = manifest__gitlab.sub(
        /include 'iptables'/,
        "class {'iptables': enable => false }"
      )
      apply_manifest_on(gitlab_server, no_firewall_manifest, catch_failures: true)

      # FIXME: postfix creates the same files twice; why?
      apply_manifest_on(gitlab_server, no_firewall_manifest, catch_failures: true)
    end

    it 'should be idempotent' do
      no_firewall_manifest = manifest__gitlab.sub(
        /include 'iptables'/,
        "class {'iptables': enable => false }"
      )
      apply_manifest_on(gitlab_server, no_firewall_manifest, catch_changes: true)
    end

    it_behaves_like(
      'a GitLab web service',
      "https://#{gitlab_server_fqdn}/users/sign_in",
      firewall: false
    )
  end


  context 'with PKI + firewall + custom port 777' do
    let(:new_lines) do
      '        firewall                => true,' + "\n" +
      '        tcp_listen_port         => 777,'
    end

    it 'should prep the test environment' do
      test_prep_manifest = <<-EOM
      # Turns off firewalld in EL7.  Presumably this would already be done.
      include 'iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }

      class{ 'svckill':
        mode   => 'enforcing',
        # Keep Gitlab installed and running from the last test
        ignore => ['gitlab-runsvdir', 'gitlab-runsvdir.service'],
      }
      EOM
      apply_manifest_on(gitlab_server,  test_prep_manifest)
    end

    it 'should work with no errors' do
      new_manifest = manifest__gitlab.gsub(%r[(pki\s*=>\s*true),?], "\\1,\n#{new_lines}\n")
      apply_manifest_on(gitlab_server, new_manifest, catch_failures: true)
    end

    it 'should be idempotent' do
      new_manifest = manifest__gitlab.gsub(%r[(pki\s*=>\s*true),?], "\\1,\n#{new_lines}\n")
      apply_manifest_on(gitlab_server, new_manifest, catch_changes: true)
    end

    it_behaves_like(
      'a GitLab web service',
      "https://#{gitlab_server_fqdn}:777/users/sign_in",
      firewall: true
    )
  end

end
