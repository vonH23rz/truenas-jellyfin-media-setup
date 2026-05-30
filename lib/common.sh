#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${REPO_DIR}/media-setup.conf}"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
elif [[ -f "${REPO_DIR}/media-setup.conf.example" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_DIR}/media-setup.conf.example"
else
  echo "ERROR: No config file found." >&2
  exit 1
fi

POOL="${POOL:-tank}"
MEDIA_DATASET="${MEDIA_DATASET:-media}"
CHILD_DATASETS="${CHILD_DATASETS:-movies tv downloads anime kids xxx music}"
DATASET_SHARE_TYPE="${DATASET_SHARE_TYPE:-MULTIPROTOCOL}"
SMB_SHARE_NAME="${SMB_SHARE_NAME:-media}"
SMB_SHARE_COMMENT="${SMB_SHARE_COMMENT:-Jellyfin media library}"
SMB_PURPOSE="${SMB_PURPOSE:-MULTIPROTOCOL_SHARE}"
SMB_GROUP="${SMB_GROUP:-media_rw}"
APP_UID="${APP_UID:-568}"
APP_GID="${APP_GID:-568}"
APPLY_RECURSIVE="${APPLY_RECURSIVE:-false}"
TRAVERSE_DATASETS="${TRAVERSE_DATASETS:-false}"
ALLOW_EXISTING_DATASETS="${ALLOW_EXISTING_DATASETS:-true}"

MEDIA_ZFS="${POOL}/${MEDIA_DATASET}"
MEDIA_PATH="/mnt/${POOL}/${MEDIA_DATASET}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root on the TrueNAS SCALE host." >&2
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${cmd}" >&2
    exit 1
  fi
}

require_truenas_tools() {
  require_cmd midclt
  require_cmd zfs
  require_cmd python3
}

json_filter_eq() {
  python3 - "$1" "$2" <<'PY'
import json, sys
print(json.dumps([[sys.argv[1], "=", sys.argv[2]]]))
PY
}

json_first_field() {
  local field="$1"
  python3 -c '
import json, sys
field = sys.argv[1]
data = json.load(sys.stdin)
if not data:
    print("")
else:
    val = data[0]
    for part in field.split("."):
        val = val.get(part, "") if isinstance(val, dict) else ""
    print("" if val is None else val)
' "$field"
}

bool_json() {
  case "${1,,}" in
    true|yes|1|on) echo true ;;
    false|no|0|off) echo false ;;
    *) echo "ERROR: Invalid boolean value: $1" >&2; exit 1 ;;
  esac
}

group_json_by_name() {
  local filter
  filter="$(json_filter_eq name "$1")"
  midclt call group.query "${filter}"
}

group_field_by_name() {
  local group_name="$1"
  local field="$2"
  group_json_by_name "${group_name}" | json_first_field "${field}"
}

user_json_by_name() {
  local filter
  filter="$(json_filter_eq username "$1")"
  midclt call user.query "${filter}"
}

user_field_by_name() {
  local username="$1"
  local field="$2"
  user_json_by_name "${username}" | json_first_field "${field}"
}

smb_share_json_by_name() {
  local filter
  filter="$(json_filter_eq name "$1")"
  midclt call sharing.smb.query "${filter}"
}

smb_share_field_by_name() {
  local share_name="$1"
  local field="$2"
  smb_share_json_by_name "${share_name}" | json_first_field "${field}"
}

ensure_smb_group() {
  local gid
  gid="$(group_field_by_name "${SMB_GROUP}" gid)"
  if [[ -n "${gid}" ]]; then
    echo "OK: Group ${SMB_GROUP} already exists with gid ${gid}."
    return 0
  fi

  echo "Creating SMB group: ${SMB_GROUP}"
  local payload
  payload="$(python3 - "${SMB_GROUP}" <<'PY'
import json, sys
print(json.dumps({
    "name": sys.argv[1],
    "smb": True,
    "sudo_commands": [],
    "sudo_commands_nopasswd": []
}))
PY
)"
  midclt call group.create "${payload}" >/dev/null
  gid="$(group_field_by_name "${SMB_GROUP}" gid)"
  if [[ -z "${gid}" ]]; then
    echo "ERROR: Created group but could not resolve gid for ${SMB_GROUP}." >&2
    exit 1
  fi
  echo "OK: Created group ${SMB_GROUP} with gid ${gid}."
}

print_config_summary() {
  cat <<EOF_SUMMARY
Configuration:
  Pool:                  ${POOL}
  Parent dataset:        ${MEDIA_ZFS}
  Mount path:            ${MEDIA_PATH}
  Child datasets:        ${CHILD_DATASETS}
  Dataset share type:    ${DATASET_SHARE_TYPE}
  SMB share name:        ${SMB_SHARE_NAME}
  SMB purpose:           ${SMB_PURPOSE}
  Human SMB group:       ${SMB_GROUP}
  App UID:GID:           ${APP_UID}:${APP_GID}
  Recursive ACL apply:   ${APPLY_RECURSIVE}
  Traverse datasets:     ${TRAVERSE_DATASETS}
EOF_SUMMARY
}
