FROM bitnami/minideb AS builder

RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y samba libnss-mdns \
    libnss-ldapd ldap-utils libpam-ldapd \ 
    krb5-user avahi-daemon wsdd2 \
    # tzdata runit \
    && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt && \
    rm -rf /etc/samba/smb.conf /var/lib/samba/private/secrets.tdb /etc/smbldap-tools /etc/nslcd.conf /etc/nsswitch.conf && \
    sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf && \
    rm -vf /etc/avahi/services/* &&\
    mkdir -p /external/avahi && \
    touch /external/avahi/not-mounted


FROM builder AS configure
# building on windows has issues with cache invalidations so I need to use separete states to benefit from cache without rebuild it completely
# with that i can use no-cache-filter

COPY root /
RUN chmod +x /entry.sh && \
    chmod +x /createUserDirs.sh && \
    chmod 600 /etc/nslcd.conf && \
    chmod 600 /etc/nsswitch.conf

EXPOSE 137/udp 139 445

ENTRYPOINT [ "/entry.sh" ]
# TODO (mario): kein tail -f nutzen
CMD ["tail", "-f", "/dev/null" ]