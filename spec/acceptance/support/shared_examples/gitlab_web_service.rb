require 'helpers/curl_ssl_cmd'

shared_examples_for 'a GitLab web service' do |gitlab_signin_url, options|
  # Assert on stable signals only. The GitLab web UI is scraped-string-hostile:
  # it is redesigned frequently and, as of 19.0, renders the sign-in form
  # client-side, so server-rendered markers like "Forgot your password" no
  # longer appear in the fetched HTML. Instead we use:
  #
  #   * the /-/health liveness endpoint for "is GitLab up" (a documented API
  #     contract returning "GitLab OK"). Note it is only reachable from GitLab's
  #     monitoring allowlist -- localhost by default -- so it is only queried
  #     from the server itself; and
  #   * HTTP status codes for access control (permitted client -> 200,
  #     unknown client -> 403 / connection refused).
  #
  # Whether the root password was actually set is verified separately (the
  # set_gitlab_root_password exec and 90_set_gitlab_root_password_spec.rb), so
  # it is not re-checked here.

  it 'serves GitLab web content to local client' do
    opt__sleep   = ENV['BEAKER_gitlab_sleep'] || options.fetch(:gitlab_sleep, 30)
    opt__retries = ENV['BEAKER_gitlab_retries'] || options.fetch(:gitlab_retries, 6)
    health_url   = gitlab_signin_url.sub(%r{(\Ahttps?://[^/]+).*}m, '\1/-/health')

    # give the web interface time to start
    shell "sleep #{opt__sleep}"

    # --retry-connrefused so the retries actually cover "nginx is still coming
    # back up" (plain --retry does not retry a refused connection).
    cmd = "#{curl_ssl_cmd(gitlab_server)} --retry #{opt__retries} --retry-connrefused -L #{health_url}"
    result = on(gitlab_server, cmd)
    expect(result.stdout).to include('GitLab OK')
  end

  it 'permits web access from permitted clients' do
    # A permitted client (in trusted_nets) should reach the web UI over TLS.
    # Assert on the HTTP status, not page content.
    cmd = "#{curl_ssl_cmd(permitted_client)} -o /dev/null -w '%{http_code}' -L #{gitlab_signin_url}"
    result = on(permitted_client, cmd)
    expect(result.stdout).to eq('200')
  end

  it 'denies web access from unknown clients' do
    if options.fetch(:firewall, true) == true
      # When the server's firewall is enabled, the connection never completes.
      #
      #  Curl exit codes:
      #    7  = failed to connect
      #    28 = connection timed out
      #
      #  Which one occurs depends on how the host network stack is locked down.
      curl_cmd = "#{curl_ssl_cmd(denied_client)} -L #{gitlab_signin_url}"
      on(denied_client, curl_cmd, acceptable_exit_codes: [7, 28])
    else
      # Without a firewall, GitLab's own trusted_nets (nginx) rejects the
      # unknown client with a 403.
      curl_cmd = "#{curl_ssl_cmd(denied_client)} -o /dev/null -w '%{http_code}' -L #{gitlab_signin_url}"
      result = on(denied_client, curl_cmd)
      expect(result.stdout).to eq('403')
    end
  end
end
