#!/bin/sh

FAILED=0

check_proc() {
    NAME="$1"

    if ! pgrep -x "$NAME" >/dev/null 2>&1; then
        echo "[Healthcheck] Missing process: $NAME"
        FAILED=1
    fi
}

check_proc smbd
check_proc nmbd
check_proc nslcd
check_proc wsdd2
check_proc avahi-daemon

if [ "$FAILED" -ne 0 ]; then
    echo "[Healthcheck] FAILED"
    exit 1
fi

echo "[Healthcheck] OK"
exit 0