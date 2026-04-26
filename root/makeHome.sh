#!/bin/sh
set -e

BASE="$1"
USER="$2"

echo ">> create $BASE/$USER"

USER_INFO=$(getent passwd "$USER") || exit 1

UID=$(echo "$USER_INFO" | cut -d: -f3)
GID=$(echo "$USER_INFO" | cut -d: -f4)

HOME_DIR="$BASE/$USER"

if [ ! -d "$HOME_DIR" ]; then
  mkdir -p "$HOME_DIR"
fi

chown "$UID:$GID" "$HOME_DIR"
chmod 750 "$HOME_DIR"

exit 0