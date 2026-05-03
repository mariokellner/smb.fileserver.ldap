#!/bin/sh

# Files 
SMBD=/etc/samba/
SMBDF=${SMBD}smb.conf
SMBDFI=${SMBD}includes.conf
SMBCD=${SMBD}conf.d/
BASEC=${SMBCD}smb.base.conf
ENVC=${SMBCD}smb.env.conf
SHRSC=${SMBCD}smb.shares.conf
USRSC=${SMBCD}smb.user.conf
AVSMBS="/etc/avahi/services/samba.service"

# Constants
T="[Startup] "
ET="[Entrypoint] "

IF=/.init

# Defaults
DEF_LDAP_AK_URI="ldap://localhost"
DEF_LDAP_BASE_DN="dc=example,dc=org"
DEF_LDAP_ADMIN_DN_USERCN="ldapservice"
DEF_LDAP_ADMIN_DN_PASSWORD="testpw"
DEF_LDAP_USER_SUF="users"
DEF_LDAP_GROUPS_SUF="groups"
DEF_LDAP_ACCESS_FILTER_USER="(&(objectClass=user)(memberOf=cn=smbshr,ou=groups,dc=kelfam,dc=de))"

cat <<EOF
INFO:
  This this samba container is mainly used for ldapsam
  in conjunction with a modified ldap provider from authentik. 

  Repo: https://github.com/mariokellner/authentik-ldap-samba-mod

  Therefore it expects some ldap defaults. Use this only if you plan to enable LDAP auth.
  NO pw change within samba possible!
  For a more valid and general setup use: https://github.com/ServerContainers/samba

EOF

echo "${T}Preparing container environment"

# Initialization
sed -i '/<\/service-group>/d' $AVSMBS

echo "${T}Search for Shares -- Adding to ${SHRSC} ..."
for ID in $(env | grep '^SMBSHARE_ENTRY_' | sed 's/=.*//' | cut -d_ -f3 | sort -u)
do
    echo "${T}Processing Share ID ${ID}"
    Selector="SMBSHARE_ENTRY_${ID}_"
    Name=$ID
    options="\n  browsable = yes\n  read only = no"
    VOLPATH=""
    unset ADDPREROOTSCRIPT
    unset MAKEAVAHISERVICE
    
    for SID in $(env | grep "^$Selector" | cut -d= -f1)
    do
        eval VALUE=\$$SID
        CONFK=$(echo "$SID" | sed "s/^$Selector//; s/_/ /g")
        if [ "${CONFK}" = "name" ]; then
            Name=$VALUE

        elif [ "${CONFK}" = "public" ]; then
            if [ "${VALUE}" = "yes" ]; then
                options=$(echo "$options\n  guest ok = yes\n  read only = no\n  writeable = yes\n available = yes")
            fi
            
            options=$(echo "$options\n  $CONFK = $VALUE")

        elif [ "${CONFK}" = "guest ok" ]; then
            if [ "${VALUE}" = "yes" ]; then
                options=$(echo "$options\n  public = yes\n  read only = no\n  writeable = yes\n available = yes")
            fi
            
            options=$(echo "$options\n  $CONFK = $VALUE")

        elif [ "${CONFK}" = "timemachine" ]; then
            if [ "${VALUE}" = "yes" ];  then
                options=$(echo "$options\n\n  # timeCapsule is active\n  posix locking = no\n  inherit acls = yes")
                MAKEAVAHISERVICE=1
            fi

        elif [ "${CONFK}" = "path" ]; then
            VOLPATH=${VALUE}
            options=$(echo "$options\n  ${CONFK} = ${VALUE}")

        elif [ "${CONFK}" = "homes" ]; then
            ADDPREROOTSCRIPT=1
        
        else 
            options=$(echo "$options\n  $CONFK = $VALUE")

        fi
    done

    # I do it here because I need the path.
    if [ ! -z ${ADDPREROOTSCRIPT+x} ]; then
        options=$(echo "$options\n\n  # this share is a homes share\n  guest ok = No\n  root preexec = /makeHome.sh $VOLPATH %U")
    fi

    if [ ! -z ${MAKEAVAHISERVICE+x} ]; then
        if [ -z $FITM ]; then
            FITM=1
            echo '<service><type>_adisk._tcp</type><txt-record>sys=waMa=0,adVF=0x100</txt-record><txt-record>dk'"$ID"'=adVN='"$Name"',adVF=0x82</txt-record></service></service-group>' >> $AVSMBS
        else
          bappend=$(grep '<txt-record>dk' /etc/avahi/services/samba.service | tail -n 1)
          sed -i 's;'"$bappend"';'"$bappend"'<txt-record>dk'"$NUMBER"'=adVN='"$VOL_NAME"',adVF=0x82</txt-record>;g' $AVSMBS
        fi
    fi

    echo "[$Name]$options" >> $SHRSC

