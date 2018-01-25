require 'helpers/curl_ssl_cmd'

shared_examples_for 'a GitLab web service' do |gitlab_signin_url, options|
  it "serves GitLab web content to local client" do
    # give the web interface time to start
    shell 'sleep 30'
    result = on(
      gitlab_server,
      "#{curl_ssl_cmd(gitlab_server)} --retry 6 --retry-delay 15 -L " +
      (gitlab_signin_url || "https://#{gitlab_server_fqdn}/users/sign_in")
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

