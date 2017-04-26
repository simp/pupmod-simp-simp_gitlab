[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_gitlab.svg)](https://travis-ci.org/simp/pupmod-simp-simp_gitlab) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)

#### Table of Contents

* [Description](#description)
	* [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
	* [What simp_gitlab affects](#what-simp_gitlab-affects)
	* [Setup Requirements](#setup-requirements-optional)
	* [Beginning with simp_gitlab](#beginning-with-simp_gitlab)
* [Usage](#usage)
* [Reference](#reference)
	* [Further Reference for munging GitLab Omnibus](#further-reference-for-munging-gitlab-omnibus)
* [Limitations](#limitations)
  * [Omnibus syslog is limited to GitLab Enterprise Edition (TODO: see if we can ship the individual logs)](#omnibus-syslog-is-limited-to-gitlab-enterprise-edition-todo-see-if-we-can-ship-the-individual-logs)
* [Development](#development)
	* [Acceptance tests](#acceptance-tests)


## Description

This module provides profiles for integrating [GitLab Omnibus][gitlab_omnibus]
with SIMP.


[gitlab_omnibus]: https://docs.gitlab.com/omnibus/ "GitLab Omnibus"
[vshn_gitlab]: https://github.com/vshn/puppet-gitlab
[simp_simp_options]: https://github.com/simp/pupmod-simp-simp_options



### This is a SIMP module

This module is a component of the [System Integrity Management
Platform](https://github.com/NationalSecurityAgency/SIMP), a
compliance-management framework built on Puppet.

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

As a profile module, `simp_gitlab` has a few functions:

- [ ] Integrate SIMP and SIMP's global catalysts with GitLab Omnibus
  - [x] `trusted_nets`
  - [x] `firewall`
  - [x] `pki`
  - [ ] `ldap` (note: GitLab Omnibus has [significant limitations](https://docs.gitlab.com/ce/administration/auth/ldap.html#limitations) on TLS LDAP authentication for both servers and clients.)
  - [ ] Intentionally unimplemented:
    - [ ] `syslog` (deferred)
    - [x] `tcpwrappers` (nothing in Omnibus is linked to TCP Wrapper)
    - [x] `auditing` (nothing in Omnibus needs special auditd logic)
    - [x] SELinux (so far, nothing in the acceptance test have broken when SELinux is `enforcing`.  However, that is not expected).
  - [x] GitLab Omnibus's postfix is disabled and SIMP's postfix module is used
    - [ ] TODO: This could use more robust testing
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
- [x] Satisfy as many compliance profiles as possible



The profile makes extensive use of the component module
[`vshn/gitlab`][vshn_gitlab], which in turn configures the
GitLab Omnibus's `/etc/gitlab/gitlab.rb` and runs `gitlab-ctl reconfigure`.

The profiles makes extensive use of the component module
[`vshn/gitlab`][vshn_gitlab]
![](assets/simp_gitlab_components.png)

**FIXME:** Ensure the *What simp_gitlab affects* section is correct and complete, then remove this message!

mention:

 * A list of files, packages, services, or operations that the module will
   alter, impact, or execute.
 * Dependencies that your module automatically installs.
 * Warnings or other important notices.

### Setup Requirements

#### Notes on installing from an isolated network

- If using this module from an isolated network, ensure that package and repo management are disabled from the module, and that the `gitlab-ce` or `gitlab-ee` package is installed.  Be sure that the `$::simp_gitlab::editon` parameter is set to the correct edition.

**FIXME:** Ensure the *Setup Requirements* section is correct and complete, then remove this message!

### Beginning with simp_gitlab

**FIXME:** Ensure the *Beginning with simp_gitlab* section is correct and complete, then remove this message!

The most basic GitLab usage within a fully-configured SIMP infrastructure is:
```puppet
include 'simp_gitlab'
```



## Usage


A basic GitLab setup using PKI:
```puppet
class { 'simp_gitlab':
  trusted_nets => [
                    '10.0.0.0/8',
                    '192.168.21.21',
                    '192.168.21.22',
                    '127.0.0.1/32',
                  ],
  pki          => true,
  firewall     => true,
}
```



#### Configuring Nginx

If you need to configure the main Nginx server, use a `file` resource to drop a `.conf` file in `/etc/gitlab/nginx/conf.d/`.


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
  * vshn/gitlab component module:
    * https://github.com/vshn/puppet-gitlab
  - Security & compliance
    - https://www.stigviewer.com/stig/web_server/


## Limitations

### GitLab

#### Puppet runs can fail if GitLab Omnibus's internal services don't start in time

#### Omnibus syslog is limited to GitLab Enterprise Edition

  - [ ] `remote-syslog` is only packaged with the `ee` version, according to https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/config/projects/gitlab.rb#L84
  - [ ] [UDP log shipping](https://docs.gitlab.com/omnibus/settings/logs.html#udp-log-shipping-gitlab-enterprise-edition-only)
  - [ ] TODO: look into configuring `simp-rsyslog` to see ship the individual omnibus logs

#### Nessus scans may incorrectly report CRIME vulnerability in GitLab

This is almost certainly a false positive, as GitLab configures compression to `0` when HTTPS is enabled.

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

Please read our [Contribution Guide](http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html).

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

**FIXME:** Ensure the *Acceptance tests* section is correct and complete, including any module-specific instructions, and remove this message!

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md)
for more information.
