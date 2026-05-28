#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

fail=0

echo "Verifying datasets..."
for ds in "${MEDIA_ZFS}" $(for child in ${CHILD_DATASETS}; do echo "${MEDIA_ZFS}/${child}"; done); do
  if zfs list -H -o name "${ds}" >/dev/null 2>&1; then
    printf "  OK   %s\n" "${ds}"
  else
    printf "  FAIL %s\n" "${ds}"
    fail=1
  fi
done

echo
echo "Verifying mount path..."
if [[ -d "${MEDIA_PATH}" ]]; then
  echo "  OK   ${MEDIA_PATH}"
else
  echo "  FAIL ${MEDIA_PATH}"
  fail=1
fi

echo
echo "Verifying SMB group..."
SMB_GID="$(group_field_by_name "${SMB_GROUP}" gid)"
if [[ -n "${SMB_GID}" ]]; then
  echo "  OK   ${SMB_GROUP} gid=${SMB_GID}"
else
  echo "  FAIL ${SMB_GROUP} missing"
  fail=1
fi

echo
echo "Verifying SMB share..."
share_id="$(smb_share_field_by_name "${SMB_SHARE_NAME}" id)"
share_path="$(smb_share_field_by_name "${SMB_SHARE_NAME}" path)"
if [[ -n "${share_id}" ]]; then
  echo "  OK   ${SMB_SHARE_NAME} id=${share_id} path=${share_path}"
else
  echo "  FAIL SMB share missing: ${SMB_SHARE_NAME}"
  fail=1
fi

echo
echo "Filesystem ACL on parent dataset:"
midclt call filesystem.getacl "$(python3 - "${MEDIA_PATH}" <<'PY'
import json, sys
print(json.dumps({"path": sys.argv[1], "simplified": True, "resolve_ids": True}))
PY
)" || fail=1

echo
echo "SMB service status:"
midclt call service.query '[["service","=","cifs"]]' || true

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "Verification completed without detected failures."
else
  echo "Verification found one or more failures." >&2
fi
exit "${fail}"
