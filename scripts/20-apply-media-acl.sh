#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

if ! zfs list -H -o name "${MEDIA_ZFS}" >/dev/null 2>&1; then
  echo "ERROR: Dataset does not exist: ${MEDIA_ZFS}" >&2
  echo "Run scripts/10-create-datasets.sh first." >&2
  exit 1
fi

ensure_smb_group
SMB_GID="$(group_field_by_name "${SMB_GROUP}" gid)"
if [[ -z "${SMB_GID}" ]]; then
  echo "ERROR: Could not resolve gid for group ${SMB_GROUP}." >&2
  exit 1
fi

recursive_json="$(bool_json "${APPLY_RECURSIVE}")"
traverse_json="$(bool_json "${TRAVERSE_DATASETS}")"

apply_acl_to_path() {
  local path="$1"
  echo "Applying NFSv4 ACL to ${path}"
  local payload
  payload="$(python3 - "${path}" "${SMB_GID}" "${APP_UID}" "${APP_GID}" "${recursive_json}" "${traverse_json}" <<'PY'
import json, sys
path = sys.argv[1]
smb_gid = int(sys.argv[2])
app_uid = int(sys.argv[3])
app_gid = int(sys.argv[4])
recursive = sys.argv[5].lower() == "true"
traverse = sys.argv[6].lower() == "true"
inherit = {"BASIC": "INHERIT"}
noinherit = {"BASIC": "NOINHERIT"}

def ace(tag, ident, basic, flags=inherit):
    entry = {
        "tag": tag,
        "type": "ALLOW",
        "perms": {"BASIC": basic},
        "flags": flags,
        "id": ident,
        "who": None,
    }
    return entry

# Design:
# - root owns the dataset metadata.
# - media_rw group gets modify access for SMB users.
# - apps UID/GID 568 get modify access for Jellyfin and related TrueNAS apps.
# - everyone@ only gets traverse/read of basic attributes, not data access.
dacl = [
    ace("owner@", -1, "FULL_CONTROL"),
    ace("group@", -1, "MODIFY"),
    ace("GROUP", smb_gid, "MODIFY"),
    ace("USER", app_uid, "MODIFY"),
    ace("GROUP", app_gid, "MODIFY"),
    ace("everyone@", -1, "TRAVERSE", noinherit),
]

print(json.dumps({
    "path": path,
    "dacl": dacl,
    "uid": 0,
    "gid": smb_gid,
    "acltype": "NFS4",
    "nfs41_flags": {
        "autoinherit": True,
        "protected": False,
        "defaulted": False,
    },
    "options": {
        "stripacl": False,
        "recursive": recursive,
        "traverse": traverse,
        "canonicalize": True,
        "validate_effective_acl": True,
    },
}))
PY
)"
  midclt call -job filesystem.setacl "${payload}" >/dev/null
}

# Apply to parent and every child dataset mountpoint. This avoids relying on ACL inheritance across dataset boundaries.
apply_acl_to_path "${MEDIA_PATH}"
for child in ${CHILD_DATASETS}; do
  apply_acl_to_path "${MEDIA_PATH}/${child}"
done

echo
echo "ACL summary:"
midclt call filesystem.getacl "$(python3 - "${MEDIA_PATH}" <<'PY'
import json, sys
print(json.dumps({"path": sys.argv[1], "simplified": True, "resolve_ids": True}))
PY
)"
