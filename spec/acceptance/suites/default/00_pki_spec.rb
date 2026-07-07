require 'spec_helper_acceptance'
require 'json'

test_name 'simp_gitlab pki tls connection'

describe 'simp_gitlab pki tls' do
  let(:hiera__vagrant) do
    {
      # enable vagrant access
      'sudo::user_specifications' => {
        'vagrant_all' => {
          'user_list' => ['vagrant'],
          'cmnd'      => ['ALL'],
          'passwd'    => false,
        },
      },
      'pam::access::users' => {
        'defaults' => {
          'origins'    => ['ALL'],
          'permission' => '+',
        },
        'vagrant' => nil,
      },
      'ssh::server::conf::permitrootlogin'    => true,
      'ssh::server::conf::authorizedkeysfile' => '.ssh/authorized_keys',
    }
  end

  let(:manifest__gitlab) do
    <<~EOS
      include 'svckill'
      include 'iptables'

      iptables::listen::tcp_stateful { 'ssh':
        dports       => 22,
        trusted_nets => ['any'],
      }

      class { 'simp_gitlab':
        trusted_nets            => [ #{ENV['TRUSTED_NETS'].to_s.split(%r{[,| ]}).map { |x| "\n#{' ' * 30}'#{x}'," }.join}
                                     '#{gitlab_server.get_ip}',
                                     '#{permitted_client.get_ip}',
                                     '127.0.0.1/32',
                                   ],
        pki                     => true,
        app_pki_external_source => '/etc/pki/simp-testing/pki',
        package_ensure          => '#{gitlab_ce_version}',
      }

      # allow vagrant access despite change in the default location of
      # authorized keys files that comes from SIMP's ssh module
      file { '/etc/ssh/local_keys/vagrant':
        ensure  => file,
        owner   => 'vagrant',
        group   => 'vagrant',
        source  => '/home/vagrant/.ssh/authorized_keys',
        mode    => '0644',
        seltype => 'sshd_key_t',
       }
    EOS
  end

  # workaround beaker issue in which FQDN is not properly set but Facter
  # thinks it is set
  context 'fix static host name' do
    hosts.each do |host|
      it "ensures static host name matches FQDN fact on #{host}" do
        fqdn = fact_on(host, 'fqdn')
        on(host, "hostnamectl set-hostname --static #{fqdn}")
      end
    end
  end

  context 'with PKI enabled but no firewall' do
    let(:hiera) do
      hiera = hiera__vagrant.dup
      # Genuinely manage no firewall. NOTE: `iptables::enable => false` does
      # NOT do this -- the iptables module only skips management when `enable`
      # is the string 'ignore'; `false` still *contains* iptables::service to
      # drive the service to a stopped/disabled state (and ship its
      # /etc/init.d/iptables SysV script). That "manage-to-off" path is dead on
      # systemd-only EL10 (no /etc/init.d, non-functional `redhat` provider),
      # so it errored the idempotency check. 'ignore' makes the class a true
      # no-op (no service, no init script) and, being inside the same guard,
      # never brings up firewalld either.
      hiera['iptables::enable'] = 'ignore'

      # Keep the standalone `iptables::listen::tcp_stateful { 'ssh' }` (added so
      # beaker can reconnect) on the raw path rather than the firewalld path --
      # this context deliberately runs no firewalld daemon. On EL10 the raw rule
      # is applied idempotently via iptables-nft.
      hiera['iptables::use_firewalld'] = false

      hiera
    end

    it 'sets hieradata so beaker can reconnect and no firewall is used' do
      hosts.each { |sut| set_hieradata_on(sut, hiera) }
    end

    it 'preps the test environment' do
      test_prep_manifest = <<~EOM
        # clean up Vagrant's leftovers
        class{ 'svckill': mode => 'enforcing' }
      EOM

      apply_manifest_on(gitlab_server, test_prep_manifest)
      on(gitlab_server, 'puppet resource service firewalld ensure=stopped')
    end

    it 'works with no errors' do
      # On slow servers, the gitlab-rails console may not come up in the
      # allotted time after a `gitlab-ctl reconfigure`. This means
      # `Exec[set_gitlab_root_password]` will fail. So may need to execute
      # `puppet apply` twice to get to a non-errored state.
      result = apply_manifest_on(gitlab_server, manifest__gitlab, acceptable_exit_codes: [0, 1, 2, 4, 6])

      unless [0, 2].include?(result.exit_code)
        # rubocop:disable RSpec/Output
        puts '>' * 80
        puts 'First `puppet apply` with gitlab install failed. Retrying...'
        puts '<' * 80
        # rubocop:enable RSpec/Output
        apply_manifest_on(gitlab_server, manifest__gitlab, catch_failures: true)
      end
    end

    it 'is idempotent' do
      apply_manifest_on(gitlab_server, manifest__gitlab, catch_changes: true)
      on(gitlab_server, 'rpm -q gitlab-ce')
    end

    it_behaves_like(
      'a GitLab web service',
      "https://#{gitlab_server_fqdn}/users/sign_in",
      firewall: false,
    )
  end

  context 'with PKI + firewall + custom port 777' do
    let(:hiera) do
      hiera = hiera__vagrant.dup

      # turn on firewalld (as a passthrough); the value of iptables::enable is
      # immaterial when this is true
      hiera['iptables::use_firewalld'] = true

      hiera
    end

    let(:new_lines) do
      '        firewall                => true,' + "\n" \
        '        tcp_listen_port         => 777,'
    end

    it 'sets hieradata so beaker can reconnect and firewalld is used' do
      hosts.each { |sut| set_hieradata_on(sut, hiera) }
    end

    it 'preps the test environment' do
      test_prep_manifest = <<~EOM
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

      apply_manifest_on(gitlab_server, test_prep_manifest)
    end

    it 'works with no errors' do
      new_manifest = manifest__gitlab.gsub(%r{(pki\s*=>\s*true),?}, "\\1,\n#{new_lines}\n")

      # Bringing firewalld up in the same run races `gitlab-ctl reconfigure`:
      # while firewalld reloads and moves the primary interface into the drop
      # zone, ohai briefly cannot detect the host IP and reconfigure aborts with
      # "Unable to determine node name", leaving gitlab on its previous config
      # (e.g. still on :443, not :777). `gitlab_reconfigure` is refreshonly and
      # subscribes to the gitlab.rb content, so a plain re-apply will NOT retry
      # it (gitlab.rb is now unchanged). Apply, then drive reconfigure directly,
      # retrying until firewalld has settled and it converges, then confirm the
      # catalog is otherwise clean.
      apply_manifest_on(gitlab_server, new_manifest, acceptable_exit_codes: [0, 1, 2, 4, 6])
      retry_on(gitlab_server, '/usr/bin/gitlab-ctl reconfigure', max_retries: 6, retry_interval: 15)
      apply_manifest_on(gitlab_server, new_manifest, catch_failures: true)
    end

    it 'is idempotent' do
      new_manifest = manifest__gitlab.gsub(%r{(pki\s*=>\s*true),?}, "\\1,\n#{new_lines}\n")
      apply_manifest_on(gitlab_server, new_manifest, catch_changes: true)
    end

    it_behaves_like(
      'a GitLab web service',
      "https://#{gitlab_server_fqdn}:777/users/sign_in",
      firewall: true,
    )
  end
end
