# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

#### Public Classes

* [`simp_gitlab`](#simp_gitlab): SIMP Profile for managing GitLab

#### Private Classes

* `simp_gitlab::config`: Manage additional GitLab-related configuration
* `simp_gitlab::config::firewall`: Manage firewall for external GitLab access
* `simp_gitlab::config::pki`: Manage PKI configuration
* `simp_gitlab::install`: Install, initially configure and bring up a GitLab instance

### Functions

* [`simp_gitlab::omnibus_config::gitlab`](#simp_gitlab--omnibus_config--gitlab): Compile a hash of settings for the ``gitlab`` class parameters, using SIMP settings
* [`simp_gitlab::omnibus_config::gitlab_rails`](#simp_gitlab--omnibus_config--gitlab_rails): Compile a hash of settings for the ``gitlab::gitlab_rails`` parameter, using SIMP settings
* [`simp_gitlab::omnibus_config::gitlab_shell`](#simp_gitlab--omnibus_config--gitlab_shell): Compile a hash of settings for the ``gitlab::shell`` parameter, using SIMP settings
* [`simp_gitlab::omnibus_config::mattermost`](#simp_gitlab--omnibus_config--mattermost): Compile a hash of settings for the ``gitlab::mattermost`` parameter, using SIMP settings
* [`simp_gitlab::omnibus_config::nginx`](#simp_gitlab--omnibus_config--nginx): Compile a hash of settings for the ``gitlab::nginx`` parameter, using SIMP settings

### Data types

* [`Simp_Gitlab::Stroolean`](#Simp_Gitlab--Stroolean): Valid PKI management options

## Classes

### <a name="simp_gitlab"></a>`simp_gitlab`

Welcome to SIMP!

This module is a component of the System Integrity Management Platform, a
managed security compliance framework built on Puppet.

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

* When included within the SIMP ecosystem, security compliance settings will
  be managed from the Puppet server.

* If used independently, all SIMP-managed security subsystems are disabled by
  default, and must be explicitly opted into by administrators.  Please
  review the parameters (e.g., ``$trusted_nets``, ``$pki``) for details.

#### Parameters

The following parameters are available in the `simp_gitlab` class:

* [`trusted_nets`](#-simp_gitlab--trusted_nets)
* [`denied_nets`](#-simp_gitlab--denied_nets)
* [`external_url`](#-simp_gitlab--external_url)
* [`tcp_listen_port`](#-simp_gitlab--tcp_listen_port)
* [`firewall`](#-simp_gitlab--firewall)
* [`pki`](#-simp_gitlab--pki)
* [`app_pki_external_source`](#-simp_gitlab--app_pki_external_source)
* [`app_pki_dir`](#-simp_gitlab--app_pki_dir)
* [`app_pki_key`](#-simp_gitlab--app_pki_key)
* [`app_pki_cert`](#-simp_gitlab--app_pki_cert)
* [`app_pki_ca`](#-simp_gitlab--app_pki_ca)
* [`edition`](#-simp_gitlab--edition)
* [`two_way_ssl_validation`](#-simp_gitlab--two_way_ssl_validation)
* [`ldap_verify_certificates`](#-simp_gitlab--ldap_verify_certificates)
* [`ssl_verify_depth`](#-simp_gitlab--ssl_verify_depth)
* [`ssl_protocols`](#-simp_gitlab--ssl_protocols)
* [`gitlab_options`](#-simp_gitlab--gitlab_options)
* [`cipher_suite`](#-simp_gitlab--cipher_suite)
* [`ldap`](#-simp_gitlab--ldap)
* [`ldap_uri`](#-simp_gitlab--ldap_uri)
* [`ldap_active_directory`](#-simp_gitlab--ldap_active_directory)
* [`ldap_base_dn`](#-simp_gitlab--ldap_base_dn)
* [`ldap_bind_dn`](#-simp_gitlab--ldap_bind_dn)
* [`ldap_bind_pw`](#-simp_gitlab--ldap_bind_pw)
* [`ldap_user_filter`](#-simp_gitlab--ldap_user_filter)
* [`ldap_group_base`](#-simp_gitlab--ldap_group_base)
* [`manage_package`](#-simp_gitlab--manage_package)
* [`package_ensure`](#-simp_gitlab--package_ensure)
* [`set_gitlab_root_password`](#-simp_gitlab--set_gitlab_root_password)
* [`gitlab_root_password`](#-simp_gitlab--gitlab_root_password)
* [`rails_console_load_timeout`](#-simp_gitlab--rails_console_load_timeout)
* [`allow_fips`](#-simp_gitlab--allow_fips)

##### <a name="-simp_gitlab--trusted_nets"></a>`trusted_nets`

Data type: `Simplib::Netlist`

A list of subnets (in CIDR notation) that should be permitted access

Default value: `simplib::lookup('simp_options::trusted_nets', {'default_value' => ['127.0.0.1/32'] })`

##### <a name="-simp_gitlab--denied_nets"></a>`denied_nets`

Data type: `Simplib::Netlist`

A list of subnets (in CIDR notation) that should be explicitly denied access

Default value: `[]`

##### <a name="-simp_gitlab--external_url"></a>`external_url`

Data type: `Simplib::Uri`

External URL of Gitlab.  By default, this will be 'https://<fqdn>' if
``$pki`` is set and 'http://<fqdn>' if it is ``false``.

Default value: `$pki ? { true => "https://${facts['networking']['fqdn']}", 'simp' => "https://${facts['networking']['fqdn']}", default => "http://${facts['networking']['fqdn']}"`

##### <a name="-simp_gitlab--tcp_listen_port"></a>`tcp_listen_port`

Data type: `Simplib::Port`

The port upon which to listen for regular TCP connections.  By default
this will be ``'80'`` if HTTPS is disabled and ``'443'`` if HTTPS is enabled.

Default value: `$pki ? { true => 443, 'simp' => 443, default => 80`

##### <a name="-simp_gitlab--firewall"></a>`firewall`

Data type: `Boolean`

If ``true``, manage firewall rules to accommodate **simp_gitlab**

Default value: `simplib::lookup('simp_options::firewall',      {'default_value' => false})`

##### <a name="-simp_gitlab--pki"></a>`pki`

Data type: `Simp_gitlab::Stroolean`

* If ``'simp'``, include ``simp/pki`` and use ``pki::copy`` to manage
  application certs in /etc/pki/simp_apps/gitlab/x509
* If ``true``, do *not* include ``simp/pki`` , but still use ``pki::copy``
  to manage certs in /etc/pki/simp_apps/gitlab/x509
* If ``false``, do not include ``simp/pki`` and do not use ``pki::copy``
  to manage certs.  You will need to appropriately assign a subset of:

     * ``$app_pki_dir``
     * ``$app_pki_key``
     * ``$app_pki_cert``
     * ``$app_pki_ca``

Default value: `simplib::lookup('simp_options::pki', { 'default_value' => false })`

##### <a name="-simp_gitlab--app_pki_external_source"></a>`app_pki_external_source`

Data type: `String`

* If ``$pki`` is 'simp' or ``true``, this is the directory from which certs
  will be copied, via ``pki::copy``.

* If ``$pki`` is ``false``, this variable has no effect.

Default value: `simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' })`

##### <a name="-simp_gitlab--app_pki_dir"></a>`app_pki_dir`

Data type: `Stdlib::Absolutepath`

This variable controls the basepath of ``$app_pki_key``, ``$app_pki_cert``,
``$app_pki_ca``, ``$app_pki_ca_dir``, and ``$app_pki_crl``.

Default value: `'/etc/pki/simp_apps/gitlab/x509'`

##### <a name="-simp_gitlab--app_pki_key"></a>`app_pki_key`

Data type: `Stdlib::Absolutepath`

Full path of the private SSL key file.

Default value: `"${app_pki_dir}/private/${facts['networking']['fqdn']}.pem"`

##### <a name="-simp_gitlab--app_pki_cert"></a>`app_pki_cert`

Data type: `Stdlib::Absolutepath`

Full path of the public SSL certificate.

Default value: `"${app_pki_dir}/public/${facts['networking']['fqdn']}.pub"`

##### <a name="-simp_gitlab--app_pki_ca"></a>`app_pki_ca`

Data type: `Stdlib::Absolutepath`

Full path of the the SSL CA certificate.

Default value: `"${app_pki_dir}/cacerts/cacerts.pem"`

##### <a name="-simp_gitlab--edition"></a>`edition`

Data type: `Enum['ce','ee']`

The Gitlab Omnibus edition to install.

Default value: `'ce'`

##### <a name="-simp_gitlab--two_way_ssl_validation"></a>`two_way_ssl_validation`

Data type: `Boolean`

When ``true``, server and clients will require mutual TLS authentication.

Default value: `false`

##### <a name="-simp_gitlab--ldap_verify_certificates"></a>`ldap_verify_certificates`

Data type: `Boolean`

When ``true``, SSL LDAP connections must use certificates signed by a known
CA.

Default value: `true`

##### <a name="-simp_gitlab--ssl_verify_depth"></a>`ssl_verify_depth`

Data type: `Integer[1]`

Sets the verification depth in the client certificates chain.

Default value: `2`

##### <a name="-simp_gitlab--ssl_protocols"></a>`ssl_protocols`

Data type: `Array[String[1]]`

Array of Nginx-compatible SSL/TLS protocols for the web server to accept.

Default value: `['TLSv1.2']`

##### <a name="-simp_gitlab--gitlab_options"></a>`gitlab_options`

Data type: `Hash`

Hash of manually-customized parameters for ``puppet/gitlab``.

These parameters will be deep-merged with settings generated by this
profile.  During the deep merge, the settings in ``$gitlab_options`` will
take precedence.

Default value: `{}`

##### <a name="-simp_gitlab--cipher_suite"></a>`cipher_suite`

Data type: `Array[String[1]]`

The cipher suite to use with SSL

Default value:

```puppet
simplib::lookup( 'simp_options::openssl::cipher_suite', {
                                                                        'default_value'  => ['DEFAULT', '!MEDIUM']
                                                                      })
```

##### <a name="-simp_gitlab--ldap"></a>`ldap`

Data type: `Boolean`

If ``true``, enable LDAP support for Gitlab Omnibus.

Default value: `simplib::lookup('simp_options::ldap',          {'default_value' => false})`

##### <a name="-simp_gitlab--ldap_uri"></a>`ldap_uri`

Data type: `Array[Simplib::URI]`

List of OpenLDAP server URIs.  Note that _multiple_ URIs is an EE feature.
@example ['ldap://server1', 'ldaps://server2']

Default value: `simplib::lookup('simp_options::ldap::uri',     {'default_value' => []})`

##### <a name="-simp_gitlab--ldap_active_directory"></a>`ldap_active_directory`

Data type: `Boolean`

This setting specifies if LDAP server is Active Directory LDAP server.
For non AD servers it skips the AD specific queries.
If your LDAP server is not AD, set this to false.

Default value: `false`

##### <a name="-simp_gitlab--ldap_base_dn"></a>`ldap_base_dn`

Data type: `String[3]`

Base where we can search for users

@example ou=People,dc=gitlab,dc=example

Default value: `simplib::lookup('simp_options::ldap::base_dn', {'default_value' => simplib::ldap::domain_to_dn()})`

##### <a name="-simp_gitlab--ldap_bind_dn"></a>`ldap_bind_dn`

Data type: `String[3]`

The DN to use when binding to the LDAP server

Default value: `simplib::lookup('simp_options::ldap::bind_dn', {'default_value' => "cn=hostAuth,ou=Hosts,${ldap_base_dn}"})`

##### <a name="-simp_gitlab--ldap_bind_pw"></a>`ldap_bind_pw`

Data type: `String[1]`

The password of the bind user

Default value: `simplib::lookup('simp_options::ldap::bind_pw', {'default_value' => "cn=LDAPAdmin,ou=People,${ldap_base_dn}"})`

##### <a name="-simp_gitlab--ldap_user_filter"></a>`ldap_user_filter`

Data type: `Optional[String[1]]`

Format: RFC 4515 http://tools.ietf.org/search/rfc4515
@example (employeeType=developer)

Default value: `undef`

##### <a name="-simp_gitlab--ldap_group_base"></a>`ldap_group_base`

Data type: `Optional[String[3]]`

EE only

Default value: `undef`

##### <a name="-simp_gitlab--manage_package"></a>`manage_package`

Data type: `Boolean`

Whether to manage the gitlab-[ce,ee] package.

Default value: `true`

##### <a name="-simp_gitlab--package_ensure"></a>`package_ensure`

Data type: `String`

The ensure status of the gitlab-[ce,ee] package, when managed by
``$manage_gitlab`` is true.

Default value: `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })`

##### <a name="-simp_gitlab--set_gitlab_root_password"></a>`set_gitlab_root_password`

Data type: `Boolean`

Whether to set the GitLab root password.

* This is **HIGHLY** recommended, as the root password is not secured
  during install otherwise.  Anyone can navigate the the GitLab URL and set
  the root password.

Default value: `true`

##### <a name="-simp_gitlab--gitlab_root_password"></a>`gitlab_root_password`

Data type: `String[16]`

GitLab root password to set.

* When set via Hiera, be sure to use eyaml to secure the password.

Default value: `simplib::passgen( "simp_gitlab_${trusted['certname']}" )`

##### <a name="-simp_gitlab--rails_console_load_timeout"></a>`rails_console_load_timeout`

Data type: `Integer[60]`

Number of seconds to wait for gitlab-rails console to load when
setting the GitLab root password.

Default value: `300`

##### <a name="-simp_gitlab--allow_fips"></a>`allow_fips`

Data type: `Boolean`

Whether to allow the module to install and manage GitLab, when the
server has FIPS enabled.

* Only set this to `true` if the version of GitLab you are running
  supports FIPS mode.

Default value: `true`

## Functions

### <a name="simp_gitlab--omnibus_config--gitlab"></a>`simp_gitlab::omnibus_config::gitlab`

Type: Puppet Language

Compile a hash of settings for the ``gitlab`` class parameters, using SIMP
settings

#### `simp_gitlab::omnibus_config::gitlab()`

Compile a hash of settings for the ``gitlab`` class parameters, using SIMP
settings

Returns: `Any` Hash of `puppet/gitlab` parameters

### <a name="simp_gitlab--omnibus_config--gitlab_rails"></a>`simp_gitlab::omnibus_config::gitlab_rails`

Type: Puppet Language

Compile a hash of settings for the ``gitlab::gitlab_rails`` parameter, using
SIMP settings

#### `simp_gitlab::omnibus_config::gitlab_rails()`

Compile a hash of settings for the ``gitlab::gitlab_rails`` parameter, using
SIMP settings

Returns: `Any` Hash of settings for the 'gitlab::gitlab_rails' # parameter

### <a name="simp_gitlab--omnibus_config--gitlab_shell"></a>`simp_gitlab::omnibus_config::gitlab_shell`

Type: Puppet Language

Compile a hash of settings for the ``gitlab::shell`` parameter, using
SIMP settings

#### `simp_gitlab::omnibus_config::gitlab_shell()`

Compile a hash of settings for the ``gitlab::shell`` parameter, using
SIMP settings

Returns: `Any` Hash of settings for the 'gitlab::shell' parameter

### <a name="simp_gitlab--omnibus_config--mattermost"></a>`simp_gitlab::omnibus_config::mattermost`

Type: Puppet Language

Compile a hash of settings for the ``gitlab::mattermost`` parameter, using
SIMP settings

#### `simp_gitlab::omnibus_config::mattermost()`

Compile a hash of settings for the ``gitlab::mattermost`` parameter, using
SIMP settings

Returns: `Any` Hash of settings for the 'gitlab::mattermost' parameter

### <a name="simp_gitlab--omnibus_config--nginx"></a>`simp_gitlab::omnibus_config::nginx`

Type: Puppet Language

Compile a hash of settings for the ``gitlab::nginx`` parameter, using
SIMP settings

#### `simp_gitlab::omnibus_config::nginx()`

Compile a hash of settings for the ``gitlab::nginx`` parameter, using
SIMP settings

Returns: `Any` Hash of settings for the 'gitlab::nginx' parameter

## Data types

### <a name="Simp_Gitlab--Stroolean"></a>`Simp_Gitlab::Stroolean`

Valid PKI management options

Alias of `Variant[Enum['simp'], Boolean]`

