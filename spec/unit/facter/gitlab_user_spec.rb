require 'spec_helper'

describe "custom fact gitlab_user" do

  before(:each) do
    Facter.clear

    # mock out Facter method called when evaluating confine for :kernel
    Facter::Core::Execution.stubs(:exec).with('uname -s').returns('Linux')
  end

  let(:conf_file) { '/var/opt/gitlab/gitlab-shell/config.yml' }

  # subset of valid gitlab-shell configuration
  let(:valid_conf) { {
    'user'       => 'git',
    'gitlab_url' => 'http://127.0.0.1:8080',
    'auth_file'  => '/var/opt/gitlab/.ssh/authorized_keys'
  } }

  let(:conf_missing_user) { valid_conf.dup.delete('user') }

  # subset of valid local user conf without gitlab users
  let(:local_users_without_gitlab) { <<EOM
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/bin:/sbin/nologin
daemon:x:2:2:daemon:/sbin:/sbin/nologin
EOM
}

  # subset of valid local user conf with gitlab users
  let(:local_users_with_gitlab) { <<EOM
#{local_users_without_gitlab}
gitlab-www:x:997:994::/var/opt/gitlab/nginx:/bin/false
git:x:996:993::/var/opt/gitlab:/bin/sh
gitlab-redis:x:995:992::/var/opt/gitlab/redis:/bin/false
gitlab-psql:x:994:991::/var/opt/gitlab/postgresql:/bin/sh
EOM
  }

  context 'valid gitlab-shell config available' do
    context 'gitlab-shell user in /etc/passwd' do
      it 'should return gitlab-shell user' do
        File.expects(:exist?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(valid_conf)
        File.expects(:read).with('/etc/passwd').returns(local_users_with_gitlab)
        expect(Facter.fact('gitlab_user').value).to eq 'git'
      end
    end

    context 'gitlab-shell user not in /etc/passwd' do
      it 'should return nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(valid_conf)
        File.expects(:read).with('/etc/passwd').returns(local_users_without_gitlab)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end
  end

  context 'invalid gitlab-shell config available' do
    context 'user key missing' do
      it 'should return nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(conf_missing_user)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end

    context 'malformed YAML' do
      it 'should return nil when YAML.load_file returns nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(nil)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end

      it 'should return nil when YAML.load_file raises Psych::SyntaxError' do
        File.expects(:exist?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).raises(Psych::SyntaxError)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end
  end

  context 'gitlab-shell config not available' do
    it 'should return nil' do
      File.expects(:exist?).with(conf_file).returns(false)
      expect(Facter.fact('gitlab_user').value).to eq nil
    end
  end
end
