require 'spec_helper'

describe 'simp_gitlab' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_gitlab') }
    it { is_expected.to contain_class('simp_gitlab') }
    it { is_expected.to contain_class('gitlab') }

    # These resources are provided by the gitlab component module
    it { is_expected.to contain_service('gitlab-runsvdir') }
    it { is_expected.to contain_package('gitlab-ce').with_ensure('installed') }
  end


  [:permissive, :enforcing].each do |selinux_mode|
    context "when SELinux is `#{selinux_mode.to_s}`" do
      on_supported_os({
        :selinux_mode   => :permissive,
      }).each do |os, os_facts|
        context "on #{os}" do
          let(:facts){
            os_facts.merge({
            :gitlab_systemd => os_facts.fetch('init_systems',{}).include?('systemd'),
          })}

          context 'simp_gitlab class without any parameters' do
            let(:params) {{ }}
            it_behaves_like 'a structured module'
            it { is_expected.to contain_class('simp_gitlab').with_trusted_nets(['127.0.0.1/32']) }
          end

          context 'simp_gitlab class with firewall enabled' do
            let(:params) {{
              :trusted_nets    => ['10.0.2.0/24'],
              :tcp_listen_port => 1234,
              :firewall        => true,
            }}
            ###it_behaves_like "a structured module"
            it { is_expected.to create_iptables__listen__tcp_stateful('allow_gitlab_nginx_tcp').with_dports(1234)
            }
          end

          context 'simp_gitlab class with pki enabled' do
            let(:params) {{
              :pki => true,
            }}
            it { is_expected.to contain_class('gitlab').with_external_port(443) }
            it { is_expected.to contain_class('gitlab').with_external_url(/^https/) }
            it 'should contain correct nginx settings' do
              nginx = catalogue.resource('class','gitlab').send(:parameters)[:nginx]
              expect( nginx ).to include({
                'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
                'ssl_certificate'     => '/etc/pki/simp_apps/gitlab/x509/public/foo.example.com.pub',
                'ssl_certificate_key' => '/etc/pki/simp_apps/gitlab/x509/private/foo.example.com.pem',
                'ssl_ciphers'         => 'DEFAULT:!MEDIUM',
              })
              expect( nginx ).not_to include('ssl_verify_client'=> 'on')
            end
            it { is_expected.to contain_file('/etc/gitlab/nginx/conf.d/http_access_list.conf').with_content(/allow 127.0.0.1\/32;\n+\s+deny all;\n/)}

            context 'and 2-way validation' do
              let(:params) {{
                :pki                    => true,
                :two_way_ssl_validation => true,
                :app_pki_dir            => '/some/other/path',
              }}
              it { is_expected.to contain_class('gitlab').with_external_url(/^https/) }

              it 'should contain correct nginx settings' do
                nginx = catalogue.resource('class','gitlab').send(:parameters)[:nginx]
                expect( nginx ).to include({
                  'custom_nginx_config' => "include /etc/gitlab/nginx/conf.d/*.conf;\n",
                  'ssl_certificate'     => '/some/other/path/public/foo.example.com.pub',
                  'ssl_certificate_key' => '/some/other/path/private/foo.example.com.pem',
                  'ssl_verify_client'   => 'on',
                  'ssl_verify_depth'    => 2,
                })
              end
            end
          end

          context 'using alternate port 777' do
            let(:params) {{
              :pki             => true,
              :firewall        => true,
              :tcp_listen_port => 777,
              :ldap => true,
              :ldap_uri => [
                'ldaps://ldapserver1.example.com',
                'ldaps://ldapserver2.example.com',
                'ldap://ldapserver3.example.com',
              ],
              :ldap_base_dn => 'dc=bar,dc=baz',
              :ldap_bind_dn => 'cn=hostAuth,ou=Hosts,dc=bar,dc=baz',
              :ldap_bind_pw => 's00per sekr3t!',
              :ldap_active_directory => false,
            }}
            it { is_expected.to create_iptables__listen__tcp_stateful('allow_gitlab_nginx_tcp').with_dports(777) }
            it { is_expected.to contain_class('gitlab').with_external_url(%r(^https://[^/]+?:777(/?.*)?))}
          end
        end
      end
    end
  end

  context 'unsupported operating system' do
    describe 'simp_gitlab class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :osfamily        => 'Solaris',
        :operatingsystem => 'Nexenta',
      }}

      it { expect { is_expected.to contain_package('simp_gitlab') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
