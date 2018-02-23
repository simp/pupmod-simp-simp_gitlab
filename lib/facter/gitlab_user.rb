# _Description_
#
# Return the username of the GitLab user.
#
# Returns nil if
# * /var/opt/gitlab/gitlab-shell/config.yml does not exist
# * /var/opt/gitlab/gitlab-shell/config.yml is malformed YAML
# * 'user' is not specified in /var/opt/gitlab/gitlab-shell/config.yml
# * The user specified in /var/opt/gitlab/gitlab-shell/config.yml does
#   not exist in /etc/passwd.
#
Facter.add(:gitlab_user) do
  confine :kernel => 'Linux'

  gitlab_shell_conf = '/var/opt/gitlab/gitlab-shell/config.yml'
  confine { File.exist?(gitlab_shell_conf) }

  setcode do
    require 'etc'
    require 'yaml'
    gitlab_user = nil
    begin
      gitlab_shell_yaml = YAML.load_file(gitlab_shell_conf)
      # YAML.load_file can return nil or raise Psych::SyntaxError
      # when YAML is malformed
      if gitlab_shell_yaml and gitlab_shell_yaml['user']
        begin
          Etc.getpwnam(gitlab_shell_yaml['user'])
          gitlab_user = gitlab_shell_yaml['user']
        rescue ArgumentError
          # user does not exist
        end
      end
    rescue Psych::SyntaxError
    end
    gitlab_user
  end
end

