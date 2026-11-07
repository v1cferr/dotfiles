"""What the phone answers, read through the allowlist. A read that failed stays ABSENT (unknown),
which is never the same as a key that answered unset."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

import parse
import sanitize
from adb import Adb, AdbError, MultipleDevices, NoDevice, Unauthorized
from spec import Spec


@dataclass
class Observed:
    props: dict[str, str] = field(default_factory=dict)
    selinux: Optional[str] = None
    nfc: Optional[str] = None
    lock_disabled: Optional[bool] = None
    settings: dict[tuple[str, str], Optional[str]] = field(default_factory=dict)
    installed: Optional[set[str]] = None
    enabled: Optional[set[str]] = None
    disabled: Optional[set[str]] = None
    third_party: Optional[set[str]] = None
    permissions: Optional[dict[str, set[str]]] = None
    managed_permissions: dict[str, set[str]] = field(default_factory=dict)  # only the packages read


def select(adb: Adb, transport_id: Optional[str] = None, serial_set: bool = False) -> parse.Device:
    """The one ready device adb will talk to, or an error that says what to do. With several,
    `--transport-id` picks one; ANDROID_SERIAL is left to adb, which never shows it to us."""
    found = parse.devices(adb.call("devices", "-l"))
    if transport_id is not None:
        found = [d for d in found if d.transport_id == transport_id]
        if not found:
            raise NoDevice(f"no device has transport id {transport_id}: see `android-iac doctor`")
    if not found:
        raise NoDevice("no phone attached: plug USB, or `adb connect <address>:<port>` for wireless debugging")
    ready = [d for d in found if d.state == "device"]
    if any(d.state == "unauthorized" for d in found) and not ready:
        raise Unauthorized("the phone has not authorized this computer: unlock it and accept the RSA prompt")
    if not ready:
        raise NoDevice(f"no device is ready (states: {', '.join(sorted({d.state for d in found}))})")
    if len(ready) > 1 and not serial_set:
        ids = ", ".join(f"{d.transport}:{d.transport_id}" for d in ready)
        raise MultipleDevices(f"{len(ready)} devices ready ({ids}): pick one with --transport-id")
    return ready[0]


def identity(spec: Spec, props: dict[str, str]) -> None:
    """Refuse to compare one phone against another's declaration."""
    for want, key in ((spec.manufacturer, "ro.product.manufacturer"), (spec.model, "ro.product.model")):
        got = props.get(key)
        if want is not None and got is not None and got.lower() != want.lower():
            raise AdbError(f"this is not {spec.name}: {key} is {got!r}, the spec declares {want!r}")


def observe(adb: Adb, spec: Spec, with_permissions: bool = False) -> Observed:
    o = Observed()
    o.props = parse.getprop(adb.try_call("shell", "getprop") or "")
    identity(spec, o.props)
    o.selinux = parse.selinux(adb.try_call("shell", "getenforce"))
    o.nfc = parse.nfc(adb.try_call("shell", "dumpsys", "nfc"))
    o.lock_disabled = parse.lock_disabled(adb.try_call("shell", "cmd", "lock_settings", "get-disabled"))
    for ns, key in [*spec.settings, *spec.manual_settings, *spec.managed.settings]:
        out = adb.try_call("shell", "settings", "get", ns, key)
        if out is not None:
            o.settings[(ns, key)] = parse.setting(out)

    def pkgs(*flag: str) -> Optional[set[str]]:
        out = adb.try_call("shell", "pm", "list", "packages", *flag)
        return None if out is None else parse.packages(out)

    o.installed, o.enabled, o.disabled, o.third_party = pkgs(), pkgs("-e"), pkgs("-d"), pkgs("-3")
    for pkg in spec.managed.permissions_revoked:
        if o.installed is not None and pkg in o.installed:
            out = adb.try_call("shell", "dumpsys", "package", pkg)
            if out is not None:
                o.managed_permissions[pkg] = parse.granted_runtime(out)
    if with_permissions and o.third_party is not None:
        o.permissions = {}
        for pkg in sorted(o.third_party):
            out = adb.try_call("shell", "dumpsys", "package", pkg)
            if out is not None:
                o.permissions[pkg] = parse.granted_runtime(out)
    return o


def report(adb: Adb, o: Observed) -> dict[str, Any]:
    """The inspect report: sanitized, and passed through the final scrubber."""
    p = o.props
    lists = {}
    for ns in ("global", "secure", "system"):
        out = adb.try_call("shell", "settings", "list", ns)
        lists[ns] = None if out is None else sanitize.settings(parse.settings_list(out))
    data = {
        "device": {"manufacturer": p.get("ro.product.manufacturer"), "model": p.get("ro.product.model"),
                   "android": p.get("ro.build.version.release"), "api": p.get("ro.build.version.sdk"),
                   "fingerprint": p.get("ro.build.fingerprint"),
                   "securityPatch": p.get("ro.build.version.security_patch")},
        "boot": {"verifiedBoot": p.get("ro.boot.verifiedbootstate"),
                 "bootloaderLocked": p.get("ro.boot.flash.locked"),
                 "vbmetaState": p.get("ro.boot.vbmeta.device_state"), "selinux": o.selinux},
        "nfc": o.nfc, "lockScreenDisabled": o.lock_disabled,
        "props": sanitize.props(p),
        "packages": {name: None if s is None else sorted(s) for name, s in (
            ("enabled", o.enabled), ("disabled", o.disabled), ("thirdParty", o.third_party))},
        "permissions": None if o.permissions is None else {
            k: sorted(v) for k, v in o.permissions.items() if v},
        "settings": lists,
    }
    return dict(sanitize.deep_scrub(data))
