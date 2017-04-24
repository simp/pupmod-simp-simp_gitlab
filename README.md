**FIXME**: Ensure the badges are correct and complete, then remove this message!

[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_gitlab.svg)](https://travis-ci.org/simp/pupmod-simp-simp_gitlab) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-6.*-orange.svg)

#### Table of Contents

* [Description](#description)
	* [This is a SIMP module](#this-is-a-simp-module)
* [Setup](#setup)
	* [What simp_gitlab affects](#what-simp_gitlab-affects)
	* [Setup Requirements **OPTIONAL**](#setup-requirements-optional)
	* [Beginning with simp_gitlab](#beginning-with-simp_gitlab)
* [Usage](#usage)
* [Reference](#reference)
	* [Further Reference for munging GitLab Omnibus](#further-reference-for-munging-gitlab-omnibus)
* [Limitations](#limitations)
  * [Omnibus syslog is limited to GitLab Enterprise Edition (TODO: see if we can ship the individual logs)](#omnibus-syslog-is-limited-to-gitlab-enterprise-edition-todo-see-if-we-can-ship-the-individual-logs)
* [Development](#development)
	* [Acceptance tests](#acceptance-tests)


## Description

This module provides profiles for managing [GitLab Omnibus](gitlab_omnibus)
with SIMP.


[gitlab_omnibus]: https://docs.gitlab.com/omnibus/ "GitLab Omnibus"
[vshn_gitlab]: https://github.com/vshn/puppet-gitlab
[simp_simp_options]: https://github.com/simp/pupmod-simp-simp_options


The profiles make extensive use of the component module
[`vshn/gitlab`](vshn_gitlab)

**FIXME:** Ensure the *Description* section is correct and complete, then remove this message!


Start with a one- or two-sentence summary of what the module does and/or what
problem it solves. This is your 30-second elevator pitch for your module.
Consider including OS and Puppet version compatability, and any other
information users will need to quickly assess the module's viability within
their environment.

You can give more descriptive information in a second paragraph. This paragraph
should answer the questions: "What does this module *do*?" and "Why would I use
it?" If your module has a range of functionality (installation, configuration,
management, etc.), this is the time to mention it.

### This is a SIMP module

This module is a component of the [System Integrity Management
Platform](https://github.com/NationalSecurityAgency/SIMP), a
compliance-management framework built on Puppet.

**FIXME:** Ensure the *This is a SIMP module* section is correct and complete, then remove this message!

It is designed to be used within a larger SIMP ecosystem, but it can be used
independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used as an independent module, all SIMP-managed security subsystems are
   disabled by default and must be explicitly opted into by administrators.
   Please review the parameters in [`simp/simp_options`](simp_simp_options) for
   details.


If you find any issues, please let us know by filing an issue at
https://simp-project.atlassian.net/.

## Setup

### What `simp_gitlab` affects

As a profile module, `simp_gitlab` has a few functions:

- [x] Integrate SIMP's global catalysts with GitLab Omnibus
- [ ] Ensure that GitLab Omnibus can be installed without internet access
- [ ] Simplify GitLab configuration for common scenarios
   - [x] GitLab
   - [x] GitLab + Omnibus version of NGINX
   - [ ] Mattermost
   - [ ] Prometheus
   - [ ] GitLab CI runner
   - [ ] GitLab CI Runner (docker)
- [x] Permit customization of GitLab Omnibus
- [x] Satisfy as many compliance profiles as possible

Most of this is done by configuring the [`vshn/gitlab`](vshn_gitlab) component
module, which in turn configures the GitLab Omnibus's `/etc/gitlab/gitlab.rb`
and runs `gitlab-ctl reconfigure`.

TODO: diagram

**FIXME:** Ensure the *What simp_gitlab affects* section is correct and complete, then remove this message!

mention:

 * A list of files, packages, services, or operations that the module will
   alter, impact, or execute.
 * Dependencies that your module automatically installs.
 * Warnings or other important notices.

### Setup Requirements **OPTIONAL**

If using this module from an isolated network, ensure that package and repo management are disabled from the module and that the `gitlab-ce` or `gitlab-ee` package is installed.  Be sure that the `$::simp_gitlab::editon` parameter is set to the correct edition.

**FIXME:** Ensure the *Setup Requirements* section is correct and complete, then remove this message!

If your module requires anything extra before setting up (pluginsync enabled,
etc.), mention it here.

If your most recent release breaks compatibility or requires particular steps
for upgrading, you might want to include an additional "Upgrading" section
here.

### Beginning with simp_gitlab

**FIXME:** Ensure the *Beginning with simp_gitlab* section is correct and complete, then remove this message!

The very basic steps needed for a user to get the module up and running. This
can include setup steps, if necessary, or it can be an example of the most
basic use of the module.

## Usage

A basic GitLab setup using PKI
```puppet
class { 'simp_gitlab':
  trusted_nets => [
                    '10.0.0.0/8',
                    '192.168.21.21',
                    '192.168.21.22',
                  ],
  pki          => true,
  firewall     => true,
}
```

**FIXME:** Ensure the *Usage* section is correct and complete, then remove this message!

This section is where you describe how to customize, configure, and do the
fancy stuff with your module here. It's especially helpful if you include usage
examples and code samples for doing things with your module.

## Reference

**FIXME:** Ensure the *Reference* section is correct and complete, then remove this message!  If there is pre-generated YARD documentation for this module, ensure the text links to it and remove references to inline documentation.

Please refer to the inline documentation within each source file, or to the
module's generated YARD documentation for reference material.

### Further Reference for munging GitLab Omnibus

  * GitLab Omnibus
    - documentation: https://docs.gitlab.com/omnibus/README.html
      - [Common installation problems](https://docs.gitlab.com/omnibus/common_installation_problems/README.html)
      - [Maintainence commands](https://docs.gitlab.com/omnibus/maintenance/README.html#maintenance-commands)
      - [Troubleshooting](https://docs.gitlab.com/omnibus/README.html#troubleshooting)
    - architecture: https://docs.gitlab.com/omnibus/architecture/README.html
      - [Global GitLab configuratino template](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template)
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

### Omnibus syslog is limited to GitLab Enterprise Edition (TODO: see if we can ship the individual logs)
  - [ ] `remote-syslog` is only packaged with the `ee` version, according to https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/config/projects/gitlab.rb#L84
  - [ ] [UDP log shipping](https://docs.gitlab.com/omnibus/settings/logs.html#udp-log-shipping-gitlab-enterprise-edition-only)

**FIXME:** Ensure the *Limitations* section is correct and complete, then remove this message!

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.

## Development

**FIXME:** Ensure the *Development* section is correct and complete, then remove this message!

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
