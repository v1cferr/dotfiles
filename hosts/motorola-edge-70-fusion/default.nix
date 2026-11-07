# The phone's facts and desired POSTURE, written once: it runs stock Android, so this is data and
# not a NixOS module. android-iac reads it as JSON: docs/notes/hardware/android-iac.md
{
  name = "motorola-edge-70-fusion";
  manufacturer = "motorola"; # ro.product.manufacturer, compared case-insensitively
  model = "motorola edge 70 fusion"; # ro.product.model, read by the first audit on 07/11/2026
  address = "192.168.1.31"; # the router's DHCP reservation, and the wireless ADB target

  # Read-only properties of a stock, locked, unrooted build. Any other value is drift.
  security = {
    props = {
      "ro.boot.verifiedbootstate" = "green";
      "ro.boot.flash.locked" = "1";
      "ro.boot.vbmeta.device_state" = "locked";
      "ro.build.type" = "user";
      "ro.build.tags" = "release-keys";
      "ro.debuggable" = "0";
      "ro.secure" = "1";
    };
    selinux = "Enforcing";
    nfc = "on"; # Pix by tap, read from `dumpsys nfc`
    lockScreenRequired = true; # `cmd lock_settings get-disabled` must answer false
    maxPatchAgeDays = 120; # older than this, the security patch level is drift
  };

  # `settings get <namespace> <key>`, audited only. null means the key must be unset or empty.
  settings = {
    global = {
      auto_time = "1"; # TOTP and banking tokens need the network clock
      auto_time_zone = "1";
    };
    secure = {
      enabled_accessibility_services = null; # the banking-malware vector: none expected
    };
  };

  # The same reads, but only a person can fix them: they are ON while an audit runs.
  manualSettings = {
    global = {
      adb_enabled = "0";
      adb_wifi_enabled = "0";
      development_settings_enabled = "0";
    };
  };

  # What phase 2 may change itself, reversibly; `android-iac plan` lists it, nothing applies it yet.
  managed.settings.global.stay_on_while_plugged_in = "0"; # a harmless first key: the screen sleeps

  # System packages whose disabled state breaks the phone, banking or NFC payments.
  packages.mustBeEnabled = [
    "com.android.nfc"
    "com.android.phone"
    "com.android.settings"
    "com.android.systemui"
    "com.android.vending"
    "com.google.android.gms"
    "com.google.android.gsf"
    "com.google.android.webview"
  ];

  # Runtime permissions a third-party app holding them should be reviewed for (`--permissions`).
  permissions.flagged = [
    "android.permission.READ_SMS"
    "android.permission.RECEIVE_SMS"
    "android.permission.READ_CALL_LOG"
    "android.permission.RECORD_AUDIO"
    "android.permission.ACCESS_BACKGROUND_LOCATION"
  ];
}
