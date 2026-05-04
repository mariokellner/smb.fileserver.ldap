FROM debian:bookworm-slim AS builder

RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y supervisor samba libnss-ldapd libnss-mdns libpam-ldapd avahi-daemon samba-vfs-modules wsdd2 && \ 
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt && \
    rm -rf /etc/samba/smb.conf /var/lib/samba/private/secrets.tdb /etc/smbldap-tools /etc/nslcd.conf /etc/nsswitch.conf && \
    sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf && \
    rm -vf /etc/avahi/services/* &&\
    mkdir -p /external/avahi && \
    touch /external/avahi/not-mounted

FROM builder AS configure

COPY root /
RUN chmod +x /*.sh && chmod 600 /etc/nslcd.conf && chmod 600 /etc/nsswitch.conf

HEALTHCHECK CMD [ "/health.sh" ]
ENTRYPOINT [ "/entry.sh" ]
CMD ["supervisord", "-c", "/etc/supervisor.conf", "-n"]
EXPOSE 137/udp 139/tcp 445/tcp 3702/udp 3702/tcp 5355/udp 5355/tcp 5353/udp 5353/tcp