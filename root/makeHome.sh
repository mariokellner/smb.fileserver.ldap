#!/bin/sh
set -e

USER_INFO=$(getent passwd "$2") || exit 1

UID=$(echo "$USER_INFO" | cut -d: -f3)
GID=$(echo "$USER_INFO" | cut -d: -f4)

[ ! -d "$1" ] && mkdir -p "$1"

chown "$UID:$GID" "$1"
chmod 750 "$1"

exit 0