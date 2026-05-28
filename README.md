# TrueNAS SCALE Jellyfin Media Dataset Setup

Reusable tutorial and scripts for a fresh TrueNAS SCALE installation where you want a clean Jellyfin media layout at:

```text
/mnt/tank/media
├── movies
├── tv
├── downloads
├── anime
├── kids
├── xxx
└── music
```

The goal is simple:

- Create the ZFS parent dataset and child datasets.
- Apply sane NFSv4 ACLs for Jellyfin and SMB access.
- Create an SMB share so another computer can add, edit, or organize media.
- Keep the setup repeatable for rebuilds, videos, wiki pages, or GitHub publication.

## Tested design target

This setup is intended for TrueNAS SCALE 25.04+ / 25.10+ style systems using `midclt`, ZFS datasets, NFSv4 ACLs, and modern SMB share presets.

The scripts use the TrueNAS middleware CLI (`midclt`) instead of editing Samba config files manually.

## Permission model

The scripts create or use this access model:

| Principal | Purpose | Permission |
|---|---|---|
| `root` | Dataset owner / administrator | Full Control |
| `media_rw` group | Human SMB users | Modify |
| UID `568` | TrueNAS app / Jellyfin default user | Modify |
| GID `568` | TrueNAS app / Jellyfin default group | Modify |
| `everyone@` | No public media access | Traverse only |

This avoids the classic problem where SMB works but Jellyfin cannot see files, or Jellyfin works but SMB users cannot manage files.

## Why NFSv4 ACLs?

TrueNAS SCALE supports POSIX and NFSv4 ACLs. SMB datasets use NFSv4 ACLs because SMB requires the richer ACL model. For paths that are accessed by apps/containers and SMB clients, this repository uses the multi-protocol style because TrueNAS documents that this is intended for paths used by apps, containers, local processes, NFS, FTP, and SMB.

## Safety notes

Run these scripts only on the TrueNAS SCALE host shell as `root` or with equivalent administrative access.

Before running this on a system with existing media, make a configuration backup and a snapshot. The default config does **not** recursively overwrite existing file ACLs, but you should still treat permissions automation with respect.

Do not create an SMB share at the root of a pool such as `/mnt/tank`. TrueNAS explicitly warns against sharing root or pool-level datasets. This repository shares `/mnt/tank/media`, which is a child dataset.

## Quick start

Clone or copy this repository to your TrueNAS SCALE host.

```bash
cd /root
# Example after upload/git clone:
cd truenas-jellyfin-media-repo
cp media-setup.conf.example media-setup.conf
nano media-setup.conf
```

Review the config. The defaults create `/mnt/tank/media` and the listed child datasets.

Run preflight:

```bash
sudo ./scripts/00-check-truenas.sh
```

Run everything:

```bash
sudo ./install-all.sh
```

Or run step by step:

```bash
sudo ./scripts/10-create-datasets.sh
sudo ./scripts/20-apply-media-acl.sh
sudo ./scripts/30-create-smb-share.sh
sudo ./scripts/90-verify-media-setup.sh
```

## Create an SMB user

You need an SMB-capable TrueNAS user that belongs to the `media_rw` group.

Recommended UI method:

1. Go to **Credentials > Users**.
2. Add a user, for example `mediaadmin`.
3. Enable SMB access for that user.
4. Add the user to the `media_rw` group.
5. Use that user from Windows/macOS/Linux to connect to the share.

Optional CLI method:

```bash
sudo ./scripts/40-create-local-smb-user-interactive.sh mediaadmin
```

The optional script prompts for the password and creates a local SMB user assigned to the configured media group.

## Connect from another computer

Windows:

```text
\\TRUENAS-HOSTNAME\media
```

macOS Finder:

```text
smb://TRUENAS-HOSTNAME/media
```

Linux:

```bash
smbclient //TRUENAS-HOSTNAME/media -U mediaadmin
```

Replace `TRUENAS-HOSTNAME` with the hostname or IP address of your TrueNAS server.

## Jellyfin app setup

When installing Jellyfin on TrueNAS SCALE:

1. Use the default Jellyfin app user/group unless you intentionally changed it.
2. The current TrueNAS Jellyfin docs describe UID/GID `568` (`apps`) as the default.
3. Add host path storage:
   - Host path: `/mnt/tank/media`
   - Container path: `/media`
4. Inside Jellyfin, add libraries like:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
   - Music: `/media/music`
   - Anime: `/media/anime`
   - Kids: `/media/kids`

## Dataset layout choice

Each media category is a child dataset rather than a plain folder. This gives you more flexibility later:

- Separate snapshots or replication rules per category.
- Separate quotas later if needed.
- Easier exclusion of `downloads` from long-term backup if desired.
- Cleaner recovery if one category needs to be rolled back.

For a very simple home setup, plain folders would also work. This repository intentionally uses child datasets because it is better for repeatable TrueNAS administration.

## Files in this repository

```text
.
├── install-all.sh
├── media-setup.conf.example
├── scripts
│   ├── 00-check-truenas.sh
│   ├── 10-create-datasets.sh
│   ├── 20-apply-media-acl.sh
│   ├── 30-create-smb-share.sh
│   ├── 40-create-local-smb-user-interactive.sh
│   └── 90-verify-media-setup.sh
├── lib
│   └── common.sh
└── docs
    ├── JELLYFIN-HOST-PATH.md
    ├── SMB-USERS.md
    └── TROUBLESHOOTING.md
```

## Configuration reference

Edit `media-setup.conf` after copying it from the example.

Important values:

```bash
POOL="tank"
MEDIA_DATASET="media"
CHILD_DATASETS="movies tv downloads anime kids xxx music"
SMB_GROUP="media_rw"
APP_UID="568"
APP_GID="568"
APPLY_RECURSIVE="false"
```

Set `APPLY_RECURSIVE="true"` only on a fresh dataset or when you intentionally want to re-apply the ACL to existing files and directories.

## Troubleshooting quick checks

Show datasets:

```bash
zfs list -r tank/media
```

Show ACL:

```bash
midclt call filesystem.getacl '{"path":"/mnt/tank/media","simplified":true,"resolve_ids":true}'
```

Show SMB share:

```bash
midclt call sharing.smb.query '[["name","=","media"]]'
```

Show SMB service:

```bash
midclt call service.query '[["service","=","cifs"]]'
```

## Official references

- TrueNAS ACL configuration: https://www.truenas.com/docs/scale/datasets/permissions/configuringacls/
- TrueNAS ACL primer: https://www.truenas.com/docs/references/aclprimer/
- TrueNAS SMB shares: https://www.truenas.com/docs/scale/shares/smb/addmanagesmbshares/
- TrueNAS multiprotocol shares: https://www.truenas.com/docs/scale/shares/mixedmodeshares/
- TrueNAS API docs: https://api.truenas.com/
- TrueNAS Jellyfin app docs: https://www.truenas.com/docs/scale/24.04/scaletutorials/apps/communityapps/jellyfin/

## License

MIT. Use it, fork it, change it, and make it your own.
