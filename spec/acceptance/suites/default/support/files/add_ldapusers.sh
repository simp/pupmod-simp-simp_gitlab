# This script creates users and groups needed to test GitLab's LDAP configuration.
# Requires token substitution for LDAP_BASE_DN.

# ------------------------------------------------------------------------------
# gitlab group for users that are allowed to log into gitlab
# ------------------------------------------------------------------------------
dsidm "accounts" -b "LDAP_BASE_DN" posixgroup create --cn gitlab --gidNumber 19999

# ------------------------------------------------------------------------------
# ldapuser1 should be able to log into gitlab, because belongs to gitlab group
# ------------------------------------------------------------------------------
dsidm "accounts" -b "LDAP_BASE_DN" posixgroup create --cn ldapuser1 --gidNumber 10001
dsidm "accounts" -b "LDAP_BASE_DN" user create --cn ldapuser1 --uid ldapuser1 --displayName "Test user 1" --uidNumber 10001 --gidNumber 10001 --homeDirectory /home/ldapuser1

#suP3rP@ssw0r!
dsidm "accounts" -b "LDAP_BASE_DN" user modify ldapuser1 add:userPassword:{SSHA}r2GaizHFWY8pcHpIClU0ye7vsO4uHv/y

dsidm "accounts" -b "LDAP_BASE_DN" posixgroup modify gitlab add:member:uid=ldapuser1,ou=People,LDAP_BASE_DN


# ------------------------------------------------------------------------------
# ldapuser2 should not be able to log into gitlab, because does *not* belong to
# gitlab group
# ------------------------------------------------------------------------------
dsidm "accounts" -b "LDAP_BASE_DN" posixgroup create --cn ldapuser2 --gidNumber 10002
dsidm "accounts" -b "LDAP_BASE_DN" user create --cn ldapuser2 --uid ldapuser2 --displayName "Test User" --uidNumber 10002 --gidNumber 10002 --homeDirectory /home/ldapuser2

#suP3rP@ssw0r!
dsidm "accounts" -b "LDAP_BASE_DN" user modify ldapuser2 add:userPassword:{SSHA}r2GaizHFWY8pcHpIClU0ye7vsO4uHv/y
