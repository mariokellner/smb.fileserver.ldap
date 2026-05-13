#!/bin/sh
set -e
# Files 
SMBD="/etc/samba/"
SMBDF="${SMBD}smb.conf"
SMBCD="${SMBD}conf.d/"

BASEC="${SMBCD}smb.base.conf"
ENVC="${SMBCD}smb.env.conf"
SHRSC="${SMBCD}smb.shares.conf"
USRSC="${SMBCD}smb.user.conf"

AVSMBS="/etc/avahi/services/samba.service"
AVSMBC="/etc/avahi/avahi-daemon.conf"
NSLCDC="/etc/nslcd.conf"
SVC="/etc/supervisor.conf"

log() {
    printf '[Startup] %s\n' "$1"
}

startContainer() {
    # Todo: nslcd shows password cleartext
    # log "========== Final nslcd.conf ================="
    # cat $NSLCDC
    # log "========== Final nslcd.conf end ============="
    log "========== Final samba.service (avahi) ======"
    cat $AVSMBS
    log "========== Final samba.service (avahi) end =="
    log "========== Final avahi daemon ==============="
    cat $AVSMBC
    log "========== Final avahi daemon end ==========="
    log "========== Final supervisor.conf ==============="
    cat $SVC
    log "========== Final supervisor.conf end ==========="
    log "========== Final smb.conf (testparm) ========"
    if ! testparm -s; then
        log "Samba config validation failed"
        exit 1
    fi
    log  "========= Final smb.conf (testparm) end ===="
    
    log "[Entrypoint] Starting CMD => $@"
    exec "$@"
    exit 0
}

# Constants
INIT="/.init"

# Defaults (not required in docker-compose)
DEF_LDAP_USER_SUF="${LDAP_USER_SUF:-users}"
DEF_LDAP_GROUPS_SUF="${LDAP_GROUPS_SUF:-groups}"
DEF_LDAP_ACCESS_FILTER_USER="${LDAP_ACCESS_FILTER_USER:-(objectClass=user)}"
DEF_LDAP_FILTER_GROUP="${LDAP_FILTER_GROUP:-(objectClass=group)}"

log "Preparing container environment ..."

if [ -f "$INIT" ]; then
  log "Container has $INIT file (restart). Skipping script ... "
  startContainer $@
fi

# Check if variable is set
for v in \
  LDAP_AK_URI \
  LDAP_BASE_DN \
  LDAP_ADMIN_DN_USERCN \
  LDAP_ADMIN_DN_PASSWORD
do
  [ -n "$(eval echo \$$v)" ] || {
    log "Missing required env var: $v"
    log "exiting ..."
    exit 1
  }
done

#tls
case "$LDAP_AK_URI" in
  *ldaps:*)
    TLS=1
    ;;
esac

[ ! -z ${TLS} ] && SSLOPTS="On" || SSLOPTS="Off"
[ ! -z ${TLS} ] && SSLOPT="on" || SSLOPT="off"

sed -i '/<\/service-group>/d' $AVSMBS # c&p from servercontainer/samba # I still have to lookup sed documentation indepth

log "Search for Shares -- Adding to ${SHRSC} ..."
SETag="SMBSHARE_ENTRY_"

for ID in $(env | grep "^$SETag" | sed 's/=.*//' | cut -d_ -f3 | sort -u)
do
    log "Processing Share ID ${ID}"
    Selector="${SETag}${ID}_"
    Name=$ID #Default Sharename if no "name" was provided
    options="\n  browsable = yes\n  read only = no"
    
    unset ADDPREROOTSCRIPT
    unset MAKEAVAHISERVICE
    unset VOLPATH
    
    for SID in $(env | grep "^$Selector" | cut -d= -f1)
    do
        eval VALUE=\$$SID
        CONFK=$(echo "$SID" | sed "s/^$Selector//; s/_/ /g")
        if [ "${CONFK}" = "name" ]; then
            Name=$VALUE

        elif [ "${CONFK}" = "public" ]; then
            if [ "${VALUE}" = "yes" ]; then
                options=$(echo "$options\n  guest ok = yes\n  writeable = yes\n available = yes")
            fi
            
            options=$(echo "$options\n  $CONFK = $VALUE")

        elif [ "${CONFK}" = "guest ok" ]; then
            if [ "${VALUE}" = "yes" ]; then
                options=$(echo "$options\n  public = yes\n  writeable = yes\n available = yes")
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

    if [ -z ${VOLPATH+x} ]; then
        log "Required share property 'path' is missing. Set it to something like that (example):"
        echo "${Selector}path: /mnt/share$ID"
        exit 1
    fi

    # I do it here because I need the path.
    if [ ! -z ${ADDPREROOTSCRIPT+x} ]; then
        options=$(echo "$options\n\n  # this share is a homes share\n  guest ok = No\n  root preexec = /makeHome.sh $VOLPATH %U")
    fi

    if [ ! -z ${MAKEAVAHISERVICE+x} ]; then
        if [ -z $FITM ]; then
            FITM=1
            echo '<service><type>_adisk._tcp</type><txt-record>sys=waMa=0,adVF=0x100</txt-record><txt-record>dk'"$ID"'=adVN='"$Name"',adVF=0x82</txt-record></service></service-group>' >> $AVSMBS
        else # cnp from servercontainers/samba
          bappend=$(grep '<txt-record>dk' /etc/avahi/services/samba.service | tail -n 1)
          sed -i 's;'"$bappend"';'"$bappend"'<txt-record>dk'"$NUMBER"'=adVN='"$VOL_NAME"',adVF=0x82</txt-record>;g' $AVSMBS
        fi
    fi

    echo "[$Name]$options" >> $SHRSC

