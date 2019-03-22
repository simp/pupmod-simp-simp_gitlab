[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_gitlab.svg)](https://forge.puppetlabs.com/simp/simp_gitlab)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_gitlab.svg)](https://forge.puppetlabs.com/simp/simp_gitlab)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_gitlab.svg)](https://travis-ci.org/simp/pupmod-simp-simp_gitlab)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
  * [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
  * [What `simp_gitlab` affects](#what-simp_gitlab-affects)
  * [Setup Requirements](#setup-requirements)
  * [Beginning with simp_gitlab](#beginning-with-simp_gitlab)
* [Usage](#usage)
  * [A basic GitLab setup using PKI](#a-basic-gitlab-setup-using-pki)
  * [Passing custom parameters to `puppet-gitlab`](#passing-custom-parameters-to-puppet-gitlab)
  * [Configuring Nginx](#configuring-nginx)
* [Reference](#reference)
  * [Further Reference for munging GitLab Omnibus](#further-reference-for-munging-gitlab-omnibus)
* [Limitations](#limitations)
  * [Gitlab's LDAP TLS is configured to re-use Omnibus' `trusted-certs/` instead of `ca_file`](#gitlabs-ldap-tls-is-configured-to-re-use-omnibus-trusted-certs-instead-of-ca_file)
  * [GitLab](#gitlab)
    * [Puppet runs can fail if GitLab Omnibus's internal services don't start in time](#puppet-runs-can-fail-if-gitlab-omnibuss-internal-services-dont-start-in-time)
    * [Nessus scans may incorrectly report CRIME vulnerability in GitLab](#nessus-scans-may-incorrectly-report-crime-vulnerability-in-gitlab)
    * [Redis log warnings](#redis-log-warnings)
* [Development](#development)
  * [Acceptance tests](#acceptance-tests)
    * [Environment variable `TEST_GITLAB_CE_VERSION`](#environment-variable-test_gitlab_ce_version)
    * [Environment variable `TRUSTED_NETS`](#environment-variable-trusted_nets)
    * [Manually inspecting the SUT GitLab server with a web browser](#manually-inspecting-the-sut-gitlab-server-with-a-web-browser)
    * [Interactive debugging using pry](#interactive-debugging-using-pry)

<!-- vim-markdown-toc -->


## Description

This module provides profiles for integrating [GitLab Omnibus][gitlab_omnibus]
with SIMP.


[gitlab_omnibus]: https://docs.gitlab.com/omnibus/ "GitLab Omnibus"
[gitlab_rb_template]: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template
[puppet_gitlab]: https://github.com/voxpupuli/puppet-gitlab
[simp_simp_options]: https://github.com/simp/pupmod-simp-simp_options



### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

It is designed to be used within a larger SIMP ecosystem, but it can be used
independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used as an independent module, all SIMP-managed security subsystems are
   disabled by default and must be explicitly opted into by administrators.
   Please review the parameters in [`simp/simp_options`][simp_simp_options] for
   details.

If you run into problems, please let us know by filing an issue at
https://simp-project.atlassian.net/.

## Setup

### What `simp_gitlab` affects

This module is a profile that integrates Gitlab with SIMP.  It makes extensive
use of the component module [`puppet/gitlab`][puppet_gitlab].  It is important to
note that `puppet-gitlab` configures the GitLab Omnibus's `/etc/gitlab/gitlab.rb`
and runs `gitlab-ctl reconfigure`.

![Relationships between components](assets/simp_gitlab_components.png)

As a profile module, `simp_gitlab` has a few functions:

- [x] Integrate SIMP and SIMP's global catalysts with GitLab Omnibus
  - [x] Supported SIMP Options (global catalysts):
    - [x] `simp_options::trusted_nets`
    - [x] `simp_options::firewall`
    - [x] `simp_options::pki`
    - [x] `simp_options::ldap::*`
  - Intentionally unimplemented:
    - `simp_options::selinux` ― The GitLab Omnibus installer appears to handle SELinux correctly
    - `simp_options::tcpwrappers` ― nothing in Omnibus is linked to TCP Wrapper
    - `simp_options::auditing` ― nothing in Omnibus needs special auditd logic
  - Deferred:
    - `simp_options::fips` ― GitLab Omnibus ships with a version of OpenSSL that does not support FIPS mode
    - `simp_options::syslog` (not clear that we want to support this outside of `ee`)
  - SIMP integrations:
    - Open access for a local `git` SSH user
       - set up a SIMP `pam::access::rule` to permit GitLab's local `git` user
       - configures `sshd` such that the GitLab's local `git` user's SSH authorized
         keys file path is managed only by the GitLab Omnibus installer.
    - The postfix service that comes with GitLab Omnibus is disabled in favor
      of the SIMP `postfix` module.
- [ ] Ensure that GitLab Omnibus can be installed without internet access
  - [ ] This requires a local mirror of the Gitlab repositories
- [ ] Simplify GitLab configuration for common scenarios
   - [x] GitLab
   - [x] GitLab + Omnibus version of NGINX
   - [ ] Mattermost
   - [ ] GitLab CI runner
   - [ ] Intentionally unimplemented:
     - [ ] Prometheus
       - (Omnibus's integrated Prometheus app monitoring requires Gitlab Omnibus to be installed [_within_ a docker container](https://docs.gitlab.com/ce/user/project/integrations/prometheus.html#configuring-prometheus-to-collect-kubernetes-metrics))
     - [ ] GitLab CI Runner (docker)
- [x] Permit customization of GitLab Omnibus
- [x] Satisfy as many compliance-relevant criteria as possible


**FIXME:** Ensure the *What simp_gitlab affects* section is correct and complete, then remove this message!

mention:

 * A list of files, packages, services, or operations that the module will
   alter, impact, or execute.
 * Dependencies that your module automatically installs.
 * Warnings or other important notices.

### Setup Requirements


If using this module from an isolated network, ensure that package and repo
management are disabled from the module, and that the `gitlab-ce` or
`gitlab-ee` package is installed.  Be sure that the `$::simp_gitlab::edition`
parameter is set to the correct edition.

### Upgrade to 0.3.0

Upgrading from simp_gitlab 0.2.0 to 0.3.0 requires you to copy the authorized key file
from `/etc/ssh/local_keys/git` to `/var/opt/gitlab/.ssh/authorized_keys`. Alternately
you can re-add your deployment keys in the gitlab interface.
See the CHANGELOG entries for version 0.3.0 for more details.

### Beginning with simp_gitlab

The most basic GitLab usage within a SIMP-managed infrastructure where all
`simp_options::` are present:

```puppet
include 'simp_gitlab'
```


## Usage


### A basic GitLab setup using PKI

```puppet
class { 'simp_gitlab':
  trusted_nets => [
                    '10.0.0.0/8',
                    '192.168.21.21',
                    '192.168.21.22',
                    '127.0.0.1/32',
                  ],
  pki          => 'simp',
  firewall     => true,
}
```


### Passing custom parameters to `puppet-gitlab`

Parameters for [`puppet/gitlab`][puppet_gitlab] can be passed in directly using the
(Hash) `$simp_gitlab::gitlab_options` parameter.

**Warning:**  `$simp_gitlab::gitlab_options` parameters that conflict with the
rest of `simp_gitlab` may lead to undefined behavior / broken systems.


**Hint:** Many of the data structures used by [`puppet/gitlab`][puppet_gitlab]'s
parameters are documented at
https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template

```puppet

# Name the local git user account `gitlab` (instead of the default `git`)
class { 'simp_gitlab':
  trusted_nets   => $simp_options::trusted_nets
  pki            => 'simp',
  firewall       => true,
  gitlab_options => {
    'user' => {
      'username' => 'gitlab',
      'group'    => 'gitlab',
    }
  },
}
```


### Configuring Nginx

`simp_gitlab` configures the GitLab's internal Nginx server to look for
additional `.conf` files under `/etc/gitlab/nginx/conf.d/`.

If you need to configure the main Nginx server, use a `file` resource from your
own profiles to establish a new `.conf` file.


## Reference

Please refer to the inline documentation within each source file, or to the
module's generated YARD documentation for reference material.

### Further Reference for munging GitLab Omnibus

  * GitLab Omnibus
    - documentation: https://docs.gitlab.com/omnibus/README.html
      - [Common installation problems](https://docs.gitlab.com/omnibus/common_installation_problems/README.html)
      - [Maintainence commands](https://docs.gitlab.com/omnibus/maintenance/README.html#maintenance-commands)
      - [Troubleshooting](https://docs.gitlab.com/omnibus/README.html#troubleshooting)
    - architecture: https://docs.gitlab.com/omnibus/architecture/README.html
      - [Global GitLab configuration template](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)
      - [Templates for configurations of components](https://docs.gitlab.com/omnibus/architecture/README.html#templates-for-configuration-of-components)
      - [`gitlab-reconfigure`](https://docs.gitlab.com/omnibus/architecture/README.html#what-happens-during-gitlab-ctl-reconfigure)
    - source: https://gitlab.com/gitlab-org/omnibus-gitlab
    - optional services:
      - Mattermost (chat): https://docs.gitlab.com/omnibus/gitlab-mattermost/README.html
      - Prometheus (monitoring): https://docs.gitlab.com/ce/administration/monitoring/prometheus/index.html
      - GitLab Docker images: https://docs.gitlab.com/omnibus/docker/README.html
  * puppet/gitlab component module:
    * https://github.com/voxpupuli/puppet-gitlab
  - Security & compliance
    - https://www.stigviewer.com/stig/web_server/


## Limitations

### Gitlab's LDAP TLS is configured to re-use Omnibus' `trusted-certs/` instead of `ca_file`

`simp_gitlab` configures the GitLab Rails server LDAP TLS settings to use the
Omnibus trusted_certs (built from `/etc/gitlab/trusted-certs`) instead of its
own `ca_file` option.

The LDAP `ca_file` setting is known to [cause problems elsewhere in GitLab
SSL][ldap_ca_file_problems].  There is a [(currently undocumented)
workaround][ce37254_workarounds] to these issues: GitLab's LDAP TLS will re-use
the GitLab Omnibus `trusted-certificates/ ` directory―but [_only_ when the LDAP
`ca_file` option has **not** been set][ce37254_trusted_wo_ca_file]

The drawback to this solution is that GitLab's LDAP client must share the same
TLS settings as GitLab's web server―which is something that [we try to keep
distinct][distinct_tls], as there could be situations in which their
configurations legitimately vary.

[ldap_ca_file_problems]: https://gitlab.com/gitlab-org/gitlab-ce/issues/40003
[ce37254_workarounds]: https://gitlab.com/gitlab-org/gitlab-ce/issues/37254#note_45543716
[ce37254_trusted_wo_ca_file]: https://gitlab.com/gitlab-org/gitlab-ce/issues/37254#note_3894021
[distinct_tls]: https://github.com/simp/pupmod-simp-simp_openldap/blob/master/manifests/client.pp#L15-L18



### GitLab

#### Puppet runs can fail if GitLab Omnibus's internal services don't start in time

**Note:** These are limitations of upstream components

* The Exec that runs `gitlab-ctl reconfigure` may take a long time start its
  internal services, particularly during the first run that installs GitLab.
  These services are internal to the GitLab Omnibus installation and are not
  registered with the host OS or the Puppet providers for `service`.  It is
  possible for the services to take so long to start in the background that
  dependencies within `puppet-gitlab` will fail.
  <!-- this line is indented to continue the preceding bullet -->
  In these cases, it should be sufficient to simply run Puppet again after the
  services finish starting (status with `gitlab-ctl status`).

* If the GitLab Omnibus package is already installed but the `gitlab-runsvdir`
  service is stopped, the service will not start and catalog compilation will
  fail.

#### Nessus scans may incorrectly report CRIME vulnerability in GitLab

This is almost certainly a false positive―GitLab configures compression to `0` when HTTPS is enabled.

- See https://docs.gitlab.com/ce/security/crime_vulnerability.html for details.

#### Redis log warnings

Right now, redis logs these warnings (running in beaker/vagrant VMs):

```
# WARNING overcommit_memory is set to 0! Background save may fail under low
memory condition. To fix this issue add 'vm.overcommit_memory = 1' to
/etc/sysctl.conf and then reboot or run the command 'sysctl
vm.overcommit_memory=1' for this to take effect.

# WARNING you have Transparent Huge Pages (THP) support enabled in your kernel.
This will create latency and memory usage issues with Redis. To fix this issue
run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as
root, and add it to your /etc/rc.local in order to retain the setting after
a reboot. Redis must be restarted after THP is disabled.
```

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md)
for more information.

#### Environment variable `TEST_GITLAB_CE_VERSION`

`TEST_GITLAB_CE_VERSION` is an environment variable that can be used
to specify the version of gitlab-ce to use in the acceptance tests.
When set, it must either a version string for a specific gitlab-ce
package version or 'latest' to indicate the latest available version.

```shell
TEST_GITLAB_CE_VERSION=latest bundle exec rake beaker:suites
```

#### Environment variable `TRUSTED_NETS`

`TRUSTED_NETS` is an environment variable that may contain a comma-delimited
list of trusted networks to add to the gitlab SUT's firewall.

```shell
TRUSTED_NETS=192.168.11.0/24,10.0.2.2 bundle exec rake beaker:suites
```

**Note:** if the `TRUSTED_NETS` configuration is too broad, it may cause
some acceptance tests (for denied clients) to fail.

#### Manually inspecting the SUT GitLab server with a web browser

Each nodeset in `spec/acceptance/nodesets/` contains a commented-out
`forwarded_ports:` section.  If you want to use a web browser to manually
inspect the SUT GitLab server during any of the tests, uncomment this section
and add the NAT network router's IP address to the `TRUSTED_NETS` variable.

For example:

```shell
TRUSTED_NETS=10.0.2.2 BEAKER_destroy=no bundle exec rake beaker:suites
```

Then, in a browser on the host machine, navigate to `https://127.0.0.1:<port>`,
where `<port>` is the forwarded port for the test being executed, i.e.,
8080, 8443, or 8777.

**Note:** If you need to login as the administrator to the GitLab instance,
use the login of `root` and the password found on the GitLab server host at
`/opt/puppetlabs/puppet/cache/simp/environments/production/simp_autofiles/gen_passwd/simp_gitlab_server.<your domain>`.

#### Interactive debugging using pry

Setting the environment variable `PRY=yes` will cause the acceptance tests to
drop into a pry console under certain circumstances (usually just before
failures in examples with complex or hard-to-debug state).  This will
effectively pause the test, to allow you to debug.

```shell
TRUSTED_NETS=10.0.2.2 BEAKER_destroy=no PRY=yes bundle exec rake beaker:suites
```
