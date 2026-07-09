# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-simp_gitlab` is a SIMP **profile** module that wraps and hardens the
community `puppet/gitlab` (GitLab Omnibus) module for use inside the SIMP
ecosystem. On its own, `puppet/gitlab` installs and configures a GitLab Omnibus
instance; `simp_gitlab` sits in front of it and layers on the SIMP-managed
security subsystems: PKI/TLS certificate distribution, host firewalling via
`simp/iptables`, PAM access control for the GitLab SSH user, an NGINX
IP-allowlist, time sync (`chrony`), mail relay (`postfix`), and OpenSSH
integration (`ssh`).

Like most SIMP profiles, the module is designed to run inside a full SIMP
deployment but can be used independently: when standalone, the SIMP security
subsystems are opt-in and default to *off* — you must explicitly enable them via
parameters such as `$trusted_nets`, `$pki`, and `$firewall`
(`manifests/init.pp`).

The core of the module is a translation layer: it reads SIMP conventions
(`simp_options::*` Hiera keys, SIMP PKI paths, SIMP netlists) and compiles them
into the parameter hash that `puppet/gitlab` expects, then deep-merges any
operator overrides on top (`manifests/init.pp`,
`functions/omnibus_config/gitlab.pp`).

### Business logic

The public entry class is `simp_gitlab`; everything else is a private
(`assert_private()`) sub-class or a `simp_gitlab::omnibus_config::*` function.

