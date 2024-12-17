require 'spec_helper_acceptance'

test_name 'simp_gitlab connection with firewall but without pki'

describe 'simp_gitlab firewall without pki' do
  let(:hiera) do
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

      # turn on firewalld (as a passthrough); the value of iptables::enable is
      # immaterial when this is true
      'iptables::use_firewalld'               => true,
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
        trusted_nets   => [ #{ENV['TRUSTED_NETS'].to_s.split(%r{[,| ]}).map { |x| "\n#{' ' * 21}'#{x}'," }.join}
                            '#{gitlab_server.get_ip}',
                            '#{permitted_client.get_ip}',
                            '127.0.0.1/32',
                          ],
        pki            => false,
        firewall       => true,
        package_ensure => '#{gitlab_ce_version}',
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

  context 'with firewall only' do
    it 'sets hieradata so beaker can reconnect and firewalld is used' do
      hosts.each { |sut| set_hieradata_on(sut, hiera) }
    end

    it 'works with no errors' do
      apply_manifest_on(gitlab_server, manifest__gitlab, catch_failures: true)
    end

    it 'is idempotent' do
      apply_manifest_on(gitlab_server, manifest__gitlab, catch_changes: true)
    end

    it_behaves_like(
      'a GitLab web service',
      "http://#{gitlab_server_fqdn}/users/sign_in",
      firewall: true,
    )
  end
end
