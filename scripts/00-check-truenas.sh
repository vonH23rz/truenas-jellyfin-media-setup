#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

print_config_summary

echo
echo "Checking TrueNAS middleware availability..."
midclt call system.version >/dev/null
midclt call system.ready >/dev/null

echo "Checking pool exists: ${POOL}"
if ! zfs list -H -o name "${POOL}" >/dev/null 2>&1; then
  echo "ERROR: ZFS pool not found: ${POOL}" >&2
  echo "Create or import the pool first, or edit media-setup.conf." >&2
  exit 1
fi

echo "Checking apps user/group IDs..."
if getent passwd "${APP_UID}" >/dev/null 2>&1; then
  echo "OK: App UID ${APP_UID}: $(getent passwd "${APP_UID}" | cut -d: -f1)"
else
  echo "WARN: UID ${APP_UID} not found locally. This may be fine on some versions, but verify Jellyfin's configured run user."
fi
if getent group "${APP_GID}" >/dev/null 2>&1; then
  echo "OK: App GID ${APP_GID}: $(getent group "${APP_GID}" | cut -d: -f1)"
else
  echo "WARN: GID ${APP_GID} not found locally. This may be fine on some versions, but verify Jellyfin's configured run group."
fi

echo
echo "Preflight OK."
