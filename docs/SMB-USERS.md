# SMB Users for the Media Share

The dataset ACL gives the `media_rw` group Modify access. That means every human user who should manage media through SMB must be a member of `media_rw`.

## Recommended UI method

1. Open the TrueNAS SCALE web UI.
2. Go to **Credentials > Users**.
3. Add or edit the user.
4. Make sure SMB access is enabled for the user.
5. Add the user to the `media_rw` group.
6. Save.
7. Connect to the share from your workstation.

## Optional CLI method

This repository includes an optional interactive script:

```bash
sudo ./scripts/40-create-local-smb-user-interactive.sh mediaadmin
```

It creates a local SMB-capable user and assigns it to the configured media group.

## Client paths

Windows:

```text
\\TRUENAS-HOSTNAME\media
```

macOS:

```text
smb://TRUENAS-HOSTNAME/media
```

Linux:

```bash
smbclient //TRUENAS-HOSTNAME/media -U mediaadmin
```

## Avoid guest access

Do not use guest access for a media library you care about. It is harder to audit, easier to break, and modern clients often block insecure guest access by default.
