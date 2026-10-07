# Phone sync (Syncthing)

`modules/nixos/services/phone-sync.nix`: Syncthing pulls the phone's `DCIM` into
`~/Pictures/M51`, and Dolphin shows it as the **M51** place.

## Why Syncthing and not the alternatives

The goal is to browse the phone's photos in Dolphin. What was weighed on 07/10/2026:

- **MTP over USB (kio-mtp).** It needs a cable and a tap on the phone every time. MTP on Linux
  has also failed for years in the same ways: the phone goes undetected, browsing freezes, and
  Dolphin says "could not enter folder". Fine as a last resort, never as the way in.
- **KDE Connect.** It browses the phone live over SFTP (`kdeconnect://`), but only while the phone
  is awake and on the same network. Thumbnails for thousands of photos over SFTP are slow, and it
  has a long record of storage-permission bugs. Good for one-off browsing, which this is not.
- **Immich's folder.** If the phone backed up to Immich, the originals would already sit in
  `/srv/photos/immich`. But Immich here is the ARCHIVE next to Google Photos (see
  [immich](immich.md)), its files belong to the `immich` user, and there is no rclone or WebDAV
  view of an Immich library.
- **Google Photos through rclone.** Its API does not hand out the originals.

Syncthing leaves real files on the local disk: thumbnails are instant, it works with the phone
off, and the whole PC side is declared here.

## The folder's two choices

- **`receiveonly`**: the phone is the only source. Editing or deleting a file here never travels
  back. Syncthing flags such a file as "locally changed", and the GUI's **Revert** button undoes
  it, which DELETES files that only exist here. Do not press it without reading the list.
- **`ignoreDelete`**: deleting a photo on the phone, usually to free space, keeps the copy here.
  It is an accumulating copy, NOT a mirror.

It is still not a backup: `~/Pictures` lives in `@home`, so only btrbk's local snapshots cover it.

## Why a new folder and not `~/Pictures/phone-m51`

`phone-m51` (11 GB) is the ADB pull from the cleanup on 28/09/2026, taken BEFORE photos were
deleted on the phone. Synced as a `receiveonly` folder, every photo the phone no longer has would
show up as "locally added", one Revert away from being deleted. So it stays an untouched archive,
and the two can be deduplicated by hand later.

## Pairing (once per phone)

The phone's Device ID is not a secret: it is public key material, the same category as the
tunnel id in `hosts/ex-b560m-v5/services.nix`. Until `my.phoneSync.deviceId` is set, the folder
exists but is shared with no one, so the service is inert.

1. On the phone, install **Syncthing-Fork** from F-Droid. The upstream Android app was
   discontinued in December 2024.
2. Copy the phone's Device ID (menu, then *Show device ID*) into `my.phoneSync.deviceId`, rebuild.
3. Read this machine's Device ID with `syncthing device-id --home ~/.config/syncthing` (or in
   the GUI at `http://127.0.0.1:8384`) and add it on the phone as a remote device.
4. On the phone, add a folder: path `DCIM`, folder ID **`m51-dcim`** (it MUST match), type
   **Send Only**, shared with this machine.

Devices and folders are owned by Nix (`overrideDevices` and `overrideFolders`), so anything
added in the GUI on this side is dropped on the next start.

## The firewall

`openDefaultPorts` opens 22000 TCP/UDP and 21027 UDP (local discovery). The router does not
forward them, so they are reachable from the LAN alone. Away from home the phone still reaches
this machine through Syncthing's relays, only slower.
