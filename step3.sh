# Become root
sudo bash <<"EOF"

. /etc/univention/ucr_master

# Install SSSD based configuration
DEBIAN_FRONTEND=noninteractive apt-get -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

# Create sssd.conf
cat >/etc/sssd/sssd.conf <<__EOF__
[sssd]
config_file_version = 2
reconnection_retries = 3
sbus_timeout = 30
services = nss, pam, sudo
domains = $kerberos_realm

[nss]
reconnection_retries = 3

[pam]
reconnection_retries = 3

[domain/$kerberos_realm]
auth_provider = krb5
krb5_kdcip = ${master_ip}
krb5_realm = ${kerberos_realm}
krb5_server = ${ldap_master}
krb5_kpasswd = ${ldap_master}
id_provider = ldap
ldap_uri = ldap://${ldap_master}:7389
ldap_search_base = ${ldap_base}
ldap_tls_reqcert = never
ldap_tls_cacert = /etc/univention/ssl/ucsCA/CAcert.pem
cache_credentials = true
enumerate = true
ldap_default_bind_dn = cn=$(hostname),cn=computers,${ldap_base}
ldap_default_authtok_type = password
ldap_default_authtok = $(cat /etc/ldap.secret)
__EOF__
chmod 600 /etc/sssd/sssd.conf

# Install auth-client-config
DEBIAN_FRONTEND=noninteractive apt-get -y install auth-client-config

# Create an auth config profile for sssd
cat >/etc/auth-client-config/profile.d/sss <<__EOF__
[sss]
nss_passwd=   passwd:   compat sss
nss_group=    group:    compat sss
nss_shadow=   shadow:   compat
nss_netgroup= netgroup: nis

pam_auth=
        auth [success=3 default=ignore] pam_unix.so nullok_secure try_first_pass
        auth requisite pam_succeed_if.so uid >= 500 quiet
        auth [success=1 default=ignore] pam_sss.so use_first_pass
        auth requisite pam_deny.so
        auth required pam_permit.so

pam_account=
        account required pam_unix.so
        account sufficient pam_localuser.so
        account sufficient pam_succeed_if.so uid < 500 quiet
        account [default=bad success=ok user_unknown=ignore] pam_sss.so
        account required pam_permit.so

pam_password=
        password requisite pam_pwquality.so retry=3
        password sufficient pam_unix.so obscure sha512
        password sufficient pam_sss.so use_authtok
        password required pam_deny.so

pam_session=
        session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
        session optional pam_keyinit.so revoke
        session required pam_limits.so
        session [success=1 default=ignore] pam_sss.so
        session required pam_unix.so
__EOF__
auth-client-config -a -p sss

# Restart sssd
service sssd restart

EOF
