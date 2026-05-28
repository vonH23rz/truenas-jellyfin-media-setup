#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root
require_truenas_tools

create_dataset() {
  local ds="$1"
  if zfs list -H -o name "${ds}" >/dev/null 2>&1; then
    if [[ "${ALLOW_EXISTING_DATASETS,,}" != "true" ]]; then
      echo "ERROR: Dataset already exists and ALLOW_EXISTING_DATASETS is not true: ${ds}" >&2
      exit 1
    fi
    echo "OK: Dataset already exists: ${ds}"
    return 0
  fi

  echo "Creating dataset: ${ds}"
  local payload
  payload="$(python3 - "${ds}" "${DATASET_SHARE_TYPE}" <<'PY'
import json, sys
name = sys.argv[1]
share_type = sys.argv[2]
print(json.dumps({
    "name": name,
    "type": "FILESYSTEM",
    "share_type": share_type,
    "compression": "LZ4",
    "atime": "OFF"
}))
PY
)"

  if ! midclt call pool.dataset.create "${payload}" >/dev/null; then
    echo "ERROR: Failed to create ${ds} with share_type=${DATASET_SHARE_TYPE}." >&2
    echo "Tip: edit media-setup.conf and try DATASET_SHARE_TYPE=SMB if your TrueNAS release rejects MULTIPROTOCOL." >&2
    exit 1
  fi
}

print_config_summary

echo
create_dataset "${MEDIA_ZFS}"

for child in ${CHILD_DATASETS}; do
  create_dataset "${MEDIA_ZFS}/${child}"
done

echo
echo "Datasets created or already present:"
zfs list -r "${MEDIA_ZFS}"
