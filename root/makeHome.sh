#!/bin/sh
set -e

USER_INFO=$(getent passwd "$2") || exit 1

UID=$(echo "$USER_INFO" | cut -d: -f3)
GID=$(echo "$USER_INFO" | cut -d: -f4)

HOME_DIR="$1/$2"

if [ ! -d "$HOME_DIR" ]; then
  mkdir -p "$HOME_DIR"
fi

chown "$UID:$GID" "$HOME_DIR"
chmod 750 "$HOME_DIR"

exit 0