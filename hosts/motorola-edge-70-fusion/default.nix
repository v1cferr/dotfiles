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

  # The same reads, but only a person can fix them. Wireless debugging (and so developer options)
  # stays ON by my choice since 08/11/2026, so only USB debugging is held off: see the README.
  manualSettings.global.adb_enabled = "0";

  # What android-iac may change itself, reversibly: `plan`, `apply --dry-run`, then `apply`.
  managed = {
    settings.global.stay_on_while_plugged_in = "0"; # a harmless first key: the screen sleeps
    # Debloat, chosen on 08/11/2026: `pm disable-user`, undone by `android-iac rollback`. Factory
    # packages say nothing about me, so this list is public; the code refuses the protected floor.
    packagesDisabled = [
      # Ads and app installers: they push "suggested" apps.
      "com.aura.oobe.motorola" # ironSource Aura, app picks at setup
      "com.dti.motorola" # Digital Turbine Ignite
      "com.facebook.appmanager"
      "com.facebook.services"
      "com.facebook.system"
      "com.motorola.demo" # the retail demo mode
      "com.motorola.paks"
      "com.motorola.paks.notification"
      "com.motorola.playautoinstallext" # Play Auto Install, promoted apps
      "com.motorola.smartfeed"
      # Telemetry and Motorola/Lenovo extras: losing them only loses the feature.
      "com.lenovo.qira" # Lenovo's AI assistant
      "com.lenovo.qiracore"
      "com.motorola.android.fmradio"
      "com.motorola.appforecast"
      "com.motorola.attvowifi" # AT&T, a US carrier
      "com.motorola.bach.modemstats"
      "com.motorola.bug2go" # bug reports to Motorola
      "com.motorola.genie" # Device Help
      "com.motorola.help"
      "com.motorola.help.extlog"
      "com.motorola.journal"
      "com.motorola.lifetimedata"
      "com.motorola.livewallpaper3"
      "com.motorola.migrateassist" # moving data from the old phone, done
      "com.motorola.motocare"
      "com.motorola.timeweatherwidget"
      "com.motorola.vzw.pco.extensions.pcoreceiver" # Verizon, a US carrier
      "com.motorola.wifi.motowifimetrics"
    ];
  };

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
