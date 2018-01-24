require 'beaker-rspec'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers
require 'tmpdir'
require 'pry' if ENV['PRY'] == 'yes'

_path = File.expand_path('../acceptance/support/lib',__FILE__)
$LOAD_PATH.unshift(_path)

fail "supportlib path '#{_path}' doesn't exist!" unless File.directory?(_path)

require 'simp_gitlab_beaker_helpers'

shared_examples_for 'a GitLab web service' do |gitlab_signin_url, options|
  it "serves GitLab web content to local client" do
    # give the web interface time to start
    shell 'sleep 30'
    result = on(
      gitlab_server,
      "#{curl_ssl_cmd(gitlab_server)} --retry 6 --retry-delay 15 -L " +
      gitlab_signin_url
    )
    expect(result.stdout).to match(/GitLab|password/)
  end

  it "permits web access from permitted clients}"  do
    result = on(
      permitted_client,
      "#{curl_ssl_cmd(permitted_client)} -L #{gitlab_signin_url}"
    )
    expect(result.stdout).to match(/GitLab|password/)
  end

  it "denies web access from unknown clients" do
    _curl_cmd = "#{curl_ssl_cmd(denied_client)} -L #{gitlab_signin_url}"
    if options.fetch(:firewall, true) == true
      # When the server's firewall is enabled, we expect curl to *fail*
      #
      #  Curl exit codes:
      #
      #    7  = Failed connect to #{fqdn}
      #    28 =  Connection timed out
      #
      #  Both exit codes have been encountered during testing, and I think it
      #  depends on the whether the host system's network stack has been locked
      #  down (ala SIMP) or not.
      result = on( denied_client, _curl_cmd, acceptable_exit_codes: [7,28])
    else
      # Without a firewall, the web server should respond with a 403
      result = on( denied_client, _curl_cmd )
      expect(result.stdout).to match(/403 Forbidden/)
    end
  end
end

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


# helper to build up curl command strings
def curl_ssl_cmd( host )
  fqdn   = fact_on(host, 'fqdn')
  'curl  --connect-timeout 30' +
       ' --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
       " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
       " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
end


RSpec.configure do |c|
  # provide SUT variables to individual examples AND example groups
  c.include SimpGitlabBeakerHelpers::SutVariables
  c.extend SimpGitlabBeakerHelpers::SutVariables

  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Install modules and dependencies from spec/fixtures/modules
      copy_fixture_modules_to( hosts )

      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on( default, hosts, cert_dir )
        hosts.each{ |sut| copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )}
      end

    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end

