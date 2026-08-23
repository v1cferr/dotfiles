# razer-dpi: reads the Razer mouse's LIVE DPI over hidraw and pushes the Quickshell OSD when the
# onboard DPI button changes it. Why not openrazer, and the protocol: docs/notes/hardware/razer.md
{ writers }:

writers.writePython3Bin "razer-dpi"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """The Razer mouse's live DPI over hidraw, with no kernel module: docs/notes/hardware/razer.md"""
    import argparse
    import fcntl
    import glob
    import os
    import subprocess
    import sys
    import time

    VENDOR = 0x1532  # Razer

    # product id -> transaction id. The transaction id is per model and openrazer's driver is the
    # source of truth for it (razer_attr_read_dpi). Adding a model is one line here.
    MODELS = {
        0x0084: ("DeathAdder V2", 0x3F),
    }

    REPORT_LEN = 90  # struct razer_report: status/transaction/.../arguments[80]/crc/reserved


    def _ioc(direction, typ, nr, size):
        """Rebuild the kernel's _IOC macro. Python needs the signed form of the 32-bit value."""
        op = (direction << 30) | (size << 16) | (ord(typ) << 8) | nr
        return op - (1 << 32) if op >= (1 << 31) else op


    def hidiocsfeature(n):
        return _ioc(3, "H", 0x06, n)


    def hidiocgfeature(n):
        return _ioc(3, "H", 0x07, n)


    def build_get_dpi(transaction):
        """razer_chroma_misc_get_dpi_xy(NOSTORE): the LIVE value, not the one saved in the profile."""
        r = bytearray(REPORT_LEN)
        r[1] = transaction
        r[5] = 0x07  # data_size
        r[6] = 0x04  # command_class: misc
        r[7] = 0x85  # command_id: get_dpi_xy
        r[8] = 0x00  # arguments[0]: NOSTORE
        crc = 0
        for i in range(2, 88):  # the checksum is a plain xor of bytes 2..87
            crc ^= r[i]
        r[88] = crc
        return bytes(r)


    def candidates():
        """Every hidraw node belonging to a Razer model we know, as (path, name, transaction)."""
        out = []
        for sysfs in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
            try:
                with open(os.path.join(sysfs, "device/uevent")) as fh:
                    uevent = fh.read()
            except OSError:
                continue
            for line in uevent.splitlines():
                if not line.startswith("HID_ID="):
                    continue
                parts = line.split("=", 1)[1].split(":")
                if len(parts) != 3:
                    continue
                try:
                    vendor, product = int(parts[1], 16), int(parts[2], 16)
                except ValueError:
                    continue
                if vendor == VENDOR and product in MODELS:
                    name, transaction = MODELS[product]
                    out.append(("/dev/" + os.path.basename(sysfs), name, transaction))
        return out


    def read_dpi(fd, transaction):
        """(dpi_x, dpi_y), or None when the device did not answer with a success status."""
        buf = bytearray(REPORT_LEN + 1)  # buf[0] is the report number (0), then the 90-byte report
        buf[1:] = build_get_dpi(transaction)
        fcntl.ioctl(fd, hidiocsfeature(REPORT_LEN + 1), buf)
        time.sleep(0.04)  # the device needs a moment before the answer is readable
        resp = bytearray(REPORT_LEN + 1)
        fcntl.ioctl(fd, hidiocgfeature(REPORT_LEN + 1), resp)
        report = resp[1:]
        if report[0] != 0x02:  # 0x02 = command successful
            return None
        args = report[8:88]
        return ((args[1] << 8) | args[2], (args[3] << 8) | args[4])


    def open_device():
        """The CONTROL interface: the only one of the 4 that answers a DPI query. (fd, name, tid)."""
        for path, name, transaction in candidates():
            try:
                fd = os.open(path, os.O_RDWR)
            except OSError:
                continue  # not the udev-tagged node, or the mouse went away mid-scan
            try:
                if read_dpi(fd, transaction) is not None:
                    return fd, name, transaction
            except OSError:
                pass
            os.close(fd)
        return None, None, None


    def notify(dpi):
        """Best effort: the OSD is a nicety, never a reason to take the watcher down."""
        try:
            subprocess.run(
                ["qs", "ipc", "call", "osd", "dpi", str(dpi)],
                check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            pass


    def cmd_get(_args):
        fd, name, transaction = open_device()
        if fd is None:
            print("no supported Razer mouse found", file=sys.stderr)
            return 1
        dpi = read_dpi(fd, transaction)
        os.close(fd)
        if dpi is None:
            print("the device did not answer a DPI query", file=sys.stderr)
            return 1
        print(f"{name}: {dpi[0]}x{dpi[1]}")
        return 0


    def cmd_watch(args):
        """Poll the LIVE DPI and push the OSD on every change. Survives unplug/replug."""
        last = None
        while True:
            fd, name, transaction = open_device()
            if fd is None:
                time.sleep(5)  # no mouse: idle cheaply until it comes back
                continue
            print(f"watching {name} every {args.interval}s", flush=True)
            # The value at startup is the BASELINE, never an OSD: nobody asked for one at login.
            try:
                last = read_dpi(fd, transaction)
            except OSError:
                os.close(fd)
                continue
            while True:
                time.sleep(args.interval)
                try:
                    current = read_dpi(fd, transaction)
                except OSError:
                    break  # unplugged (or suspended): fall back to the rescan loop
                if current is None or current == last:
                    continue
                last = current
                print(f"dpi {current[0]}x{current[1]}", flush=True)
                notify(current[0])
            os.close(fd)


    def main():
        parser = argparse.ArgumentParser(description="Razer mouse DPI, read straight from hidraw.")
        sub = parser.add_subparsers(dest="command", required=True)
        sub.add_parser("get", help="print the current DPI once")
        watch = sub.add_parser("watch", help="push the Quickshell OSD whenever the DPI changes")
        watch.add_argument(
            "--interval", type=float, default=0.25,
            help="seconds between polls (default: 0.25). Each poll is one HID feature report.",
        )
        args = parser.parse_args()
        handler = {"get": cmd_get, "watch": cmd_watch}[args.command]
        try:
            return handler(args)
        except KeyboardInterrupt:
            return 0


    if __name__ == "__main__":
        sys.exit(main())
  ''
