#!/bin/sh
set -e

CONSTPROCNUM=6 # with grep
[ $(ps aux | grep 'mbd\|nslcd\|wsdd2\|nmbd\|avahi-daemon ' | wc -l) -ge "$CONSTPROCNUM" ]
exit $