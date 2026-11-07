"""`android-iac audit`'s session: find the wireless debugging port, pair once if needed, connect,
and always disconnect. Nothing here changes the phone; turning debugging off stays a human step."""

from __future__ import annotations

import shutil
import subprocess
from typing import Callable, Optional

from adb import Adb, AdbError

Ask = Callable[[str, bool], str]  # (prompt, secret) -> answer
Browse = Callable[[str], str]  # (service type) -> `avahi-browse -tpr` output

CLOSE = """
Close the session on the phone (docs/guides/android-adb-session.md):
  Developer options, Revoke USB debugging authorizations, then Wireless debugging off."""


def avahi_browse(service: str) -> str:
    exe = shutil.which("avahi-browse")
    if exe is None:
        return ""
    try:
        return subprocess.run([exe, "-tpr", service], capture_output=True, text=True,
                              timeout=8, check=False).stdout
    except subprocess.TimeoutExpired:
        return ""


def discover(browse: Browse, service: str, address: str) -> Optional[str]:
    """The port the phone announces for `service` at `address`, from avahi's resolved lines
    (`=;iface;proto;name;type;domain;host;address;port;txt`)."""
    for line in browse(service).splitlines():
        f = line.split(";")
        if len(f) >= 9 and f[0] == "=" and f[7] == address and f[8].isdigit():
            return f[8]
    return None


def _port(found: Optional[str], ask: Ask, prompt: str) -> str:
    if found:
        return found
    answer = ask(prompt, False).strip()
    if not answer.isdigit():
        raise AdbError(f"not a port: {answer!r}")
    return answer


def open_session(adb: Adb, address: str, ask: Ask, browse: Browse = avahi_browse) -> str:
    """Connect to `address` over wireless debugging and return the `ip:port` serial."""
    port = _port(discover(browse, "_adb-tls-connect._tcp", address), ask,
                 "Wireless debugging on, then the port on its screen (IP address & Port): ")
    endpoint = f"{address}:{port}"
    out = adb.session("connect", endpoint)
    if out.startswith(("connected to", "already connected")):
        return endpoint
    print(f"adb connect: {out}")
    print("Not paired yet: on the phone, Wireless debugging, Pair device with pairing code.")
    pport = _port(discover(browse, "_adb-tls-pairing._tcp", address), ask, "Pairing port: ")
    code = ask("Pairing code (six digits): ", True).strip()
    if not (code.isdigit() and len(code) == 6):
        raise AdbError("the pairing code is six digits")
    paired = adb.session("pair", f"{address}:{pport}", secret=code)
    if "Successfully paired" not in paired:
        raise AdbError(f"pairing failed: {paired.splitlines()[-1] if paired else 'no answer'}")
    out = adb.session("connect", endpoint)
    if not out.startswith(("connected to", "already connected")):
        raise AdbError(f"paired, but connect failed: {out}")
    return endpoint


def close_session(adb: Adb, endpoint: Optional[str]) -> None:
    if endpoint:
        adb.session("disconnect", endpoint)
        print(f"\ndisconnected from {endpoint}")
    print(CLOSE)
