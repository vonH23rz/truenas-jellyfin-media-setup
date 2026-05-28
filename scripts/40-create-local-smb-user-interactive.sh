#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

USERNAME="${1:-}"
if [[ -z "${USERNAME}" ]]; then
  read -r -p "SMB username to create: " USERNAME
fi

if [[ -z "${USERNAME}" ]]; then
  echo "ERROR: username is required." >&2
  exit 1
fi

ensure_smb_group
GROUP_ID="$(group_field_by_name "${SMB_GROUP}" id)"
if [[ -z "${GROUP_ID}" ]]; then
  echo "ERROR: Could not resolve API id for group ${SMB_GROUP}." >&2
  exit 1
fi

existing_user_id="$(user_field_by_name "${USERNAME}" id)"
if [[ -n "${existing_user_id}" ]]; then
  echo "User already exists: ${USERNAME} (id ${existing_user_id})"
  echo "This script does not modify existing users. Add the user to ${SMB_GROUP} in the UI if needed."
  exit 0
fi

read -r -p "Full name / description [${USERNAME}]: " FULL_NAME
FULL_NAME="${FULL_NAME:-${USERNAME}}"

while true; do
  read -r -s -p "SMB password: " PASSWORD1
  echo
  read -r -s -p "Repeat SMB password: " PASSWORD2
  echo
  if [[ "${PASSWORD1}" == "${PASSWORD2}" && -n "${PASSWORD1}" ]]; then
    break
  fi
  echo "Passwords did not match or were empty. Try again."
done

payload="$(python3 - "${USERNAME}" "${FULL_NAME}" "${GROUP_ID}" "${PASSWORD1}" <<'PY'
import json, sys
username, full_name, group_id, password = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
print(json.dumps({
    "username": username,
    "full_name": full_name,
    "group_create": False,
    "group": group_id,
    "groups": [group_id],
    "home": "/var/empty",
    "home_create": False,
    "shell": "/usr/bin/zsh",
    "password": password,
    "password_disabled": False,
    "ssh_password_enabled": False,
    "smb": True,
    "locked": False,
    "sudo_commands": [],
    "sudo_commands_nopasswd": [],
}))
PY
)"

midclt call user.create "${payload}" >/dev/null

echo "OK: Created SMB user ${USERNAME} and assigned it to group ${SMB_GROUP}."
echo "You should now be able to authenticate to the SMB share with this user."
