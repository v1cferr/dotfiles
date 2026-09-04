# The webcam, and the USB -71 that kills the stream

Two packages and no module: `guvcview` in [`home/packages.nix`](../../../home/packages.nix) (the
viewer) and `v4l-utils` in [`system/packages.nix`](../../../system/packages.nix) (the diagnosis,
next to the other hardware monitors, rule 4). There is nothing else to declare, and that is the
finding rather than an omission: measured on 04/09/2026, the camera needs no driver, no udev rule
and no kernel quirk, and the one thing that would fix it is not declarable at all.

`guvcview` is the viewer of the four I looked at because it shows the image AND the UVC controls
(brightness, exposure, format, resolution) in the same window. For a camera that still resets
itself, being able to pick the format by hand is worth more than a prettier preview. GNOME
Snapshot only previews, and OBS Studio is a studio, which is a different job.

## What the device is, and what already works

A Sonix `0c45:636b` sold as a REDRAGON Live Camera, UVC 1.00, on a USB 2.0 hub. The parts that
work needed nothing declared:

| Piece | State |
| --- | --- |
| Driver | `uvcvideo` binds it at enumeration, no module option, no quirk |
| Nodes | `/dev/video0` (capture), `/dev/video1` (metadata), `/dev/media0` |
| Access | the seat ACL already grants `user:v1cferr:rw-`, so no group and no rule of mine |
| Microphone | interfaces 1.2 and 1.3 bind `snd-usb-audio`, and PipeWire has it as a source |
| Formats offered | MJPG up to 1280x720 at 30 fps, YUYV up to 640x480 at 30 fps |

The microphone matters as EVIDENCE and not as a feature: recording from it produced 3 seconds of
real, non-silent audio over the same cable and the same hub. So enumeration works, the control
endpoint works for the audio function, and the link carries isochronous traffic. Whatever is
broken is specific to the video half.

The camera also arrives as the DEFAULT PipeWire source, ahead of the headset, which is a
preference to fix on the day it annoys me and not a fault.

## The failure

Nearly every attempt to start the stream dies the same way, in the kernel log:

```text
uvcvideo 1-8.2:1.1: Failed to set UVC probe control : -71 (exp. 26).
uvcvideo 1-8.2:1.1: Failed to set UVC commit control : -71 (exp. 26).
usb 1-8.2: USB disconnect, device number 9
usb 1-8.2: new high-speed USB device number 10 using xhci_hcd
```

Userspace sees `VIDIOC_STREAMON: Protocol error` on the first try and `Input/output error` on the
ones after, because by then the camera is re-enumerating. In one session on 04/09/2026 it went
from device number 6 to 10: the device REBOOTS ITSELF when the video function is asked to negotiate
a stream and the negotiation fails.

IT IS INTERMITTENT, NOT DEAD, and that is the fact that took the longest to see: **1 stream in
17 attempts on 04/09/2026**, with 11 self-reboots in the same day. The one that worked captured a
clean frame with NOTHING in the log, no probe error and no reset, and it was the first access to a
device that had sat untouched for about three hours. Every attempt after it failed, including the
one 90 seconds later. So a single success proves nothing here, and neither does a single failure:
whatever is marginal is marginal in the electrical sense, not in the driver.

`-71` is EPROTO, and where it happens is the whole point. The probe and commit controls are
CONTROL transfers on endpoint 0, which run BEFORE any isochronous bandwidth is reserved. A camera
that asked for more bandwidth than the bus has does not fail here, it fails at STREAMON with
ENOSPC. So this is the transport giving up, not the driver negotiating badly.

## What it is NOT, all of it measured

Recorded because each one of these is an afternoon someone else would spend, and three of them
are the answers the internet offers first:

- **NOT permissions.** The ACL is right and the ioctl reaches the driver, which is exactly why the
  driver is the one logging the error.
- **NOT the format or the resolution.** MJPG at 1280x720 and 640x480, and YUYV at 640x480 and
  320x240, all four fail identically. Dropping the resolution is the standard advice and it does
  nothing here.
- **NOT bandwidth.** See above: EPROTO on endpoint 0 happens before allocation. `UVC_QUIRK_FIX_BANDWIDTH`
  would be treating a symptom that never appeared.
