require 'spec_helper'

describe 'simp_gitlab' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_gitlab') }
    it { is_expected.to contain_class('simp_gitlab') }
    it { is_expected.to contain_class('gitlab') }
###    it { is_expected.to contain_class('simp_gitlab::install').that_comes_before('Class[simp_gitlab::config]') }
###    it { is_expected.to contain_class('simp_gitlab::config') }
###    it { is_expected.to contain_class('simp_gitlab::service').that_subscribes_to('Class[simp_gitlab::config]') }
###
###    it { is_expected.to contain_service('simp_gitlab') }
###    it { is_expected.to contain_package('simp_gitlab').with_ensure('present') }
  end


  context 'supported operating systems' do
    on_supported_os({
      :selinux_mode   => :permissive,
    }).each do |os, os_facts|
      context "on #{os}" do
        let(:facts){
          os_facts.merge({
          :gitlab_systemd => os_facts.fetch('init_systems',{}).include?('systemd'),
        })}

        context "simp_gitlab class without any parameters" do
          let(:params) {{ }}
          it_behaves_like "a structured module"
          it { is_expected.to contain_class('simp_gitlab').with_trusted_nets(['127.0.0.1/32']) }
        end

        context "simp_gitlab class with firewall enabled" do
          let(:params) {{
            :trusted_nets    => ['10.0.2.0/24'],
            :tcp_listen_port => 1234,
            :firewall        => true,
          }}
          ###it_behaves_like "a structured module"
          it { is_expected.to create_iptables__listen__tcp_stateful('allow_simp_gitlab_tcp_connections').with_dports(1234)
          }
        end

        context "simp_gitlab class with pki enabled" do
          let(:params) {{
            :pki => true,
          }}
          it { is_expected.to contain_class('gitlab').with_external_port(443) }
          it { is_expected.to contain_class('gitlab').with_external_url(/^https/) }
          it { is_expected.to contain_class('gitlab').with_nginx({
            "ssl_certificate"        => "/etc/pki/simp_apps/gitlab/x509/public/foo.example.com.pub",
            "ssl_certificate_key"    => "/etc/pki/simp_apps/gitlab/x509/private/foo.example.com.pem",
            "redirect_http_to_https" => true
          })}

          context 'and 2-way validation' do
            let(:params) {{
              :pki                    => true,
              :two_way_ssl_validation => true,
              :app_pki_dir            => '/some/other/path',
            }}
            it { is_expected.to contain_class('gitlab').with_external_port(443) }
            it { is_expected.to contain_class('gitlab').with_external_url(/^https/) }
            it { is_expected.to contain_class('gitlab').with_nginx({
              "ssl_verify_client"      => "on",
              "ssl_verify_depth"       => 2,
              "ssl_certificate"        => "/some/other/path/public/foo.example.com.pub",
              "ssl_certificate_key"    => "/some/other/path/private/foo.example.com.pem",
              "redirect_http_to_https" => true,
            })}
          end
        end

###
###        context "simp_gitlab class with auditing enabled" do
###          let(:params) {{
###            :enable_auditing => true,
###          }}
###          ###it_behaves_like "a structured module"
###          it { is_expected.to contain_class('simp_gitlab::config::auditing') }
###          it { is_expected.to contain_class('simp_gitlab::config::auditing').that_comes_before('Class[simp_gitlab::service]') }
###          it { is_expected.to create_notify('FIXME: auditing') }
###        end
###
###        context "simp_gitlab class with logging enabled" do
###          let(:params) {{
###            :enable_logging => true,
###          }}
###          ###it_behaves_like "a structured module"
###          it { is_expected.to contain_class('simp_gitlab::config::logging') }
###          it { is_expected.to contain_class('simp_gitlab::config::logging').that_comes_before('Class[simp_gitlab::service]') }
###          it { is_expected.to create_notify('FIXME: logging') }
      end
    end
  end

  on_supported_os({
    :selinux_mode   => :enforcing,
  }).each do |os, os_facts|
    context "simp_gitlab class with selinux enabled" do
      let(:facts){
        os_facts.merge({
        :gitlab_systemd => os_facts.fetch('init_systems',{}).include?('systemd'),
      })}
      let(:params) {{ :enable_selinux => true }}

      ### it_behaves_like "a structured module"
      ### it { is_expected.to contain_class('simp_gitlab').with_trusted_nets(['127.0.0.1/32']) }

      skip('FIXME: verify selinux works (see ##://docs.gitlab.com/omnibus/common_installation_problems/README.html#git-user-does-not-have-ssh-access')
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
