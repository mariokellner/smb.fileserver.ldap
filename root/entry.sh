#!/bin/sh

echo "[ENTRY] Preparing container environment"

smbpasswd -w testpw

echo "[Entry] Starting exec nmbd"
exec nmbd &

echo "[Entry] Starting avahi-daemon"
exec avahi-daemon --no-rlimits &

echo "[Entry] Starting nslcd"
exec nslcd &

echo "[Entry] Starting exec samba"
exec smbd --foreground --no-process-group --debug-stdout -d 2 &

echo "[ENTRY] Starting CMD"
echo "$@"
exec "$@"