done

# Initialization
echo "${T}Getting ENV globals -- Adding to ${ENVC}"
echo "[global]" >> $ENVC
GK="SMBGLOBAL_"

for GI in $(env | grep "^$GK" | cut -d= -f1)
do
    eval VALUE=\$$GI
    CONF_KEY=$(echo "$GI" | sed "s/^$GK//; s/_/ /g")

    if echo "$VALUE" | sed 1d | grep -q .; 
    then # can be used for passing whole sections and no need for extra environment
        echo "$VALUE" >> $ENVC
    else
        echo "$CONF_KEY = $VALUE" >> $ENVC
    fi
done

echo "${T}Check for user defined file ..."

[ ! -f "$USRSC" ] && touch "$USRSC"

echo "${T}Setup other modules ..."

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

if [ "${DEF_LDAP_AK_URI}" = *"ldaps:"* ]; then
    DEF_LDAP_TLS=0
fi


cat <<EOF
LDAP Pamater
  >> Server URL is: $DEF_LDAP_AK_URI
  >> BASEDN: $DEF_LDAP_BASE_DN
  >> ADMIN DN: $DEF_LDAP_ADMIN_DN_USERCN
  >> PW: $DEF_LDAP_ADMIN_DN_USERCN
EOF

[ ! -z ${DEF_LDAP_TLS} ] && SSLOPTS="On" || SSLOPTS="Off"
[ ! -z ${DEF_LDAP_TLS} ] && SSLOPT="on" || SSLOPT="off"

cat  <<EOF >> /etc/samba/conf.d/smb.base.conf
  
  # LDAP Base Settings
  passdb backend = ldapsam:$DEF_LDAP_AK_URI
  ldap admin dn = cn=$DEF_LDAP_ADMIN_DN_USERCN,ou=$DEF_LDAP_USER_SUF,$DEF_LDAP_BASE_DN
  ldap suffix = $DEF_LDAP_BASE_DN
  ldap user suffix = ou=$DEF_LDAP_USER_SUF
  ldap group suffix = ou=$DEF_LDAP_GROUPS_SUF
  ldap ssl = $SSLOPTS

EOF

# nslcd.cnf
cat <<EOF >>/etc/nslcd.conf
uri $DEF_LDAP_AK_URI
tls_reqcert never
ssl $SSLOPT

base $DEF_LDAP_BASE_DN
binddn cn=$DEF_LDAP_ADMIN_DN_USERCN,$DEF_LDAP_BASE_DN
bindpw $DEF_LDAP_ADMIN_DN_PASSWORD

base passwd ou=$DEF_LDAP_USER_SUF,$DEF_LDAP_BASE_DN
base group ou=groups,$DEF_LDAP_BASE_DN

filter passwd $DEF_LDAP_ACCESS_FILTER_USER

EOF

if [ ! -z $SHARENAME ]; then
    cat <<EOF >> /etc/samba/conf.d/smb.base.conf
  netbios name = $SHARENAME
  additional dns hostnames =  $SHARENAME
  
EOF
    sed -i "s/command=wsdd2/command=wsdd2 -H $SHARENAME/g" /etc/supervisor.conf
    sed -i "s/#host-name=.*/host-name=$SHARENAME/g" /etc/avahi/avahi-daemon.conf
fi

if [ ! -z $WORKGROUP ]; then
    cat <<EOF >> /etc/samba/conf.d/smb.base.conf
        
  workgroup = $WORKGROUP

EOF
fi

if [ ! -z $GUEST_USERNAME ]; then    
    cat <<EOF >> /etc/samba/conf.d/smb.base.conf

      # GUEST 
      guest account = $GUEST_USERNAME
      map to guest = Bad User
      
      # this is a service option but testparm returns it as a valid option for global section too.  
      guest ok = Yes 

EOF

fi


smbpasswd -w $DEF_LDAP_ADMIN_DN_PASSWORD

# cat "${BASEC}"
echo "${T} ======= Final conf ======="
testparm -s
echo  "${T} ===== Final  End ====="
echo "\\${ET}Starting CMD => $@"
exec "$@"