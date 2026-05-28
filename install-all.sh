#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/scripts/00-check-truenas.sh"
"${SCRIPT_DIR}/scripts/10-create-datasets.sh"
"${SCRIPT_DIR}/scripts/20-apply-media-acl.sh"
"${SCRIPT_DIR}/scripts/30-create-smb-share.sh"
"${SCRIPT_DIR}/scripts/90-verify-media-setup.sh"

cat <<'DONE'

Done.
Next steps:
  1. Create or verify an SMB user and put it in the media_rw group.
  2. Install Jellyfin and mount /mnt/tank/media into the app as a Host Path.
  3. In Jellyfin, add libraries pointing to /media/movies, /media/tv, /media/music, etc.
DONE
