#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

if [[ ! -d "${MEDIA_PATH}" ]]; then
  echo "ERROR: Path does not exist: ${MEDIA_PATH}" >&2
  echo "Run scripts/10-create-datasets.sh first." >&2
  exit 1
fi

existing_id="$(smb_share_field_by_name "${SMB_SHARE_NAME}" id)"
if [[ -n "${existing_id}" ]]; then
  echo "OK: SMB share already exists: ${SMB_SHARE_NAME} (id ${existing_id})"
else
  echo "Creating SMB share ${SMB_SHARE_NAME} for ${MEDIA_PATH}"
  payload="$(python3 - "${SMB_SHARE_NAME}" "${MEDIA_PATH}" "${SMB_PURPOSE}" "${SMB_SHARE_COMMENT}" <<'PY'
import json, sys
print(json.dumps({
    "name": sys.argv[1],
    "path": sys.argv[2],
    "purpose": sys.argv[3],
    "comment": sys.argv[4],
    "enabled": True,
    "readonly": False,
    "browsable": True,
    "access_based_share_enumeration": False,
}))
PY
)"
  midclt call sharing.smb.create "${payload}" >/dev/null
fi

echo "Starting/restarting SMB service..."
CIFS_SERVICE_ID="$(midclt call service.query '[["service","=","cifs"]]' | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')"
midclt call service.update "${CIFS_SERVICE_ID}" '{"enable": true}' >/dev/null

midclt call --job service.control START cifs '{"silent": false}' >/dev/null || \
midclt call --job service.control RESTART cifs '{"silent": false}' >/dev/null || true

echo
echo "SMB share configured. Access it as:"
echo "  \\\\$(hostname -s)\\${SMB_SHARE_NAME}"
echo "or"
echo "  smb://$(hostname -s)/${SMB_SHARE_NAME}"
echo
echo "Important: create an SMB-capable user and add it to group ${SMB_GROUP}. See docs/SMB-USERS.md."
