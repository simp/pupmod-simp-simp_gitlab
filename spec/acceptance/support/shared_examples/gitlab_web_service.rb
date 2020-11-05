require 'helpers/curl_ssl_cmd'

shared_examples_for 'a GitLab web service' do |gitlab_signin_url, options|
  it 'serves GitLab web content to local client' do
    _sleep   = ENV['BEAKER_gitlab_sleep'] || options.fetch(:gitlab_sleep, 30)
    _retries = ENV['BEAKER_gitlab_retries'] || options.fetch(:gitlab_retries, 6)
    _delay   = ENV['BEAKER_gitlab_retry_delay'] || options.fetch(:gitlab_retry_delay, 15)

    # give the web interface time to start
    shell "sleep #{_sleep}"

    # FIXME For some reason, --retry-delay option no longer works when run in
    # on(), even though the option is supported by curl and works when logged
    # into the gitlab_server. The command seems to be correctly passed to the
    # net-ssh infrastructure, but perhaps the options are munged in the
    # process. curl fails with an error:
    #
    #   curl: option --retry-delay: expected a positive numerical parameter
    #
    #cmd = "#{curl_ssl_cmd(gitlab_server)} --retry #{_retries} --retry-delay #{_delay} -L " +
    #  (gitlab_signin_url || "https://#{gitlab_server_fqdn}/users/sign_in")
    cmd = "#{curl_ssl_cmd(gitlab_server)} --retry #{_retries} -L " +
      (gitlab_signin_url || "https://#{gitlab_server_fqdn}/users/sign_in")

    result = on(gitlab_server, cmd)
    expect(result.stdout).to match(/GitLab|password/)
  end

  it 'permits web access from permitted clients'  do
    result = on(
      permitted_client,
      "#{curl_ssl_cmd(permitted_client)} -L #{gitlab_signin_url}"
    )
    expect(result.stdout).to match(/GitLab|password/)
  end

  it 'denies web access from unknown clients' do
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

