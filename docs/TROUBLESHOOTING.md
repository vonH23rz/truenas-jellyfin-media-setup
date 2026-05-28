# Troubleshooting

## Jellyfin cannot see the folders

Check which UID/GID Jellyfin runs as. The default in TrueNAS docs is `568:568`, but users can change it during app setup.

```bash
midclt call filesystem.getacl '{"path":"/mnt/tank/media","simplified":true,"resolve_ids":true}'
```

Confirm that UID/GID `568` or your custom Jellyfin UID/GID has at least Read/Traverse access. This repository grants Modify by default.

## SMB login works but files cannot be written

Check that the SMB user is in the `media_rw` group.

```bash
midclt call group.query '[["name","=","media_rw"]]'
```

Also verify the dataset ACL:

```bash
midclt call filesystem.getacl '{"path":"/mnt/tank/media","simplified":true,"resolve_ids":true}'
```

## SMB share does not appear

Check the share exists:

```bash
midclt call sharing.smb.query '[["name","=","media"]]'
```

Check the SMB service:

```bash
midclt call service.query '[["service","=","cifs"]]'
```

Start or restart SMB:

```bash
midclt call -job service.control START cifs '{"silent": false}'
midclt call -job service.control RESTART cifs '{"silent": false}'
```

## Existing files still have old permissions

By default, `APPLY_RECURSIVE` is `false` for safety. On a fresh dataset you can set this in `media-setup.conf`:

```bash
APPLY_RECURSIVE="true"
```

Then rerun:

```bash
sudo ./scripts/20-apply-media-acl.sh
```

Only do this intentionally because recursive ACL changes touch existing files.

## TrueNAS rejects DATASET_SHARE_TYPE=MULTIPROTOCOL

Older or changed API versions may use a different internal value. Edit `media-setup.conf`:

```bash
DATASET_SHARE_TYPE="SMB"
```

Then rerun the dataset creation script.
