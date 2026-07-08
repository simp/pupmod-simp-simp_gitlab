require 'beaker-rspec'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

require 'tmpdir'
require 'pry' if ENV['PRY'] == 'yes'

$LOAD_PATH.unshift(File.expand_path('../acceptance/support', __FILE__))

require 'helpers/simp_gitlab_beaker_helpers'
require 'helpers/curl_ssl_cmd'
require 'shared_examples/gitlab_web_service'

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end

RSpec.configure do |c|
  # provide SUT variables to individual examples AND example groups
  c.include SimpGitlabBeakerHelpers::SutVariables
  c.extend SimpGitlabBeakerHelpers::SutVariables

  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Detect cases in which no examples are executed (e.g., nodeset does not
  # have hosts with required roles)
  c.fail_if_no_examples = true

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install modules and dependencies from spec/fixtures/modules
    copy_fixture_modules_to(hosts)

    # Ensure firewalld is present before the first Puppet run. simp_firewalld
    # only manages firewalld when the `simplib__firewalls` fact already reports
    # `firewall-cmd` on PATH, and it never installs the package itself -- a
    # chicken-and-egg that no-ops the whole firewall stack on images that don't
    # ship firewalld preinstalled (minimal EL9/EL10), which then falls back to
    # the iptables SysV service (non-functional on systemd-only EL10). Once the
    # package is present the fact resolves and the SIMP stack engages. It is a
    # no-op where firewalld is already installed.
    #
    # `--disablerepo=epel*`: firewalld and its deps live in BaseOS/AppStream, so
    # EPEL is not needed here -- and loading EPEL's metadata pushes dnf's memory
    # use past the 1 GB client nodes, OOM-killing the install.
    # See https://github.com/simp/pupmod-simp-simp_firewalld/issues/102
    apply_manifest_on(
      hosts,
      "package { 'firewalld': ensure => installed, install_options => ['--disablerepo=epel*'] }",
      catch_failures: true,
    )

    # Generate and install PKI certificates on each SUT
    Dir.mktmpdir do |cert_dir|
      run_fake_pki_ca_on(default, hosts, cert_dir)
      hosts.each { |sut| copy_pki_to(sut, cert_dir, '/etc/pki/simp-testing') }
    end
  rescue StandardError, ScriptError => e
    # rubocop:disable Lint/Debugger
    raise e unless ENV['PRY']
    require 'pry'
    binding.pry
    # rubocop:enable Lint/Debugger
  end
end
