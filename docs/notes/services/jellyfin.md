# Jellyfin and the media library

`system/services/jellyfin.nix`. A native media server on systemd, 24/7, up at boot. Migrated from
the Arch Docker stack: isolated in the `jellyfin` user, with no container overhead.

## The shared group

The library lives in `/srv/media` (an SSD) and is shared through the `media` group: I manage the
files, jellyfin reads them. `/srv/media` is created with setgid (the `2` in `2775`), so everything
created inside inherits the group and jellyfin, the \*arr apps and I see the same files without
fighting over permissions.

The LIBRARIES themselves (what is a Movie, what is a Series) are configured in the web UI
(`localhost:8096`) on the first visit. That is jellyfin's state, not config, so it does not live
in Nix (rule 6).

## The UMask override

Upstream uses `UMask 0077`: the cover art and `.nfo` files jellyfin downloads are born `0600` and
I cannot read or move them. `0002` makes them inherit the `media` group with read access.

## DLNA on the TV

It stopped being core in 10.10; it is the official "DLNA" plugin, installed through the web UI
(Dashboard > Plugins). It discovers the network interface on its own, but it only counts as
"virtual" what is listed in `VirtualInterfaceNames` (Dashboard > Network). With no `docker`/`br-`
there, it announces the Docker bridge's IP and the TV never finds the server.

## The rest of the old stack

jellyseerr and the \*arr apps come later, one module at a time. qbittorrent is already migrated
(`system/services/qbittorrent.nix`), in the same `media` group, writing to `/srv/media/torrents`,
with the Web UI on 8080. Its save paths and categories are set in that Web UI: state again.
The initial login is user `admin`, with a temporary password in `journalctl -u qbittorrent`.
