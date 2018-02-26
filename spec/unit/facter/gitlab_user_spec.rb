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

  # SEE https://www.onyxpoint.com/resetting-stubs-in-mocha/ for explanation
  # of weird mocha stub code below for File.file?()
  context 'valid gitlab-shell config available' do
    context 'gitlab-shell user in /etc/passwd' do
      it 'should return gitlab-shell user' do
        File.expects(:exist?).with(conf_file).returns(true)
        File.expects(:file?).with(conf_file).returns(true)
        File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
        File.expects(:readable?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(valid_conf)
        Etc.expects(:getpwnam).with('git').returns('something') # return value not used
        expect(Facter.fact('gitlab_user').value).to eq 'git'
      end
    end

    context 'gitlab-shell user not in /etc/passwd' do
      it 'should return nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        File.expects(:file?).with(conf_file).returns(true)
        File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
        File.expects(:readable?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(valid_conf)
        Etc.expects(:getpwnam).with('git').raises(ArgumentError) # unknown user
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end
  end

  context 'invalid gitlab-shell config available' do
    context 'user key missing' do
      it 'should return nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        File.expects(:file?).with(conf_file).returns(true)
        File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
        File.expects(:readable?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(conf_missing_user)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end

    context 'malformed YAML' do
      it 'should return nil when YAML.load_file returns nil' do
        File.expects(:exist?).with(conf_file).returns(true)
        File.expects(:file?).with(conf_file).returns(true)
        File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
        File.expects(:readable?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).returns(nil)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end

      it 'should return nil when YAML.load_file raises Psych::SyntaxError' do
        File.expects(:exist?).with(conf_file).returns(true)
        File.expects(:file?).with(conf_file).returns(true)
        File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
        File.expects(:readable?).with(conf_file).returns(true)
        YAML.expects(:load_file).with(conf_file).raises(Psych::SyntaxError)
        expect(Facter.fact('gitlab_user').value).to eq nil
      end
    end
  end

  context 'gitlab-shell config not available' do
    it 'should return nil when file does not exist' do
      File.expects(:exist?).with(conf_file).returns(false)
      expect(Facter.fact('gitlab_user').value).to eq nil
    end

    it 'should return nil when config path is not a file' do
      File.expects(:exist?).with(conf_file).returns(true)
      File.expects(:file?).with(conf_file).returns(false)
      File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
      expect(Facter.fact('gitlab_user').value).to eq nil
    end

    it 'should return nil when config file is not readable' do
      File.expects(:exist?).with(conf_file).returns(true)
      File.expects(:file?).with(conf_file).returns(true)
      File.stubs(:file?).with(Not(equals(conf_file))).returns(true)
      File.expects(:readable?).with(conf_file).returns(false)
      expect(Facter.fact('gitlab_user').value).to eq nil
    end
  end
end
