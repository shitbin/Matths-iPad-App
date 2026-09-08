#!/bin/sh
# Read-only preflight for a production-identity app before device OAuth QA.
# Does not sign/install, change profiles, contact a portal, or download models.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$script_dir/device_auth_signing.py" "$@"
