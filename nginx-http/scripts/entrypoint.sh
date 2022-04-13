#!/bin/bash
set -eu

sh -c "/logo-switcher.sh"

exec "$@"
