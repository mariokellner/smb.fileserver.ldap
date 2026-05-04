#!/bin/sh
set -e

CONSTPROCNUM=6
[ $(ps aux | grep 'mbd\|nslcd\|wsdd2\|nmbd\|avahi-daemon ' | wc -l) -ge "$CONSTPROCNUM" ]
exit $