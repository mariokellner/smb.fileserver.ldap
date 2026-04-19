#!/bin/sh

echo "[ENTRY] Preparing container environment"

addgroup -gid 1500 smbshr
useradd --badname -M -s /sbin/nologin -g 1500 -u 1003 smbusr
echo "nobodyPassword\nnobodyPassword" | passwd smbusr
echo "nobodyPassword\nnobodyPassword" | smbpasswd smbusr

sleep 2
echo "[Entry] Starting exec samba"
exec smbd &


echo "[Entry] Starting exec nmbd"
exec nmbd &

echo "[Entry] Starting avahi-daemon"
exec avahi-daemon --no-rlimits &

echo "[Entry] Starting sssd as daemon"
exec sssd -D &

# echo "[Entry] Starting sssd"
# exec service sssd start

echo "[ENTRY] Starting CMD"
echo "$@"
exec "$@"