# @summary Manage PKI configuration
#
# @api private
# @author https://github.com/simp/pupmod-simp-simp_gitlab/graphs/contributors
#
class simp_gitlab::config::pki {
  assert_private()

  pki::copy { 'gitlab':
    pki    => $simp_gitlab::pki,
    source => $simp_gitlab::app_pki_external_source,
  }

  file { '/etc/gitlab/trusted-certs':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  pki_cert_sync{ '/etc/gitlab/trusted-certs':
    source                  => "${simp_gitlab::app_pki_dir}/cacerts",
    purge                   => true,
    # ``gitlab-ctl reconfigure`` generates PEM hash links
    generate_pem_hash_links => false,
  }

  Pki::Copy['gitlab'] -> Pki_cert_sync['/etc/gitlab/trusted-certs']
  File['/etc/gitlab/trusted-certs'] -> Pki_cert_sync['/etc/gitlab/trusted-certs']

  if $simp_gitlab::merged_gitlab_options['letsencrypt']['enable'] {
    # TODO: This module doesn't really integrate with Let's Encrypt yet. The
    # code below fixes one small problem, but not all.
    #
    # The GitLab letsencrypt recipe and pki::copy both manage the permissions of
    # the public destination directory of pki::copy. Unfortunately, they have
    # different opinions on the what the directory permissions should be. This
    # causes expensive flapping with each puppet run. (`gitlab-ctl reconfigure`
    # is executed **every** time.) Since the directory permissions cannot yet
    # be configured for the recipe or the pki::copy, override the permissions of
    # the appropriate file resource in pki::copy.
    #
    File <| title == "${simp_gitlab::app_pki_dir}/public" |> {
      # Recursive setting on the directory, so use the desired file permissions
      # and Puppet will take care of the directory permissions, properly.
      mode => '0644'
    }
  }

}
