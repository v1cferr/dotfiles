# Android over ADB, wireless

`system/hardware/android.nix`: `adb`, `scrcpy` and `uad-ng`, for looking inside the phone from
this machine and cleaning it up.

## Why ADB and not SFTP

The goal was a slow phone with too much installed. Apps and their data live under `/data`, which
is closed to SFTP and to MTP without root: either one only sees shared storage (`/sdcard`: photos,
Downloads, WhatsApp media). So SFTP can find big files but can never say which app holds 8 GB, and
cannot uninstall anything. ADB sees both, and removes packages, including system bloat.

## What the module does NOT need

- **`programs.adb`**: it has no effect anymore. systemd 258 ships the uaccess rules for ADB
  devices, so the USB ACL goes to whoever is logged in on the seat, with no `adbusers` group.
- **A firewall port**: in wireless debugging the PC dials OUT to the phone, both for `adb pair`
  and for `adb connect`. Nothing listens here.

## Pairing (once per phone)

1. On the phone: Developer options, then **Wireless debugging**, then **Pair device with pairing
   code**. It shows an `IP:port` and a 6 digit code.
2. Here:

   ```sh
   adb pair 192.168.1.X:PAIRING_PORT   # asks for the code
   adb connect 192.168.1.X:PORT        # the port on the MAIN Wireless debugging screen
   adb devices                         # must list it as `device`, not `unauthorized`
   ```

The pairing port and the connect port are DIFFERENT, and both change every time wireless debugging
is toggled. The pairing survives; only `adb connect` has to be repeated with the new port.

## Measuring and cleaning

```sh
adb shell dumpsys diskstats            # per-app sizes: code, data, cache
adb shell du -h -d1 /sdcard | sort -h  # the heaviest folders in shared storage
adb shell pm list packages -3          # apps installed by me, not the system
adb shell pm trim-caches 999G          # clears every app's cache at once
adb uninstall <package>                # an app I installed
scrcpy                                 # the screen here, to click through settings
```

For system apps and vendor bloat, `uad-ng`. Each package carries a rating (Recommended, Advanced,
Expert, Unsafe); stay on Recommended unless a package is known. Its removal is
`pm uninstall --user 0`, which hides the app for the user and keeps the APK in the system
partition, so it is reversible:

```sh
adb shell cmd package install-existing <package>
```

A factory reset also brings every removed system app back.
