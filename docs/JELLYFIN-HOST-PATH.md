# Jellyfin Host Path Setup

The media dataset is prepared for the default TrueNAS Jellyfin app user/group, usually UID/GID `568` (`apps`).

## Recommended mount

In the TrueNAS Jellyfin app storage settings, add a host path:

```text
Host path:      /mnt/tank/media
Container path: /media
```

Then add Jellyfin libraries:

```text
Movies:    /media/movies
TV Shows:  /media/tv
Anime:     /media/anime
Kids:      /media/kids
Music:     /media/music
```

## Downloads folder

`/media/downloads` is included because many homelab media workflows use a download/import staging area. You may decide later not to expose it directly to Jellyfin as a library.

## Read-only alternative

For maximum safety, you can give Jellyfin read-only access and let SMB users manage the files. This repository defaults to Modify access for Jellyfin because many users want Jellyfin or related media tools to write metadata, thumbnails, or sidecar files. Adjust the ACL if your design is stricter.
