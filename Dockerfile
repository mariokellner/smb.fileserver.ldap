FROM debian:bookworm-slim

ENV NODE_ENV=production \
    PORT=3000 \
    USER=node

RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y samba sssd sssd-ldap libnss-sss libnss-mdns libpam-sss ldap-utils krb5-user avahi-daemon tzdata runit wsdd2 && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt && \
    rm -rf /etc/samba/smb.conf /var/lib/samba/private/secrets.tdb /etc/smbldap-tools /etc/nslcd.conf /etc/nsswitch.conf && \
    sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf && \
    rm -vf /etc/avahi/services/* &&\
    mkdir -p /external/avahi && \
    touch /external/avahi/not-mounted 

COPY root /
RUN chmod +x /entry.sh

EXPOSE 137/udp 139 445

ENTRYPOINT [ "/entry.sh" ]
CMD ["tail", "-f", "/dev/null" ]