done

unset ID
unset Selector
unset options
unset SID
unset CONFK

# environment
log "Getting ENV globals -- Adding to ${ENVC}"
echo "[global]" >> $ENVC

GK="SMBGLOBAL_"

for GI in $(env | grep "^$GK" | cut -d= -f1)
do
    GIVAL=$(printenv "$GI")
    GIK=$(echo "$GI" | sed "s/^$GK//; s/_/ /g")

    if echo "$GIVAL" | sed 1d | grep -q .; 
    then # can be used for passing whole sections and no need for extra environment
        echo "$GIVAL" >> $ENVC
    else
        echo "$GIK = $GIVAL" >> $ENVC
    fi
done
unset GI
unset GIVAL
unset GIK

# userfile
log "Check for user defined file ..."
[ ! -f "$USRSC" ] && touch "$USRSC"

log "Setup configuration files ..."

# config files 
cat <<EOF
${T}LDAP Paramater
  >> Server URL is: $LDAP_AK_URI
  >> BASEDN: $LDAP_BASE_DN
  >> ADMIN DN: $LDAP_ADMIN_DN_USERCN
  >> TLS detected: $SSLOPTS
  >> User access filter: $DEF_LDAP_ACCESS_FILTER_USER
  >> Group filter: $DEF_LDAP_FILTER_GROUP
EOF

cat  <<EOF >> $BASEC
  
  # LDAP Base Settings
  passdb backend = ldapsam:$LDAP_AK_URI
  ldap admin dn = cn=$LDAP_ADMIN_DN_USERCN,ou=$DEF_LDAP_USER_SUF,$LDAP_BASE_DN
  ldap suffix = $LDAP_BASE_DN
  ldap user suffix = ou=$DEF_LDAP_USER_SUF
  ldap group suffix = ou=$DEF_LDAP_GROUPS_SUF
  ldap ssl = $SSLOPTS
EOF

cat <<EOF >> $NSLCDC

uri $LDAP_AK_URI
tls_reqcert never
ssl $SSLOPT

base $LDAP_BASE_DN
binddn cn=$LDAP_ADMIN_DN_USERCN,$LDAP_BASE_DN
bindpw $LDAP_ADMIN_DN_PASSWORD

base passwd ou=$DEF_LDAP_USER_SUF,$LDAP_BASE_DN
base group ou=groups,$LDAP_BASE_DN

filter passwd $DEF_LDAP_ACCESS_FILTER_USER
filter group $DEF_LDAP_FILTER_GROUP

EOF

# shortcut to set hostname in all services without configure provide each config separately
if [ ! -z $SHARENAME ]; then
    cat <<EOF >> $BASEC

  netbios aliases = $SHARENAME
  netbios name = $SHARENAME
  additional dns hostnames = $SHARENAME
EOF
    sed -i "s/command=wsdd2/command=wsdd2 -H $SHARENAME/g" $SVC
    sed -i "s/#host-name=.*/host-name=$SHARENAME/g" $AVSMBC
fi

# # shortcut to set the workgroup for all services (Actually i think all services will inerhit it from the smb.cnf, but ill leave the option here)
# if [ ! -z $WORKGROUP ]; then
#     cat <<EOF >> $BASEC

#   workgroup = $WORKGROUP
# EOF
# fi

# shortcut to set guest user information to enable that anyuser could access the share
if [ ! -z $GUEST_USERNAME ]; then    
    cat <<EOF >> $BASEC

  # GUEST Account
  guest account = $GUEST_USERNAME
  map to guest = Bad User

  # this is a service option but testparm returns it as a valid option for global section too.  
  guest ok = Yes 
EOF
fi

# debug defaults
log "Configuring debug levels ..."

SMBD_LOG_LEVEL="${SMBD_LOG_LEVEL:-1}"
NMBD_LOG_LEVEL="${NMBD_LOG_LEVEL:-1}"
NSLCD_DEBUG="${NSLCD_DEBUG:-false}"
AVAHI_DEBUG="${AVAHI_DEBUG:-false}"
WSDD2_DEBUG_LEVEL="${WSDD2_DEBUG_LEVEL:-0}"
WSDD2_FLAGS=""

i=0
while [ "$i" -lt "$WSDD2_DEBUG_LEVEL" ]
do
    WSDD2_FLAGS="${WSDD2_FLAGS}W"
    i=$((i + 1))
done

sed -i "s#command=smbd .*#command=smbd --foreground --no-process-group -d $SMBD_LOG_LEVEL --debug-stdout#g" "$SVC"
sed -i "s#command=nmbd .*#command=nmbd -i -d $NMBD_LOG_LEVEL#g" "$SVC"
[ "$NSLCD_DEBUG" = "true" ] && sed -i "s#command=nslcd .*#command=nslcd -d#g" "$SVC" || sed -i "s#command=nslcd .*#command=nslcd -n#g" "$SVC"
[ "$AVAHI_DEBUG" = "true" ] && sed -i "s#command=avahi-daemon .*#command=avahi-daemon --no-drop-root --no-rlimits --debug#g" "$SVC"
[ -n "$WSDD2_FLAGS" ] && WSDD2_FLAGS="-$WSDD2_FLAGS"
sed -i "s#command=wsdd2.*#command=wsdd2 $WSDD2_FLAGS#g" "$SVC"

# Set LDAP admin password
smbpasswd -w $LDAP_ADMIN_DN_PASSWORD

touch $INIT
startContainer $@
