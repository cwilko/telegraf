#!/bin/sh
set -e

if [ "$(printf '%.1s' "$1")" = '-' ]; then
    set -- telegraf "$@"
fi

exec "$@"