- **`simp_gitlab` (`manifests/init.pp`)** — Public entry class
  (consumers `include 'simp_gitlab'`; it is *not* `assert_private()`'d). It calls
  `simplib::assert_metadata($module_name)` (`init.pp`) and then:
  - **FIPS guard (`init.pp`)**: if `$facts['fips_enabled']` is true and
    `$allow_fips` is false, it `fail()`s with "GitLab does not support FIPS
    mode". `$allow_fips` defaults to `true` (`init.pp`), so by default the
    module *proceeds* under FIPS — only set `$allow_fips => false` to hard-block.
  - **Calculated variables (`init.pp`)**: derives the GitLab SSH user,
    home, and authorized-keys path from `$gitlab_options` via `pick()`/`dig()`
    (defaulting to `git`, `/var/opt/gitlab`, `<home>/.ssh/authorized_keys`), and
    builds `$merged_gitlab_options` by `deep_merge`ing
    `simp_gitlab::omnibus_config::gitlab()` (the SIMP-computed defaults) with the
    operator-supplied `$gitlab_options` — operator values win.
  - **Class ordering (`init.pp`)**: unconditionally `include`s `chrony`,
    `postfix`, `ssh`, `simp_gitlab::install`, and `simp_gitlab::config`, then
    pins the chain
    `chrony -> simp_gitlab::install -> simp_gitlab::config -> postfix`.
  - **PKI branch (`init.pp`)**: when `$pki` is truthy (`'simp'` or
    `true`), `include`s `simp_gitlab::config::pki` and wires
    `simp_gitlab::config::pki ~> gitlab::service` so new certs trigger a
    `gitlab-ctl reconfigure`.
  - **Firewall branch (`init.pp`)**: when `$firewall` is true, `include`s
    `simp_gitlab::config::firewall` and orders it *before*
    `simp_gitlab::install` — the comment notes install brings up a live GitLab,
    so the firewall must already be in place.

  Standard SIMP profile ordering is therefore
  `init -> install -> config`, with `config::pki` and `config::firewall` hung off
  that chain conditionally.

- **`simp_gitlab::install` (`manifests/install.pp`, private)** — the real
  installer. It renders the NGINX IP-allowlist
  (`simp_gitlab/etc/nginx/http_access_list.conf.epp`) from `$trusted_nets` /
  `$denied_nets` into `/etc/gitlab/nginx/conf.d/http_access_list.conf`
  (`install.pp`); forces the *standard* `AuthorizedKeysFile` path for the
  GitLab SSH user via `sshd_config` because GitLab's Chef recipes and Puppet
  cannot both manage the SIMP-customized SSH key path (`install.pp`);
  declares `class { 'gitlab': * => $simp_gitlab::merged_gitlab_options }`
  (`install.pp`); and adds `svckill::ignore { 'gitlab-runsvdir' }` so
  svckill does not reap the runit supervisor when `gitlab::service` is unmanaged
  (`install.pp`).

- **`simp_gitlab::config` (`manifests/config.pp`, private)** — post-install
  configuration. Adds a `pam::access::rule` permitting the GitLab SSH user from
  the trusted nets (rewriting a leading `127.0.0.1` to the PAM `LOCAL` token,
  `config.pp`); installs the `/usr/local/sbin/change_gitlab_root_password`
  helper (`config.pp`); and, when `$set_gitlab_root_password` is true
  (default), runs that helper via an `exec` guarded by
  `creates => /etc/gitlab/.root_password_set`, ordered after `gitlab::service`
  (`config.pp`). The Puppet `timeout` is deliberately set to
  `$rails_console_load_timeout + 60` so Puppet outlasts the script.

- **`simp_gitlab::config::firewall`
  (`manifests/config/firewall.pp`, private)** — a single
  `iptables::listen::tcp_stateful` opening `$tcp_listen_port` to `$trusted_nets`.

- **`simp_gitlab::config::pki` (`manifests/config/pki.pp`, private)** —
  distributes certs via `pki::copy { 'gitlab' }` into
  `/etc/pki/simp_apps/gitlab/x509` and syncs trusted CAs into
  `/etc/gitlab/trusted-certs` with `pki_cert_sync` (`purge => true`,
  `generate_pem_hash_links => false` because `gitlab-ctl reconfigure` generates
  the PEM hash links itself). It also contains a documented Let's Encrypt
  workaround: when `letsencrypt.enable` is set in the merged options, it uses a
  resource collector to override the `public` PKI directory to mode `0644` to
  stop permission flapping between the GitLab recipe and `pki::copy`
  (`config/pki.pp`).

- **`simp_gitlab::omnibus_config::*` functions
  (`functions/omnibus_config/*.pp`)** — five Puppet-language functions
  (`gitlab`, `gitlab_rails`, `gitlab_shell`, `mattermost`, `nginx`) that compute
  the `puppet/gitlab` parameter hash from SIMP settings. `gitlab()` is the top
  entry point (`init.pp`); notably it rewrites the `external_url` to embed a
  non-standard `$tcp_listen_port` because Omnibus requires the port in the URL
  for HTTPS (`functions/omnibus_config/gitlab.pp`).

### Gotchas / non-obvious details

- **This is a profile, not the installer.** GitLab itself is installed and
  configured by `puppet/gitlab`; `simp_gitlab` only computes its parameters and
  layers SIMP hardening around it. Behavioral GitLab bugs usually belong to
  `puppet/gitlab` or the Omnibus recipes, not here.
- **The SIMP subsystems are opt-in.** `$firewall`, `$ldap`, and `$pki` all
  default from `simp_options::*` with a fallback of `false`
  (`init.pp`); `$trusted_nets` defaults to `['127.0.0.1/32']`
  (`init.pp`). A bare `include simp_gitlab` will *not* open a firewall port
  or manage certs unless those toggles are set.
- **`$pki` is tri-state, not boolean.** Its type is `Simp_gitlab::Stroolean`
  = `Variant[Enum['simp'], Boolean]` (`types/stroolean.pp`). `'simp'` includes
  `simp/pki` and copies certs; `true` copies certs but does *not* include
  `simp/pki`; `false` disables cert management entirely (docstring at
  `init.pp`). Several defaults (`$external_url`, `$tcp_listen_port`) branch
  on all three values (`init.pp`).
- **`$allow_fips` defaults to `true`.** Under FIPS the module proceeds by
  default; it only fails hard when an operator explicitly sets
  `$allow_fips => false` (`init.pp`). Do not assume FIPS is blocked.
- **Firewall is ordered before install on purpose.** `config::firewall` runs
  *before* `install` (`init.pp`) so the port is filtered before GitLab comes
  up live — reversing this would briefly expose an unfirewalled instance.
- **The root password exec is idempotent by marker file.**
  `set_gitlab_root_password` only runs while `/etc/gitlab/.root_password_set` is
  absent (`config.pp`); deleting that file re-triggers it.
- **`gitlab_root_password` is auto-generated if unset** via
  `simplib::passgen("simp_gitlab_${trusted['certname']}")` (`init.pp`) — it
  is per-host and stored in the passgen backend, not hard-coded.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  the manifests consume the `simp_options::*` seam via `simplib::lookup`
  (the function ships in `simp/simplib`). Treat the seam as provided by
  `simplib`, not by a `simp_options` runtime dep.
- **The EPP template path uses the module namespace, not the filesystem path.**
  `install.pp` references `simp_gitlab/etc/nginx/http_access_list.conf.epp`,
  which resolves to `templates/etc/nginx/http_access_list.conf.epp`.
- **`config::pki` reaches into merged options.** Its Let's Encrypt branch reads
  `$simp_gitlab::merged_gitlab_options['letsencrypt']['enable']`
  (`config/pki.pp`), so that key must survive the deep-merge — a nil
  `letsencrypt` hash would raise at compile time.

## The `simp_options` / `simplib::lookup` seam

This is the module's real SIMP-integration seam — the natural target for a
lookup-path unit test. All calls are in `manifests/init.pp` (class parameter
defaults):

| File | Key | `default_value` |
|------|-----|-----------------|
| `init.pp` | `simp_options::trusted_nets` | `['127.0.0.1/32']` |
| `init.pp` | `simp_options::pki` | `false` |
| `init.pp` | `simp_options::firewall` | `false` |
| `init.pp` | `simp_options::ldap` | `false` |
| `init.pp` | `simp_options::ldap::uri` | `[]` |
| `init.pp` | `simp_options::ldap::base_dn` | `simplib::ldap::domain_to_dn()` |
| `init.pp` | `simp_options::ldap::bind_dn` | `"cn=hostAuth,ou=Hosts,${ldap_base_dn}"` |
| `init.pp` | `simp_options::ldap::bind_pw` | `"cn=LDAPAdmin,ou=People,${ldap_base_dn}"` |
| `init.pp` | `simp_options::pki::source` | `'/etc/pki/simp/x509'` |
| `init.pp` | `simp_options::openssl::cipher_suite` | `['DEFAULT', '!MEDIUM']` |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json`, 11 total):

- `puppet/chrony` `>= 1.0.0 < 4.0.0` (time sync; `include 'chrony'`)
- `puppet/augeasproviders_ssh` `>= 2.5.0 < 7.0.0` (the `sshd_config` type used
  in `install.pp`)
- `puppet/gitlab` `>= 6.0.1 < 10.0.0` (the wrapped Omnibus module — the `gitlab`
  class this profile configures)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (`deep_merge`, `pick`, etc.)
- `simp/iptables` `>= 6.5.3 < 8.0.0` (`iptables::listen::tcp_stateful`)
- `simp/pam` `>= 6.8.3 < 8.0.0` (`pam::access::rule`)
- `simp/pki` `>= 6.2.0 < 7.0.0` (`pki::copy`, `pki_cert_sync`)
- `simp/postfix` `>= 5.5.0 < 6.0.0` (`include 'postfix'`)
- `simp/simplib` `>= 4.9.0 < 5.0.0` (`simplib::lookup`,
  `simplib::assert_metadata`, `simplib::passgen`, `simplib::ldap::domain_to_dn`,
  and the `Simplib::*` data types)
- `simp/ssh` `>= 6.11.0 < 7.0.0` (`include 'ssh'`)
- `simp/svckill` `>= 3.6.1 < 4.0.0` (`svckill::ignore`)

There are **no optional dependencies** (`metadata.json` has no
`simp.optional_dependencies`).

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0`. This is an **old baseline** and still names **puppet**. (SIMP
is migrating Puppet → OpenVox; when `metadata.json` switches this to `openvox`,
update this line to match.)

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `manifests/init.pp` — public `simp_gitlab` class: parameters, the SIMP →
  Omnibus translation, the FIPS guard, and class ordering.
- `manifests/install.pp` — private `simp_gitlab::install`: NGINX allowlist,
  SSH key path fix, `class { 'gitlab' }`, svckill ignore.
- `manifests/config.pp` — private `simp_gitlab::config`: PAM access rule and the
  root-password exec/helper.
- `manifests/config/firewall.pp` — private `simp_gitlab::config::firewall`: the
  iptables rule.
- `manifests/config/pki.pp` — private `simp_gitlab::config::pki`: cert copy,
  trusted-CA sync, and the Let's Encrypt permission workaround.
- `functions/omnibus_config/*.pp` — five Puppet functions (`gitlab`,
  `gitlab_rails`, `gitlab_shell`, `mattermost`, `nginx`) computing the
  `puppet/gitlab` parameter hash from SIMP settings.
- `types/stroolean.pp` — the `Simp_gitlab::Stroolean` data type
  (`Variant[Enum['simp'], Boolean]`) used by `$pki`.
- `templates/etc/nginx/http_access_list.conf.epp` — NGINX IP-allowlist template.
- `files/usr/local/sbin/change_gitlab_root_password` — the root-password helper
  script installed by `config.pp`.
- `metadata.json` — deps, OS matrix, Puppet requirement.
- `spec/classes/` — rspec-puppet unit tests; `spec/acceptance/` — beaker
  acceptance suites and nodesets.
- `REFERENCE.md` — generated Puppet Strings reference.
- No `data/` or `hiera.yaml` — this module ships **no module-level Hiera data**;
  all defaults live in the manifest parameter list and the `simp_options::*`
  seam. No `lib/` — it has no Ruby types/providers/functions/facts; every custom
  type, function, and provider it uses comes from the dependencies above.
- **`assert_private()`** is called in the four private classes —
  `manifests/config.pp`, `manifests/install.pp`,
  `manifests/config/firewall.pp`, and `manifests/config/pki.pp`. `init.pp`
  is the public entry class and is not private.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class spec
bundle exec rspec spec/classes/init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
bundle exec puppet strings generate --format markdown --out REFERENCE.md

# Run a beaker acceptance suite (run manually — see note below)
bundle exec rake beaker:suites[default]
```

**Acceptance is NOT run in CI.** `.github/workflows/pr_tests.yml` defines only
the standard six jobs — `puppet-syntax`, `puppet-style`, `ruby-style`,
`file-checks`, `releng-checks`, and `spec-tests` — with no `acceptance` job. The
shipped nodesets are run manually. Nodesets in `spec/acceptance/nodesets/`:
`centos-7-x86_64.yml`, `centos-8-x86_64.yml`, `oel-7-x86_64.yml`,
`oel-8-x86_64.yml`, and `default.yml`.

Relevant gem pins (from `Gemfile`): `rubocop ~> 1.88.0`,
`puppetlabs_spec_helper ~> 8.0.0`, `simp-rake-helpers ~> 5.24.0`, `simp-beaker-helpers ~> 2.0.0`. The `Gemfile` installs the
**puppet** gem only (`gem 'puppet', puppet_version`) — no OpenVox — and
`puppet_version` defaults to `['>= 7', '< 9']`. `spec/spec_helper.rb`
requires `puppetlabs_spec_helper/module_spec_helper`.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on the public
  class — they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing
  docs or parameters.
- Keep `assert_private()` at the top of every non-`init` class; only
  `simp_gitlab` is meant to be `include`d directly.
- Compute `puppet/gitlab` settings in the `simp_gitlab::omnibus_config::*`
  functions and deep-merge operator overrides on top (operator wins) — don't
  hard-code Omnibus config in the manifests.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` rather than
  assuming `simp_options` is included.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in `manifests/init.pp`.
