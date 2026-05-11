FROM debian:trixie-slim AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
    supervisor \
    samba libnss-ldapd libpam-ldapd samba-vfs-modules \
    avahi-daemon wsdd2 && \ 
    \
    rm -rf /usr/share/doc /usr/share/man /usr/share/info /var/cache/debconf/* /tmp/* /var/lib/apt/lists/* /var/cache/apt && \
    rm -rf /etc/samba/smb.conf /var/lib/samba/private/secrets.tdb /etc/smbldap-tools /etc/nslcd.conf /etc/nsswitch.conf && \
    sed -i 's/#enable-dbus=.*/enable-dbus=no/' /etc/avahi/avahi-daemon.conf && \
    rm -vf /etc/avahi/services/*


FROM base AS configure

COPY root /
RUN chmod +x /*.sh && chmod 600 /etc/nslcd.conf && chmod 600 /etc/nsswitch.conf

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 CMD [ "/health.sh" ]
ENTRYPOINT [ "/entry.sh" ]
CMD ["supervisord", "-c", "/etc/supervisor.conf", "-n"]
EXPOSE 137/udp 139/tcp 445/tcp 3702/udp 3702/tcp 5355/udp 5355/tcp 5353/udp 5353/tcp