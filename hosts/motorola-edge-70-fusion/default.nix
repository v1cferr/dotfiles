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
    # Checked against UAD-ng's list on 08/11/2026: all "Recommended" but the six it lacks (noted).
    packagesDisabled = [
      # Ads and app installers: they push "suggested" apps.
      "com.aura.oobe.motorola" # ironSource Aura, app picks at setup
      "com.dti.motorola" # Digital Turbine Ignite
      "com.facebook.appmanager"
      "com.facebook.services"
      "com.facebook.system"
      "com.motorola.demo" # the retail demo mode
      "com.motorola.playautoinstallext" # Play Auto Install, promoted apps: not in UAD-ng
      "com.motorola.smartfeed" # not in UAD-ng
      # Telemetry and Motorola/Lenovo extras: losing them only loses the feature.
      "com.lenovo.qira" # Lenovo's AI assistant, new in 2026: not in UAD-ng
      "com.lenovo.qiracore" # not in UAD-ng
      "com.motorola.android.fmradio"
      "com.motorola.appforecast"
      "com.motorola.attvowifi" # AT&T, a US carrier
      "com.motorola.bach.modemstats"
      "com.motorola.bug2go" # bug reports to Motorola
      "com.motorola.genie" # Device Help
      "com.motorola.help"
      "com.motorola.help.extlog"
      "com.motorola.lifetimedata"
      "com.motorola.livewallpaper3"
      "com.motorola.migrateassist" # moving data from the old phone, done: not in UAD-ng
      "com.motorola.motocare"
      "com.motorola.timeweatherwidget"
      "com.motorola.vzw.pco.extensions.pcoreceiver" # Verizon, a US carrier
      "com.motorola.wifi.motowifimetrics"
      # Round two, picked on 08/11/2026 from UAD-ng's "Recommended" (Android Auto is "Advanced").
      # Factory tests and diagnostics:
      "android.autoinstalls.config.motorola.layout" # installs OEM apps at setup
      "com.android.egg"
      "com.android.traceur"
      "com.motorola.android.nativedropboxagent" # Android logging, not the Dropbox app
      "com.motorola.dciservice"
      "com.motorola.hiddenmenuapp"
      "com.motorola.motocit" # the factory test menu
      "com.qti.qcc"
      "com.qualcomm.qti.xrvd.service"
      # Google's ad and personalization services (mainline ones may be refused, which is fine):
      "com.android.providers.partnerbookmarks"
      "com.google.android.adservices.api"
      "com.google.android.federatedcompute"
      "com.google.android.feedback"
      "com.google.android.gms.location.history"
      "com.google.android.ondevicepersonalization.services"
      # US carriers:
      "com.motorola.android.systemui.overlay.sprint"
      "com.motorola.android.systemui.overlay.tmo"
      "com.motorola.android.systemui.overlay.usc"
      "com.motorola.android.systemui.overlay.vzw"
      "com.motorola.contacts.preloadcontacts"
      "com.motorola.easyprefix"
      "com.motorola.nfwlocationattribution"
      "com.motorola.omadm.service"
      # Setup leftovers and extras, and the Google apps I do not use:
      "com.google.ambient.streaming" # apps on a Chromebook
      "com.google.android.apps.restore" # the setup's restore, done
      "com.google.android.projection.gearhead" # Android Auto
      "com.google.android.videos" # Google TV
      "com.motorola.android.overlay.crystaltalkai"
      "com.motorola.gesture" # the gesture tutorial
      # Round three, picked on 08/11/2026: the Moto extras I do not use (the Moto gestures stay).
      "com.android.theme.font.Exo2Regular"
      "com.android.theme.font.RobotoSlabRegular"
      "com.android.theme.font.RookeryRegular"
      "com.android.theme.font.notoserifsource"
      "com.android.theme.icon.pebble"
      "com.android.theme.icon.round"
      "com.google.ar.core" # ARCore, augmented reality
      "com.motorola.aiservices" # Moto AI's models (com.motorola.aicore stays: the camera uses it)
      "com.motorola.mobiledesktop.core" # Ready For, the phone on a PC or TV
      "com.motorola.systemui.desk" # Ready For's desktop UI
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