- **NOT USB autosuspend, and this one nearly fooled me.** The device sits at `power/control = auto`
  with a 2000 ms delay, it was suspended when the first attempt ran, and EPROTO on the first
  control transfer after a resume is a documented UVC quirk. It is still not the cause: four more
  attempts with the device already `active` logged the same failure on both the probe and the commit
  control. That first measurement was contaminated, since a device mid-reset also reads `active`,
  so it was redone cleanly: four iterations that WOKE the device with a control transfer first,
  each starting from a fresh enumeration (device numbers 11 through 14), confirmed `active`, and
  every one still failed at STREAMON. A udev rule pinning `power/control = on` was therefore NOT
  declared, because rule 16 means a workaround that fixes nothing is worse than none.
- **NOT the cheapest mode either.** YUYV at 320x240, the mode that asks least of both the bus and
  the JPEG encoder, fails the same way as the FIRST access to a settled device. The earlier test of
  it was contaminated (the camera was already wedged), which is why it was run again.
- **NOT contention.** No process holds `/dev/video0` or `/dev/video1`, and the camera's own
  microphone reads `closed` at the ALSA level, so the audio function is not occupying the device
  when the video function tries to negotiate. Worth checking because this device is the DEFAULT
  PipeWire source, so something monitoring input would have been a plausible explanation.
- **NOT a missing quirk, and this one was TESTED and not merely reasoned about.** Nothing in the
  kernel's UVC quirk table names `0c45:636b`, and the error names the control SIZE (`exp. 26`, the
  UVC 1.0 probe control, which is what the driver sends because the device declares UVC 1.00), so
  firmware wanting the larger 1.1 layout was a real candidate. Forced at runtime through the module
  parameter with a full re-probe between each: `quirks=6` (`PROBE_MINMAX` plus
  `PROBE_EXTRAFIELDS`), then `4`, then `2`. All three fail identically. The community reports of
  `-71` converge on power and cabling instead, with replugging as the usual workaround, and
  replugging was tried here and the failure survived it.

One line does appear at every enumeration and is harmless, so it is not the trail to follow:
`Failed to query (GET_INFO) UVC control 5 on unit 1`. That is firmware not answering an optional
query, and the camera works elsewhere with it.

## Two traps for whoever tests this next

`v4l2-ctl` EXITS 0 EVEN WHEN THE STREAM FAILS. `--stream-mmap` printing
`VIDIOC_STREAMON returned -1` still gives `$?` of 0, so any script that branches on the exit code
reports success while the camera is dead. Check the BYTES captured (`--stream-to` a file, then test
it is non-empty), never the status.

`modprobe -r uvcvideo` CANNOT WORK WITH THE GRAPHICAL SESSION UP: the module sits at refcount 1
with no process holding `/dev/video*` or `/dev/media*`, since what pins it is the input device the
camera registers for its own button, which the compositor's libinput keeps open. So a quirk is
tested WITHOUT unloading anything: write `/sys/module/uvcvideo/parameters/quirks`, then force a
re-probe by toggling `/sys/bus/usb/devices/1-8.2/authorized` off and on, which is a software
replug. The default to restore is `4294967295`, the unsigned form of the `-1` that means "use the
driver's own table", NOT `0`, which would force "no quirks at all".

## What is left, and it is physical

The camera hangs off a bus-powered USB 2.0 hub (`1-8`, whose descriptor advertises 100 mA),
sharing it with a USB Audio and HID device at `1-8.4`. The camera's own descriptor asks for
**500 mA**. That gap explains the shape of the failure precisely: enumeration and the microphone
draw almost nothing, while the sensor and the JPEG encoder are what pull current, and they only
switch on at the moment of stream negotiation. A brown-out there looks exactly like this, EPROTO
followed by the device rebooting.

Bus 2, the USB 3 root, has NO devices on it at all, so there are free ports on the board.

THE TEST THAT DECIDES IT, and no configuration substitutes for it: plug the camera straight into a
rear motherboard port, with no hub in between, and stream again.

- If it streams there, the hub is the answer, and the fix is a port or a powered hub. Still nothing
  to declare, which is why this note exists instead of a module.
- If it fails there too, on a USB 2 and a USB 3 port, the video half of the camera is dead and no
  config in this repo will bring it back. The microphone would keep working, which is the confusing
  part worth remembering: half of this device can be fine while the other half is not.
