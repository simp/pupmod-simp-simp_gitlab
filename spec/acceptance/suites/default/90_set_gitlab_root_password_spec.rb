require 'spec_helper_acceptance'
require 'helpers/curl_ssl_cmd'
require 'json'

describe 'change_gitlab_root_password misc' do

  # This test assumes a running GitLab server is up and running and
  # ***will change*** the GitLab root password.
  #
  # 11_ssh_access_spec.rb has already verified the root password was set to the
  # value expected. So, this is a catch all for other test cases of that script.
  #
  let(:exe) { '/usr/local/sbin/change_gitlab_root_password' }

  context 'success cases' do
    it 'should print a help message when -h option is used' do
      cmd = "#{exe} -h"
      result = on(gitlab_server, cmd)
      expect(result.stdout).to match(/Usage:/)
    end

    it 'should debug log when -v option is used' do
      cmd = "#{exe} -v N3w=R00t=P@ssword"
      result = on(gitlab_server, cmd)
      expect(result.stdout).to match(/Loading gitlab-rails console/)
    end
  end

  context 'error cases' do
    it 'should fail when the gitlab-rails console load times out' do
      cmd = "#{exe} -t 1 N3w=R00t=P@ssword"
      on(gitlab_server, cmd, :acceptable_exit_codes => [1])
    end

    it 'should fail when no password is specified' do
      on(gitlab_server, exe, :acceptable_exit_codes => [1])
    end

    it 'should fail when the password is empty' do
      cmd = "#{exe} ''"
      on(gitlab_server, cmd, :acceptable_exit_codes => [1])
    end
  end

end
