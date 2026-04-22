#!/bin/sh
# docker-entrypoint.sh

# Defaults
DEF_LDAP_AK_URI="ldap://localhost"
DEF_LDAP_BASE_DN="dc=example,dc=org"
DEF_LDAP_ADMIN_DN_USERCN="ldapservice"
DEF_LDAP_ADMIN_DN_PASSWORD="testpw"

# Initialization
echo "[ENTRY] Preparing container environment"

if [ ! -z $LDAP_AK_URI ]; then
    DEF_LDAP_AK_URI=$LDAP_AK_URI
fi
if [ ! -z $LDAP_BASE_DN ]; then
    DEF_LDAP_BASE_DN=$LDAP_BASE_DN
fi

if [ ! -z $LDAP_ADMIN_DN_PASSWORD ]; then
    DEF_LDAP_ADMIN_DN_PASSWORD=$LDAP_ADMIN_DN_PASSWORD
fi

if [ ! -z $LDAP_ADMIN_DN_USERCN ]; then
    DEF_LDAP_ADMIN_DN_USERCN=$LDAP_ADMIN_DN_USERCN
fi

echo " >> Server URL is: $DEF_LDAP_AK_URI"
echo " >> BASEDN: $DEF_LDAP_BASE_DN"
echo " >> ADMIN DN: $DEF_LDAP_ADMIN_DN_USERCN"
echo " >> PW: $DEF_LDAP_ADMIN_DN_USERCN"

# samb.cnf
sed -i 's$passdb backend = tdbsam$'"passdb backend = ldapsam:$DEF_LDAP_AK_URI"'$g' /etc/samba/smb.conf
sed -i 's$dc=example,dc=org$'"$DEF_LDAP_BASE_DN"'$g' /etc/samba/smb.conf
sed -i 's$ldap admin dn = cn=ldapservice$'"ldap admin dn = cn=$DEF_LDAP_ADMIN_DN_USERCN"'$g' /etc/samba/smb.conf

smbpasswd -w $DEF_LDAP_ADMIN_DN_PASSWORD

# nslcd.cnf
sed -i 's$uri ldap://localhost$'"uri $DEF_LDAP_AK_URI"'$g' /etc/nslcd.conf
sed -i 's$dc=example,dc=org$'"$DEF_LDAP_BASE_DN"'$g' /etc/nslcd.conf
sed -i 's$bindpw testpw$'"bindpw $LDAP_ADMIN_DN_PASSWORD"'$g' /etc/nslcd.conf
sed -i 's$binddn cn=user$'"binddn cn=$DEF_LDAP_ADMIN_DN_USERCN"'$g' /etc/nslcd.conf



## Service
echo "[Entry] Starting exec nmbd"
exec nmbd &

echo "[Entry] Starting avahi-daemon"
exec avahi-daemon --no-rlimits &

echo "[Entry] Starting nslcd"
exec nslcd &

echo "[Entry] Starting exec samba"
exec smbd --foreground --no-process-group --debug-stdout -d 3 &

echo "[ENTRY] Starting CMD"
echo "$@"
exec "$@"