require 'spec_helper'

describe 'simp_gitlab' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:pre_condition) { "function simplib::passgen(String $name) { 'generated_password' }" }

      context 'FIPS mode disabled' do
        let(:facts) do
          facts = os_facts.dup
          facts['fips_enabled'] = false
          facts
        end

        context 'with default parameters' do
          let(:params) { {} }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('simp_gitlab').with_trusted_nets(['127.0.0.1/32']) }
          it { is_expected.to contain_class('postfix') }
          it { is_expected.to contain_class('chrony') }
          it { is_expected.to contain_class('ssh') }
          it { is_expected.to contain_file('/etc/gitlab/nginx').with_ensure('directory') }
          it { is_expected.to contain_file('/etc/gitlab/nginx/conf.d').with_ensure('directory') }
          it {
            is_expected.to contain_file('/etc/gitlab/nginx/conf.d/http_access_list.conf')
              .with_content(<<~EOM)
                # This file is managed by Puppet(module 'simp_gitlab')

                    allow 127.0.0.1/32;

                    deny all;

                    # See:
                    #   - https://gitlab.com/gitlab-org/gitlab-ce/issues/27607
                    # proxy_pass http://gitlab-workhorse;
              EOM
          }

          it {
            is_expected.to contain_sshd_config('AuthorizedKeysFile GitLab user').with(
              ensure: 'present',
              key: 'AuthorizedKeysFile',
              condition: 'User git',
              value: '/var/opt/gitlab/.ssh/authorized_keys',
            )
          }

          it {
            is_expected.to contain_class('gitlab').with(
              manage_package: true,
              manage_upstream_edition: 'ce',
              package_ensure: 'installed',
              external_url: 'http://foo.example.com:80',
              nginx: {
                'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
              },
              gitlab_rails: {
                'initial_root_password' => 'temp_generated_password',
                'usage_ping_enabled'    => false,
              },
              shell: {
                'auth_file' => '/var/opt/gitlab/.ssh/authorized_keys',
              },
              mattermost: { 'enable' => false },
              mattermost_nginx: { 'enable' => false },
              prometheus: { 'enable' => false },
              gitlab_exporter: { 'enable' => false },
              node_exporter: { 'enable' => false },
              redis_exporter: { 'enable' => false },
              postgres_exporter: { 'enable' => false },
              letsencrypt: { 'enable' => false },
            )
          }

          it { is_expected.to contain_svckill__ignore('gitlab-runsvdir') }
          it {
            is_expected.to contain_pam__access__rule('Allow GitLab git users via ssh').with(
              users: [ 'git' ],
              origins: [ 'LOCAL' ],
            )
          }

          it { is_expected.to contain_file('/usr/local/sbin/change_gitlab_root_password') }
          it {
            is_expected.to contain_exec('set_gitlab_root_password')
              .with_command('/usr/local/sbin/change_gitlab_root_password -t 300 generated_password')
              .with_timeout(360)
          }

          it { is_expected.not_to contain_class('simp_gitlab::config::pki') }
          it { is_expected.not_to contain_class('simp_gitlab::config::firewall') }
        end

        context 'simp_gitlab class with firewall enabled' do
          let(:params) do
            {
              trusted_nets: ['10.0.2.0/24'],
              tcp_listen_port: 1234,
              firewall: true,
            }
          end

          it {
            is_expected.to create_iptables__listen__tcp_stateful('allow_gitlab_nginx_tcp')
              .with_trusted_nets([ '10.0.2.0/24' ])
              .with_dports(1234)
          }

          it {
            is_expected.to contain_pam__access__rule('Allow GitLab git users via ssh').with(
              users: [ 'git' ],
              origins: [ '10.0.2.0/24' ],
            )
          }
        end

        context 'simp_gitlab class with pki enabled' do
          let(:params) do
            {
              pki: true,
            }
          end

          it { is_expected.to contain_pki__copy('gitlab') }
          it {
            is_expected.to contain_pki_cert_sync('/etc/gitlab/trusted-certs').with(
              purge: true,
              generate_pem_hash_links: false,
            )
          }
          it { is_expected.to contain_class('gitlab').with_external_url(%r{^https}) }
          it 'contains correct nginx settings' do
            nginx = catalogue.resource('class', 'gitlab').send(:parameters)[:nginx]
            expect(nginx).to include(
              'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
              'ssl_certificate'     => '/etc/pki/simp_apps/gitlab/x509/public/foo.example.com.pub',
              'ssl_certificate_key' => '/etc/pki/simp_apps/gitlab/x509/private/foo.example.com.pem',
              'ssl_ciphers'         => 'DEFAULT:!MEDIUM',
              'ssl_protocols'       => 'TLSv1.2',
            )
            expect(nginx).not_to include('ssl_verify_client' => 'on')
          end
          it { is_expected.to contain_file('/etc/gitlab/nginx/conf.d/http_access_list.conf').with_content(%r{allow 127.0.0.1/32;\n+\s+deny all;\n}) }

          context 'and 2-way validation' do
            let(:params) do
              {
                pki: true,
                two_way_ssl_validation: true,
                app_pki_dir: '/some/other/path',
              }
            end

            it { is_expected.to contain_class('gitlab').with_external_url(%r{^https}) }

            it 'contains correct nginx settings' do
              nginx = catalogue.resource('class', 'gitlab').send(:parameters)[:nginx]
              expect(nginx).to include(
                'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
                'ssl_certificate'     => '/some/other/path/public/foo.example.com.pub',
                'ssl_certificate_key' => '/some/other/path/private/foo.example.com.pem',
                'ssl_verify_client'   => 'on',
                'ssl_verify_depth'    => 2,
              )
            end
          end

          context 'and using alternate web server port 777' do
            let(:params) do
              {
                pki: true,
                firewall: true,
                tcp_listen_port: 777,
              }
            end

            it { is_expected.to create_iptables__listen__tcp_stateful('allow_gitlab_nginx_tcp').with_dports(777) }
            it { is_expected.to contain_class('gitlab').with_external_url(%r{^https://[^/]+?:777(/?.*)?}) }
          end
        end

        context 'simp_gitlab class using multiple LDAP servers (NOTE: ee only)' do
          let(:params) do
            {
              ldap: true,
              ldap_uri: [
                'ldaps://ldapserver1.example.com',
                'ldaps://ldapserver2.example.com',
                'ldap://ldapserver3.example.com',
              ],
              ldap_base_dn: 'dc=bar,dc=baz',
              ldap_bind_dn: 'cn=hostAuth,ou=Hosts,dc=bar,dc=baz',
              ldap_bind_pw: 's00per sekr3t!',
              ldap_active_directory: false,
            }
          end

          it 'contains correct LDAP settings' do
            gitlab_rails = catalogue.resource('class', 'gitlab').send(:parameters)[:gitlab_rails]
            expect(gitlab_rails).to include('ldap_enabled' => true)
            expect(gitlab_rails['ldap_servers'].size).to eq 3
            expect(gitlab_rails['ldap_servers'].first.last).to include('base'  => 'dc=bar,dc=baz')
            expect(gitlab_rails['ldap_servers'].first.last).to include('label' => 'LDAP')
          end

          it 'mangles LDAP server names into valid and unique provider IDs' do
            gitlab_rails = catalogue.resource('class', 'gitlab').send(:parameters)[:gitlab_rails]
            expect(gitlab_rails['ldap_servers'].keys.sort).to eql [
              'ldapsldapserver1examplecom',
              'ldapsldapserver2examplecom',
              'ldapldapserver3examplecom',
            ].sort
          end
        end

        context 'with gitlab_options set' do
          context 'with additional settings only' do
            let(:params) do
              {
                gitlab_options: {
                  'manage_omnibus_repository' => false,
                  'nginx'                     => {
                    'client_max_body_size' => '300m',
                  },
                },
              }
            end

            it {
              is_expected.to contain_class('gitlab')
                .with_manage_omnibus_repository(false)
                .with_nginx(
                  'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
                  'client_max_body_size' => '300m',
                )
            }
          end

          context 'with overrides of SIMP settings' do
            let(:params) do
              {
                gitlab_options: {
                  'mattermost' => {
                    'enable'         => 'true',
                    'team_site_name' => 'My GitLab Matters the Most',
                  },
                },
              }
            end

            it {
              is_expected.to contain_class('gitlab').with_mattermost(
                'enable'         => 'true',
                'team_site_name' => 'My GitLab Matters the Most',
              )
            }
          end

          context "with letsencrypt = true override and pki = 'simp'" do
            let(:params) do
              {
                gitlab_options: { 'letsencrypt' => { 'enable' => 'true' } },
                pki: 'simp',
              }
            end

            it {
              is_expected.to contain_file('/etc/pki/simp_apps/gitlab/x509/public')
                .with_mode('0644')
            }
          end
        end
      end

      context 'FIPS mode disabled' do
        let(:facts) do
          facts = os_facts.dup
          facts['fips_enabled'] = true
          facts
        end

        context 'with default parameters' do
          let(:params) { {} }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('simp_gitlab').with_trusted_nets(['127.0.0.1/32']) }
        end

        context 'with allow_fips=false' do
          let(:params) { { allow_fips: false } }

          it { is_expected.not_to compile.with_all_deps }
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'simp_gitlab class without any parameters on Solaris/Nexenta' do
      let(:facts) do
        {
          osfamily: 'Solaris',
          operatingsystem: 'Nexenta',
        }
      end

      it { is_expected.not_to compile }
    end
  end
end
