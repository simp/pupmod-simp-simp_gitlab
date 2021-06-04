$test_binary = '/bin/test'

# NOTE: for the purposes of resetting GitLab, it _should_ be enough to
# run `gitlab-ctl cleanse`.  However, that hasn't always been enough
# while running these tests―so this uninstall makes very sure that all
# traces of GitLab are *removed.*
service{'gitlab-runsvdir':
  ensure => stopped,
  enable => false,
}

package{['gitlab-ce','gitlab-ee']: ensure=>absent}

exec{['/opt/gitlab/bin/gitlab-ctl cleanse',
      '/opt/gitlab/bin/gitlab-ctl remove-accounts',
      ]:
  tag => 'before_uninstall',
  onlyif => "${test_binary} -f /opt/gitlab/bin/gitlab-ctl",
}

exec{'/bin/rm -rf /run/gitlab*':
  tag => 'after_uninstall',
  onlyif => "${test_binary} -d /run/gitlab*",
}

exec{'/bin/rm -rf /opt/gitlab*':
  tag => 'after_uninstall',
  onlyif => "${test_binary} -d /opt/gitlab*",
}

exec{'/bin/rm -rf /var/log/gitlab*':
  tag => 'after_uninstall',
  onlyif => "${test_binary} -d /var/log/gitlab*",
}

file{ '/usr/lib/systemd/system/gitlab-runsvdir.service':
   ensure=>absent
}

Service <||>
->
Exec<| tag == 'before_uninstall' |>
->
Package<||>
->
Exec<| tag == 'after_uninstall' |>
->
File<||>

